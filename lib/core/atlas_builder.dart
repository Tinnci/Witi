import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../infra/logging/game_logger.dart';
import '../infra/dependency_injection.dart';

/// Atlas builder implementing MaxRects algorithm for efficient sprite packing
/// Generates atlas.json in Flame's SpriteBatch format for efficient loading
class AtlasBuilder {
  final int maxAtlasSize;
  final String outputDirectory;
  final String atlasName;
  final GameLogger _logger;

  /// List of sprite infos to pack
  final List<SpriteInfo> sprites = [];

  /// MaxRects packer for efficient sprite placement
  late MaxRectsPacker _packer;

  AtlasBuilder({
    required this.maxAtlasSize,
    required this.outputDirectory,
    required this.atlasName,
    GameLogger? logger,
  }) : _logger = logger ?? _getLogger() {
    _packer = MaxRectsPacker(maxAtlasSize, maxAtlasSize);
  }

  static GameLogger _getLogger() {
    try {
      return DependencyInjection.instance.get<GameLogger>();
    } catch (e) {
      return GameLogger.forTesting();
    }
  }

  /// Add sprite to be packed
  void addSprite(String name, String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        _logger.warning('Sprite file not found: $imagePath');
        return;
      }

      final imageBytes = file.readAsBytesSync();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        _logger.error('Failed to decode image: $imagePath');
        return;
      }

      sprites.add(SpriteInfo(name: name, path: imagePath, image: image));

      _logger.debug('Added sprite: $name (${image.width}x${image.height})');
    } catch (e, stackTrace) {
      _logger.error(
        'Error adding sprite $name',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Load sprites from directory
  Future<void> loadSpritesFromDirectory(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      _logger.warning('Sprite directory does not exist: $directory');
      return;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        final relativePath = entity.path.replaceFirst('$directory/', '');
        final name = relativePath.replaceAll(
          RegExp(r'\.[^.]+$'),
          '',
        ); // Remove extension
        addSprite(name, entity.path);
      }
    }

    _logger.info('Loaded ${sprites.length} sprites from $directory');
  }

  /// Build the atlas using MaxRects algorithm
  Future<BuildResult> buildAtlas() async {
    if (sprites.isEmpty) {
      return BuildResult(success: false, message: 'No sprites to pack');
    }

    _logger.info('Building atlas with ${sprites.length} sprites...');

    // Sort sprites by area (largest first) for better packing
    sprites.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));

    // Reset packer
    _packer = MaxRectsPacker(maxAtlasSize, maxAtlasSize);

    final packedSprites = <PackedSprite>[];
    final failedSprites = <SpriteInfo>[];

    // Pack each sprite
    for (final sprite in sprites) {
      final rect = _packer.pack(sprite.width, sprite.height);
      if (rect != null) {
        packedSprites.add(
          PackedSprite(
            info: sprite,
            x: rect.left,
            y: rect.top,
            width: sprite.width,
            height: sprite.height,
          ),
        );
        _logger.debug('Packed ${sprite.name} at (${rect.left}, ${rect.top})');
      } else {
        failedSprites.add(sprite);
        _logger.warning(
          'Failed to pack sprite: ${sprite.name} (${sprite.width}x${sprite.height})',
        );
      }
    }

    if (failedSprites.isNotEmpty) {
      return BuildResult(
        success: false,
        message:
            'Failed to pack ${failedSprites.length} sprites. Consider increasing atlas size.',
        failedSprites: failedSprites,
      );
    }

    // Generate atlas image and manifest
    try {
      await _generateAtlasImage(packedSprites);
      await _generateFlameManifest(packedSprites);

      return BuildResult(
        success: true,
        message:
            'Atlas built successfully with ${packedSprites.length} sprites',
        packedSprites: packedSprites,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error generating atlas files',
        error: e,
        stackTrace: stackTrace,
      );
      return BuildResult(
        success: false,
        message: 'Error generating atlas files: $e',
      );
    }
  }

  /// Generate the atlas image file
  Future<void> _generateAtlasImage(List<PackedSprite> packedSprites) async {
    // Create blank atlas image
    final atlasImage = img.Image(width: maxAtlasSize, height: maxAtlasSize);
    img.fill(
      atlasImage,
      color: img.ColorRgba8(0, 0, 0, 0),
    ); // Transparent background

    // Draw each sprite onto the atlas
    for (final packed in packedSprites) {
      img.compositeImage(
        atlasImage,
        packed.info.image,
        dstX: packed.x,
        dstY: packed.y,
      );
    }

    // Save atlas image
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final atlasImagePath = '$outputDirectory/$atlasName.png';
    final imageBytes = img.encodePng(atlasImage);
    await File(atlasImagePath).writeAsBytes(imageBytes);

    _logger.info('Atlas image saved: $atlasImagePath');
  }

  /// Generate Flame-compatible manifest
  Future<void> _generateFlameManifest(List<PackedSprite> packedSprites) async {
    final frames = <String, dynamic>{};

    for (final packed in packedSprites) {
      frames[packed.info.name] = {
        'frame': {
          'x': packed.x,
          'y': packed.y,
          'w': packed.width,
          'h': packed.height,
        },
        'rotated': false,
        'trimmed': false,
        'spriteSourceSize': {
          'x': 0,
          'y': 0,
          'w': packed.width,
          'h': packed.height,
        },
        'sourceSize': {'w': packed.width, 'h': packed.height},
      };
    }

    final manifest = {
      'frames': frames,
      'meta': {
        'app': 'Sims-like Game Atlas Builder',
        'version': '1.0',
        'image': '$atlasName.png',
        'format': 'RGBA8888',
        'size': {'w': maxAtlasSize, 'h': maxAtlasSize},
        'scale': '1',
      },
    };

    final manifestPath = '$outputDirectory/$atlasName.json';
    await File(
      manifestPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

    _logger.info('Atlas manifest saved: $manifestPath');
  }

  /// Check if file is an image
  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg');
  }

  /// Validate sprites before packing
  List<String> validateSprites() {
    final errors = <String>[];

    for (final sprite in sprites) {
      // Check size limits
      if (sprite.width > maxAtlasSize || sprite.height > maxAtlasSize) {
        errors.add(
          '${sprite.name}: Size ${sprite.width}x${sprite.height} exceeds maximum atlas size $maxAtlasSize',
        );
      }

      // Check for very small sprites (might indicate issues)
      if (sprite.width < 1 || sprite.height < 1) {
        errors.add(
          '${sprite.name}: Invalid dimensions (${sprite.width}x${sprite.height})',
        );
      }
    }

    return errors;
  }
}

/// MaxRects bin packing algorithm implementation
class MaxRectsPacker {
  final int binWidth;
  final int binHeight;
  final List<Rectangle> freeRectangles = [];

  MaxRectsPacker(this.binWidth, this.binHeight) {
    // Start with one free rectangle covering the entire bin
    freeRectangles.add(Rectangle(0, 0, binWidth, binHeight));
  }

  /// Pack a rectangle using Best Short Side Fit heuristic
  Rectangle? pack(int width, int height) {
    Rectangle? bestNode;
    int bestShortSide = 0x7FFFFFFF; // Maximum int value
    int bestLongSide = 0x7FFFFFFF;

    for (final rect in freeRectangles) {
      if (rect.width >= width && rect.height >= height) {
        final leftoverHoriz = rect.width - width;
        final leftoverVert = rect.height - height;
        final leftoverShort = math.min(leftoverHoriz, leftoverVert);
        final leftoverLong = math.max(leftoverHoriz, leftoverVert);

        if (leftoverShort < bestShortSide ||
            (leftoverShort == bestShortSide && leftoverLong < bestLongSide)) {
          bestNode = Rectangle(rect.left, rect.top, width, height);
          bestShortSide = leftoverShort;
          bestLongSide = leftoverLong;
        }
      }
    }

    if (bestNode != null) {
      _splitFreeNode(bestNode);
    }

    return bestNode;
  }

  /// Split free rectangles when a new rectangle is placed
  void _splitFreeNode(Rectangle usedNode) {
    final rectanglesToProcess = List<Rectangle>.from(freeRectangles);
    freeRectangles.clear();

    for (final freeRect in rectanglesToProcess) {
      if (_splitFreeRectByNode(freeRect, usedNode)) {
        // Rectangle was split, don't add original
      } else {
        freeRectangles.add(freeRect);
      }
    }

    _pruneFreeList();
  }

  /// Split a free rectangle by a used node
  bool _splitFreeRectByNode(Rectangle freeRect, Rectangle usedNode) {
    bool wasSplit = false;

    // Test with SAT if the rectangles even intersect
    if (usedNode.left >= freeRect.left + freeRect.width ||
        usedNode.left + usedNode.width <= freeRect.left ||
        usedNode.top >= freeRect.top + freeRect.height ||
        usedNode.top + usedNode.height <= freeRect.top) {
      return false;
    }

    if (usedNode.left < freeRect.left + freeRect.width &&
        usedNode.left + usedNode.width > freeRect.left) {
      // New node at the top side of the used node
      if (usedNode.top > freeRect.top &&
          usedNode.top < freeRect.top + freeRect.height) {
        final newNode = Rectangle(
          freeRect.left,
          freeRect.top,
          freeRect.width,
          usedNode.top - freeRect.top,
        );
        freeRectangles.add(newNode);
        wasSplit = true;
      }

      // New node at the bottom side of the used node
      if (usedNode.top + usedNode.height < freeRect.top + freeRect.height) {
        final newNode = Rectangle(
          freeRect.left,
          usedNode.top + usedNode.height,
          freeRect.width,
          freeRect.top + freeRect.height - (usedNode.top + usedNode.height),
        );
        freeRectangles.add(newNode);
        wasSplit = true;
      }
    }

    if (usedNode.top < freeRect.top + freeRect.height &&
        usedNode.top + usedNode.height > freeRect.top) {
      // New node at the left side of the used node
      if (usedNode.left > freeRect.left &&
          usedNode.left < freeRect.left + freeRect.width) {
        final newNode = Rectangle(
          freeRect.left,
          freeRect.top,
          usedNode.left - freeRect.left,
          freeRect.height,
        );
        freeRectangles.add(newNode);
        wasSplit = true;
      }

      // New node at the right side of the used node
      if (usedNode.left + usedNode.width < freeRect.left + freeRect.width) {
        final newNode = Rectangle(
          usedNode.left + usedNode.width,
          freeRect.top,
          freeRect.left + freeRect.width - (usedNode.left + usedNode.width),
          freeRect.height,
        );
        freeRectangles.add(newNode);
        wasSplit = true;
      }
    }

    return wasSplit;
  }

  /// Remove redundant free rectangles
  void _pruneFreeList() {
    for (int i = 0; i < freeRectangles.length; ++i) {
      for (int j = i + 1; j < freeRectangles.length; ++j) {
        if (_isContainedIn(freeRectangles[i], freeRectangles[j])) {
          freeRectangles.removeAt(i);
          --i;
          break;
        }
        if (_isContainedIn(freeRectangles[j], freeRectangles[i])) {
          freeRectangles.removeAt(j);
          --j;
        }
      }
    }
  }

  /// Check if rectangle a is contained in rectangle b
  bool _isContainedIn(Rectangle a, Rectangle b) {
    return a.left >= b.left &&
        a.top >= b.top &&
        a.left + a.width <= b.left + b.width &&
        a.top + a.height <= b.top + b.height;
  }
}

/// Rectangle class for packing
class Rectangle {
  final int left;
  final int top;
  final int width;
  final int height;

  Rectangle(this.left, this.top, this.width, this.height);

  @override
  String toString() => 'Rectangle($left, $top, $width, $height)';
}

/// Sprite information
class SpriteInfo {
  final String name;
  final String path;
  final img.Image image;

  SpriteInfo({required this.name, required this.path, required this.image});

  int get width => image.width;
  int get height => image.height;
}

/// Packed sprite with position
class PackedSprite {
  final SpriteInfo info;
  final int x;
  final int y;
  final int width;
  final int height;

  PackedSprite({
    required this.info,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Build result
class BuildResult {
  final bool success;
  final String message;
  final List<PackedSprite>? packedSprites;
  final List<SpriteInfo>? failedSprites;

  BuildResult({
    required this.success,
    required this.message,
    this.packedSprites,
    this.failedSprites,
  });
}
