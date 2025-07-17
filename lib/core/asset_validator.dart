import 'dart:io';
import 'package:image/image.dart' as img;
import '../infra/logging/game_logger.dart';
import '../infra/dependency_injection.dart';

/// Asset validation tool for checking image formats and sizes
/// Ensures assets meet game requirements before processing
class AssetValidator {
  final GameLogger _logger;

  AssetValidator({GameLogger? logger}) : _logger = logger ?? _getLogger();

  static GameLogger _getLogger() {
    try {
      return DependencyInjection.instance.get<GameLogger>();
    } catch (e) {
      return GameLogger.forTesting();
    }
  }

  /// Validate all assets in a directory
  Future<ValidationResult> validateDirectory(String directory) async {
    final result = ValidationResult();
    final dir = Directory(directory);

    if (!await dir.exists()) {
      result.addError('Directory does not exist: $directory');
      return result;
    }

    _logger.info('Validating assets in: $directory');

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        final fileResult = await validateImageFile(entity.path);
        result.merge(fileResult);
      }
    }

    _logger.info(
      'Asset validation complete: ${result.totalFiles} files, ${result.errors.length} errors, ${result.warnings.length} warnings',
    );
    return result;
  }

  /// Validate a single image file
  Future<ValidationResult> validateImageFile(String filePath) async {
    final result = ValidationResult();
    final file = File(filePath);

    if (!await file.exists()) {
      result.addError('File does not exist: $filePath');
      return result;
    }

    result.totalFiles++;

    try {
      // Check file extension
      if (!_isValidImageFormat(filePath)) {
        result.addWarning(
          '$filePath: Unsupported image format. Use PNG, JPG, or JPEG.',
        );
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB
        result.addWarning(
          '$filePath: Large file size (${_formatBytes(fileSize)}). Consider optimizing.',
        );
      }

      // Decode and validate image
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        result.addError(
          '$filePath: Failed to decode image. File may be corrupted.',
        );
        return result;
      }

      // Check dimensions
      _validateDimensions(filePath, image, result);

      // Check format specific issues
      _validateFormat(filePath, image, result);

      // Check for power-of-two dimensions (recommended for GPU performance)
      if (!_isPowerOfTwo(image.width) || !_isPowerOfTwo(image.height)) {
        result.addInfo(
          '$filePath: Dimensions (${image.width}x${image.height}) are not power-of-two. May impact GPU performance.',
        );
      }

      result.validFiles++;
    } catch (e, stackTrace) {
      result.addError('$filePath: Validation error - $e');
      _logger.error(
        'Error validating $filePath',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return result;
  }

  /// Validate image dimensions
  void _validateDimensions(
    String filePath,
    img.Image image,
    ValidationResult result,
  ) {
    const int maxDimension = 4096;
    const int minDimension = 1;

    if (image.width > maxDimension || image.height > maxDimension) {
      result.addError(
        '$filePath: Dimensions too large (${image.width}x${image.height}). Maximum allowed: ${maxDimension}x$maxDimension',
      );
    }

    if (image.width < minDimension || image.height < minDimension) {
      result.addError(
        '$filePath: Dimensions too small (${image.width}x${image.height}). Minimum allowed: ${minDimension}x$minDimension',
      );
    }

    // Check for very small sprites (might indicate issues)
    if (image.width < 4 || image.height < 4) {
      result.addWarning(
        '$filePath: Very small dimensions (${image.width}x${image.height}). May not be visible in game.',
      );
    }

    // Check for very large sprites (performance impact)
    if (image.width > 1024 || image.height > 1024) {
      result.addWarning(
        '$filePath: Large dimensions (${image.width}x${image.height}). May impact performance.',
      );
    }

    // Check aspect ratio
    final aspectRatio = image.width / image.height;
    if (aspectRatio > 10 || aspectRatio < 0.1) {
      result.addWarning(
        '$filePath: Extreme aspect ratio (${aspectRatio.toStringAsFixed(2)}). May cause visual issues.',
      );
    }
  }

  /// Validate format-specific issues
  void _validateFormat(
    String filePath,
    img.Image image,
    ValidationResult result,
  ) {
    final ext = filePath.toLowerCase();

    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
      // JPEG doesn't support transparency
      if (_hasTransparency(image)) {
        result.addWarning(
          '$filePath: JPEG format detected with transparency. Consider using PNG for transparent images.',
        );
      }
    }

    if (ext.endsWith('.png')) {
      // Check PNG bit depth
      if (image.numChannels > 4) {
        result.addWarning(
          '$filePath: PNG has more than 4 channels. May not be supported in all contexts.',
        );
      }
    }
  }

  /// Check if image has transparency
  bool _hasTransparency(img.Image image) {
    if (image.numChannels < 4) return false; // No alpha channel

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.a < 255) {
          // Found transparent pixel
          return true;
        }
      }
    }
    return false;
  }

  /// Check if file is a supported image format
  bool _isValidImageFormat(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg');
  }

  /// Check if file is an image
  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.webp');
  }

  /// Check if a number is a power of two
  bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Generate validation report
  String generateReport(ValidationResult result) {
    final buffer = StringBuffer();

    buffer.writeln('=== Asset Validation Report ===');
    buffer.writeln('Total files processed: ${result.totalFiles}');
    buffer.writeln('Valid files: ${result.validFiles}');
    buffer.writeln('Errors: ${result.errors.length}');
    buffer.writeln('Warnings: ${result.warnings.length}');
    buffer.writeln('Info: ${result.infos.length}');
    buffer.writeln();

    if (result.errors.isNotEmpty) {
      buffer.writeln('ERRORS:');
      for (final error in result.errors) {
        buffer.writeln('  ❌ $error');
      }
      buffer.writeln();
    }

    if (result.warnings.isNotEmpty) {
      buffer.writeln('WARNINGS:');
      for (final warning in result.warnings) {
        buffer.writeln('  ⚠️  $warning');
      }
      buffer.writeln();
    }

    if (result.infos.isNotEmpty) {
      buffer.writeln('INFO:');
      for (final info in result.infos) {
        buffer.writeln('  ℹ️  $info');
      }
      buffer.writeln();
    }

    if (result.errors.isEmpty && result.warnings.isEmpty) {
      buffer.writeln('✅ All assets are valid!');
    }

    return buffer.toString();
  }
}

/// Result of asset validation
class ValidationResult {
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> infos = [];
  int totalFiles = 0;
  int validFiles = 0;

  /// Add an error message
  void addError(String message) {
    errors.add(message);
  }

  /// Add a warning message
  void addWarning(String message) {
    warnings.add(message);
  }

  /// Add an info message
  void addInfo(String message) {
    infos.add(message);
  }

  /// Merge another result into this one
  void merge(ValidationResult other) {
    errors.addAll(other.errors);
    warnings.addAll(other.warnings);
    infos.addAll(other.infos);
    totalFiles += other.totalFiles;
    validFiles += other.validFiles;
  }

  /// Check if validation passed (no errors)
  bool get isValid => errors.isEmpty;

  /// Get total issue count
  int get totalIssues => errors.length + warnings.length;
}
