#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:watcher/watcher.dart';

/// CLI tool for building sprite atlases using maxrects algorithm
/// Generates atlas.json in Flame's SpriteBatch format for efficient loading
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'input',
      abbr: 'i',
      defaultsTo: 'assets/images/sprites',
      help: 'Input directory containing sprite images',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'assets/images',
      help: 'Output directory for atlas files',
    )
    ..addOption(
      'name',
      abbr: 'n',
      defaultsTo: 'atlas',
      help: 'Base name for atlas files',
    )
    ..addOption(
      'max-size',
      defaultsTo: '2048',
      help: 'Maximum atlas size (width and height)',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      defaultsTo: false,
      help: 'Watch for changes and rebuild automatically',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      help: 'Show this help message',
    );

  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    print('Atlas Builder - Sprite packing tool for Flame games');
    print('Usage: dart tool/atlas_builder.dart [options]');
    print(parser.usage);
    return;
  }

  final inputDir = results['input'] as String;
  final outputDir = results['output'] as String;
  final atlasName = results['name'] as String;
  final maxSize = int.parse(results['max-size'] as String);
  final watchMode = results['watch'] as bool;

  final builder = AtlasBuilder(
    inputDirectory: inputDir,
    outputDirectory: outputDir,
    atlasName: atlasName,
    maxAtlasSize: maxSize,
  );

  if (watchMode) {
    print('Watching $inputDir for changes...');
    await builder.watchAndBuild();
  } else {
    await builder.buildAtlas();
  }
}

/// Represents a sprite in the atlas
class SpriteInfo {
  final String name;
  final String path;
  final img.Image image;
  int x = 0;
  int y = 0;
  bool placed = false;

  SpriteInfo({required this.name, required this.path, required this.image});

  int get width => image.width;
  int get height => image.height;
  int get area => width * height;
}

/// Represents a rectangle in the maxrects algorithm
class Rectangle {
  int x, y, width, height;

  Rectangle(this.x, this.y, this.width, this.height);

  bool contains(Rectangle other) {
    return x <= other.x &&
        y <= other.y &&
        x + width >= other.x + other.width &&
        y + height >= other.y + other.height;
  }

  bool intersects(Rectangle other) {
    return !(x >= other.x + other.width ||
        other.x >= x + width ||
        y >= other.y + other.height ||
        other.y >= y + height);
  }

  @override
  String toString() => 'Rectangle($x, $y, $width, $height)';
}

/// MaxRects bin packing algorithm implementation
class MaxRectsPacker {
  final int binWidth;
  final int binHeight;
  final List<Rectangle> freeRectangles = [];

  MaxRectsPacker(this.binWidth, this.binHeight) {
    freeRectangles.add(Rectangle(0, 0, binWidth, binHeight));
  }

  /// Pack a sprite into the atlas using Best Short Side Fit heuristic
  Rectangle? pack(int width, int height) {
    Rectangle? bestNode;
    int bestShortSide = 0x7FFFFFFF; // int.maxFinite equivalent
    int bestLongSide = 0x7FFFFFFF;

    for (final rect in freeRectangles) {
      if (rect.width >= width && rect.height >= height) {
        final leftoverHoriz = rect.width - width;
        final leftoverVert = rect.height - height;
        final shortSide = min(leftoverHoriz, leftoverVert);
        final longSide = max(leftoverHoriz, leftoverVert);

        if (shortSide < bestShortSide ||
            (shortSide == bestShortSide && longSide < bestLongSide)) {
          bestNode = Rectangle(rect.x, rect.y, width, height);
          bestShortSide = shortSide;
          bestLongSide = longSide;
        }
      }
    }

    if (bestNode != null) {
      _splitFreeNode(bestNode);
    }

    return bestNode;
  }

  void _splitFreeNode(Rectangle usedNode) {
    for (int i = freeRectangles.length - 1; i >= 0; i--) {
      if (_splitFreeRectByUsedRect(freeRectangles[i], usedNode)) {
        freeRectangles.removeAt(i);
      }
    }

    _pruneFreeList();
  }

  bool _splitFreeRectByUsedRect(Rectangle freeRect, Rectangle usedRect) {
    if (!freeRect.intersects(usedRect)) return false;

    if (usedRect.x < freeRect.x + freeRect.width &&
        usedRect.x + usedRect.width > freeRect.x) {
      // New node at the top side of the used node
      if (usedRect.y > freeRect.y &&
          usedRect.y < freeRect.y + freeRect.height) {
        final newNode = Rectangle(
          freeRect.x,
          freeRect.y,
          freeRect.width,
          usedRect.y - freeRect.y,
        );
        freeRectangles.add(newNode);
      }

      // New node at the bottom side of the used node
      if (usedRect.y + usedRect.height < freeRect.y + freeRect.height) {
        final newNode = Rectangle(
          freeRect.x,
          usedRect.y + usedRect.height,
          freeRect.width,
          freeRect.y + freeRect.height - (usedRect.y + usedRect.height),
        );
        freeRectangles.add(newNode);
      }
    }

    if (usedRect.y < freeRect.y + freeRect.height &&
        usedRect.y + usedRect.height > freeRect.y) {
      // New node at the left side of the used node
      if (usedRect.x > freeRect.x && usedRect.x < freeRect.x + freeRect.width) {
        final newNode = Rectangle(
          freeRect.x,
          freeRect.y,
          usedRect.x - freeRect.x,
          freeRect.height,
        );
        freeRectangles.add(newNode);
      }

      // New node at the right side of the used node
      if (usedRect.x + usedRect.width < freeRect.x + freeRect.width) {
        final newNode = Rectangle(
          usedRect.x + usedRect.width,
          freeRect.y,
          freeRect.x + freeRect.width - (usedRect.x + usedRect.width),
          freeRect.height,
        );
        freeRectangles.add(newNode);
      }
    }

    return true;
  }

  void _pruneFreeList() {
    for (int i = 0; i < freeRectangles.length; i++) {
      for (int j = i + 1; j < freeRectangles.length; j++) {
        if (freeRectangles[i].contains(freeRectangles[j])) {
          freeRectangles.removeAt(j);
          j--;
        } else if (freeRectangles[j].contains(freeRectangles[i])) {
          freeRectangles.removeAt(i);
          i--;
          break;
        }
      }
    }
  }
}

/// Main atlas builder class
class AtlasBuilder {
  final String inputDirectory;
  final String outputDirectory;
  final String atlasName;
  final int maxAtlasSize;

  AtlasBuilder({
    required this.inputDirectory,
    required this.outputDirectory,
    required this.atlasName,
    required this.maxAtlasSize,
  });

  /// Build the sprite atlas
  Future<void> buildAtlas() async {
    print('Building atlas from $inputDirectory...');

    final sprites = await _loadSprites();
    if (sprites.isEmpty) {
      print('No sprites found in $inputDirectory');
      return;
    }

    print('Found ${sprites.length} sprites');

    // Validate sprites
    final validationErrors = _validateSprites(sprites);
    if (validationErrors.isNotEmpty) {
      print('Validation errors:');
      for (final error in validationErrors) {
        print('  - $error');
      }
      return;
    }

    // Sort sprites by area (largest first) for better packing
    sprites.sort((a, b) => b.area.compareTo(a.area));

    final packer = MaxRectsPacker(maxAtlasSize, maxAtlasSize);
    final packedSprites = <SpriteInfo>[];

    // Pack sprites
    for (final sprite in sprites) {
      final rect = packer.pack(sprite.width, sprite.height);
      if (rect != null) {
        sprite.x = rect.x;
        sprite.y = rect.y;
        sprite.placed = true;
        packedSprites.add(sprite);
      } else {
        print(
          'Warning: Could not pack sprite ${sprite.name} (${sprite.width}x${sprite.height})',
        );
      }
    }

    if (packedSprites.isEmpty) {
      print('No sprites could be packed');
      return;
    }

    // Create atlas image
    final atlasImage = await _createAtlasImage(packedSprites);

    // Save atlas image
    final atlasImagePath = '$outputDirectory/$atlasName.png';
    await Directory(outputDirectory).create(recursive: true);
    await File(atlasImagePath).writeAsBytes(img.encodePng(atlasImage));

    // Generate atlas manifest in Flame's format
    final manifest = _generateFlameManifest(packedSprites);
    final manifestPath = '$outputDirectory/$atlasName.json';
    await File(
      manifestPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

    print('Atlas built successfully:');
    print('  - Image: $atlasImagePath');
    print('  - Manifest: $manifestPath');
    print('  - Packed ${packedSprites.length}/${sprites.length} sprites');
    print('  - Atlas size: ${atlasImage.width}x${atlasImage.height}');
  }

  /// Watch directory for changes and rebuild automatically
  Future<void> watchAndBuild() async {
    // Initial build
    await buildAtlas();

    // Watch for changes
    final watcher = DirectoryWatcher(inputDirectory);
    await for (final event in watcher.events) {
      if (event.path.endsWith('.png') || event.path.endsWith('.jpg')) {
        print('Detected change: ${event.path}');
        print('Rebuilding atlas...');
        await buildAtlas();
      }
    }
  }

  /// Load all sprite images from the input directory
  Future<List<SpriteInfo>> _loadSprites() async {
    final sprites = <SpriteInfo>[];
    final dir = Directory(inputDirectory);

    if (!await dir.exists()) {
      print('Input directory does not exist: $inputDirectory');
      return sprites;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        try {
          final bytes = await entity.readAsBytes();
          final image = img.decodeImage(bytes);

          if (image != null) {
            final relativePath = entity.path.replaceFirst(
              '$inputDirectory/',
              '',
            );
            final name = relativePath.replaceAll(
              RegExp(r'\.[^.]+$'),
              '',
            ); // Remove extension

            sprites.add(
              SpriteInfo(name: name, path: entity.path, image: image),
            );
          }
        } catch (e) {
          print('Warning: Could not load image ${entity.path}: $e');
        }
      }
    }

    return sprites;
  }

  /// Validate sprite images
  List<String> _validateSprites(List<SpriteInfo> sprites) {
    final errors = <String>[];

    for (final sprite in sprites) {
      // Check size limits
      if (sprite.width > maxAtlasSize || sprite.height > maxAtlasSize) {
        errors.add(
          '${sprite.name}: Size ${sprite.width}x${sprite.height} exceeds maximum atlas size $maxAtlasSize',
        );
      }

      // Check for power-of-two dimensions (recommended for GPU performance)
      if (!_isPowerOfTwo(sprite.width) || !_isPowerOfTwo(sprite.height)) {
        print(
          'Info: ${sprite.name} dimensions (${sprite.width}x${sprite.height}) are not power-of-two',
        );
      }

      // Check for very small sprites (might indicate issues)
      if (sprite.width < 4 || sprite.height < 4) {
        print(
          'Warning: ${sprite.name} is very small (${sprite.width}x${sprite.height})',
        );
      }
    }

    return errors;
  }

  /// Create the final atlas image
  Future<img.Image> _createAtlasImage(List<SpriteInfo> sprites) async {
    // Calculate actual atlas size needed
    int actualWidth = 0;
    int actualHeight = 0;

    for (final sprite in sprites) {
      actualWidth = max(actualWidth, sprite.x + sprite.width);
      actualHeight = max(actualHeight, sprite.y + sprite.height);
    }

    // Create atlas image with transparent background
    final atlas = img.Image(width: actualWidth, height: actualHeight);
    img.fill(atlas, color: img.ColorRgba8(0, 0, 0, 0)); // Transparent

    // Copy sprites to atlas
    for (final sprite in sprites) {
      img.compositeImage(atlas, sprite.image, dstX: sprite.x, dstY: sprite.y);
    }

    return atlas;
  }

  /// Generate manifest in Flame's SpriteBatch format
  Map<String, dynamic> _generateFlameManifest(List<SpriteInfo> sprites) {
    final frames = <String, Map<String, dynamic>>{};

    for (final sprite in sprites) {
      frames[sprite.name] = {
        'frame': {
          'x': sprite.x,
          'y': sprite.y,
          'w': sprite.width,
          'h': sprite.height,
        },
        'rotated': false,
        'trimmed': false,
        'spriteSourceSize': {
          'x': 0,
          'y': 0,
          'w': sprite.width,
          'h': sprite.height,
        },
        'sourceSize': {'w': sprite.width, 'h': sprite.height},
      };
    }

    return {
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
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg');
  }

  bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }
}
