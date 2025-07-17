#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:args/args.dart';

/// Asset validation tool for checking image formats, sizes, and configurations
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('path', abbr: 'p', defaultsTo: 'assets',
        help: 'Path to assets directory to validate')
    ..addFlag('strict', abbr: 's', defaultsTo: false,
        help: 'Enable strict validation (warnings become errors)')
    ..addFlag('help', abbr: 'h', defaultsTo: false,
        help: 'Show this help message');

  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    print('Asset Validator - Validation tool for game assets');
    print('Usage: dart tool/asset_validator.dart [options]');
    print(parser.usage);
    return;
  }

  final assetPath = results['path'] as String;
  final strictMode = results['strict'] as bool;

  final validator = AssetValidator(
    assetPath: assetPath,
    strictMode: strictMode,
  );

  final result = await validator.validate();
  
  print('\n=== Asset Validation Results ===');
  print('Total files checked: ${result.totalFiles}');
  print('Errors: ${result.errors.length}');
  print('Warnings: ${result.warnings.length}');
  
  if (result.errors.isNotEmpty) {
    print('\nErrors:');
    for (final error in result.errors) {
      print('  ❌ $error');
    }
  }
  
  if (result.warnings.isNotEmpty) {
    print('\nWarnings:');
    for (final warning in result.warnings) {
      print('  ⚠️  $warning');
    }
  }
  
  if (result.errors.isEmpty && result.warnings.isEmpty) {
    print('✅ All assets are valid!');
  }
  
  // Exit with error code if there are errors (or warnings in strict mode)
  if (result.errors.isNotEmpty || (strictMode && result.warnings.isNotEmpty)) {
    exit(1);
  }
}

class ValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final int totalFiles;

  ValidationResult({
    required this.errors,
    required this.warnings,
    required this.totalFiles,
  });
}

class AssetValidator {
  final String assetPath;
  final bool strictMode;

  AssetValidator({
    required this.assetPath,
    required this.strictMode,
  });

  Future<ValidationResult> validate() async {
    final errors = <String>[];
    final warnings = <String>[];
    int totalFiles = 0;

    final assetDir = Directory(assetPath);
    if (!await assetDir.exists()) {
      errors.add('Asset directory does not exist: $assetPath');
      return ValidationResult(errors: errors, warnings: warnings, totalFiles: 0);
    }

    print('Validating assets in: $assetPath');

    // Validate images
    await _validateImages(assetDir, errors, warnings);
    
    // Validate JSON configurations
    await _validateJsonConfigs(assetDir, errors, warnings);
    
    // Validate audio files
    await _validateAudioFiles(assetDir, errors, warnings);
    
    // Count total files
    await for (final entity in assetDir.list(recursive: true)) {
      if (entity is File) {
        totalFiles++;
      }
    }

    return ValidationResult(
      errors: errors,
      warnings: warnings,
      totalFiles: totalFiles,
    );
  }

  Future<void> _validateImages(Directory dir, List<String> errors, List<String> warnings) async {
    final imageDir = Directory('${dir.path}/images');
    if (!await imageDir.exists()) {
      warnings.add('Images directory not found: ${imageDir.path}');
      return;
    }

    await for (final entity in imageDir.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        await _validateImageFile(entity, errors, warnings);
      }
    }
  }

  Future<void> _validateImageFile(File file, List<String> errors, List<String> warnings) async {
    final relativePath = file.path.replaceFirst('$assetPath/', '');
    
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        errors.add('$relativePath: Could not decode image');
        return;
      }

      // Check image dimensions
      if (image.width <= 0 || image.height <= 0) {
        errors.add('$relativePath: Invalid dimensions ${image.width}x${image.height}');
      }

      // Check for very large images
      if (image.width > 4096 || image.height > 4096) {
        warnings.add('$relativePath: Very large image ${image.width}x${image.height} (may impact performance)');
      }

      // Check for very small images
      if (image.width < 4 || image.height < 4) {
        warnings.add('$relativePath: Very small image ${image.width}x${image.height}');
      }

      // Check for non-power-of-two dimensions (GPU performance)
      if (!_isPowerOfTwo(image.width) || !_isPowerOfTwo(image.height)) {
        warnings.add('$relativePath: Non-power-of-two dimensions ${image.width}x${image.height} (may impact GPU performance)');
      }

      // Check file size
      final fileSizeKB = bytes.length / 1024;
      if (fileSizeKB > 1024) { // > 1MB
        warnings.add('$relativePath: Large file size ${fileSizeKB.toStringAsFixed(1)}KB');
      }

      // Check format recommendations
      final ext = file.path.toLowerCase();
      if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
        if (image.numChannels == 4) { // Has alpha channel
          warnings.add('$relativePath: JPEG format with transparency detected, consider using PNG');
        }
      }

    } catch (e) {
      errors.add('$relativePath: Error reading image - $e');
    }
  }

  Future<void> _validateJsonConfigs(Directory dir, List<String> errors, List<String> warnings) async {
    final dataDir = Directory('${dir.path}/data');
    if (!await dataDir.exists()) {
      warnings.add('Data directory not found: ${dataDir.path}');
      return;
    }

    await for (final entity in dataDir.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        await _validateJsonFile(entity, errors, warnings);
      }
    }
  }

  Future<void> _validateJsonFile(File file, List<String> errors, List<String> warnings) async {
    final relativePath = file.path.replaceFirst('$assetPath/', '');
    
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      
      // Basic JSON structure validation
      if (json is! Map<String, dynamic>) {
        warnings.add('$relativePath: JSON root should be an object');
      }

      // Check for common configuration patterns
      if (relativePath.contains('objects.json')) {
        _validateObjectsConfig(json, relativePath, errors, warnings);
      } else if (relativePath.contains('needs.json')) {
        _validateNeedsConfig(json, relativePath, errors, warnings);
      }

    } catch (e) {
      errors.add('$relativePath: Invalid JSON - $e');
    }
  }

  void _validateObjectsConfig(dynamic json, String path, List<String> errors, List<String> warnings) {
    if (json is! Map<String, dynamic>) return;

    // Check for required fields in object definitions
    for (final entry in json.entries) {
      final objName = entry.key;
      final objData = entry.value;
      
      if (objData is! Map<String, dynamic>) {
        errors.add('$path: Object "$objName" should be an object');
        continue;
      }

      // Check required fields
      final requiredFields = ['name', 'advertisements'];
      for (final field in requiredFields) {
        if (!objData.containsKey(field)) {
          errors.add('$path: Object "$objName" missing required field "$field"');
        }
      }

      // Validate advertisements
      if (objData.containsKey('advertisements')) {
        final ads = objData['advertisements'];
        if (ads is! Map<String, dynamic>) {
          errors.add('$path: Object "$objName" advertisements should be an object');
        } else {
          for (final adEntry in ads.entries) {
            if (adEntry.value is! num) {
              errors.add('$path: Object "$objName" advertisement "${adEntry.key}" should be a number');
            } else {
              final value = adEntry.value as num;
              if (value < 0 || value > 100) {
                warnings.add('$path: Object "$objName" advertisement "${adEntry.key}" value $value outside recommended range 0-100');
              }
            }
          }
        }
      }
    }
  }

  void _validateNeedsConfig(dynamic json, String path, List<String> errors, List<String> warnings) {
    if (json is! Map<String, dynamic>) return;

    for (final entry in json.entries) {
      final needName = entry.key;
      final needData = entry.value;
      
      if (needData is! Map<String, dynamic>) {
        errors.add('$path: Need "$needName" should be an object');
        continue;
      }

      // Check for decay rate
      if (needData.containsKey('decayRate')) {
        final decayRate = needData['decayRate'];
        if (decayRate is! num) {
          errors.add('$path: Need "$needName" decayRate should be a number');
        } else if (decayRate <= 0) {
          warnings.add('$path: Need "$needName" decayRate $decayRate should be positive');
        }
      }
    }
  }

  Future<void> _validateAudioFiles(Directory dir, List<String> errors, List<String> warnings) async {
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) {
      warnings.add('Audio directory not found: ${audioDir.path}');
      return;
    }

    await for (final entity in audioDir.list(recursive: true)) {
      if (entity is File && _isAudioFile(entity.path)) {
        await _validateAudioFile(entity, errors, warnings);
      }
    }
  }

  Future<void> _validateAudioFile(File file, List<String> errors, List<String> warnings) async {
    final relativePath = file.path.replaceFirst('$assetPath/', '');
    
    try {
      final stat = await file.stat();
      final fileSizeKB = stat.size / 1024;
      
      // Check file size
      if (fileSizeKB > 5120) { // > 5MB
        warnings.add('$relativePath: Large audio file ${fileSizeKB.toStringAsFixed(1)}KB');
      }

      // Check format recommendations
      final ext = file.path.toLowerCase();
      if (ext.endsWith('.wav')) {
        warnings.add('$relativePath: WAV format detected, consider using OGG or MP3 for smaller file size');
      }

    } catch (e) {
      errors.add('$relativePath: Error reading audio file - $e');
    }
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.png') || 
           ext.endsWith('.jpg') || 
           ext.endsWith('.jpeg') || 
           ext.endsWith('.gif') || 
           ext.endsWith('.bmp');
  }

  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp3') || 
           ext.endsWith('.ogg') || 
           ext.endsWith('.wav') || 
           ext.endsWith('.m4a');
  }

  bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }
}