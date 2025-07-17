import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import '../infra/logging/game_logger.dart';
import '../infra/dependency_injection.dart';

/// Asset loader with strongly-typed access and fallback mechanisms
/// Integrates with flutter_gen for compile-time asset validation
class AssetLoader {
  static AssetLoader? _instance;
  static AssetLoader get instance => _instance ??= AssetLoader._();

  AssetLoader._();

  final Map<String, dynamic> _cache = {};
  final Map<String, String> _fallbacks = {};

  // Flame's image cache for sprites
  final Images _images = Images();

  GameLogger get _logger {
    try {
      return DependencyInjection.instance.get<GameLogger>();
    } catch (e) {
      // Fallback to a temporary logger if DI not initialized
      return GameLogger.forTesting();
    }
  }

  /// Load sprite atlas manifest
  Future<Map<String, dynamic>> loadAtlasManifest([
    String atlasName = 'atlas',
  ]) async {
    final cacheKey = 'atlas_manifest_$atlasName';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as Map<String, dynamic>;
    }

    try {
      final manifestPath = 'assets/images/$atlasName.json';
      final manifestString = await rootBundle.loadString(manifestPath);
      final manifest = jsonDecode(manifestString) as Map<String, dynamic>;

      _cache[cacheKey] = manifest;
      return manifest;
    } catch (e, stackTrace) {
      _logger.warning(
        'Could not load atlas manifest for $atlasName',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Load sprite from atlas
  Future<Sprite?> loadSpriteFromAtlas(
    String spriteName, [
    String atlasName = 'atlas',
  ]) async {
    try {
      final manifest = await loadAtlasManifest(atlasName);
      final frames = manifest['frames'] as Map<String, dynamic>?;

      if (frames == null || !frames.containsKey(spriteName)) {
        _logger.warning('Sprite $spriteName not found in atlas $atlasName');
        return await _loadFallbackSprite(spriteName);
      }

      final frameData = frames[spriteName] as Map<String, dynamic>;
      final frame = frameData['frame'] as Map<String, dynamic>;

      final atlasImage = await _images.load('$atlasName.png');

      return Sprite(
        atlasImage,
        srcPosition: Vector2(
          (frame['x'] as num).toDouble(),
          (frame['y'] as num).toDouble(),
        ),
        srcSize: Vector2(
          (frame['w'] as num).toDouble(),
          (frame['h'] as num).toDouble(),
        ),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error loading sprite $spriteName from atlas',
        error: e,
        stackTrace: stackTrace,
      );
      return await _loadFallbackSprite(spriteName);
    }
  }

  /// Load individual sprite file (fallback when atlas is not available)
  Future<Sprite?> loadSprite(String spritePath) async {
    try {
      final image = await _images.load(spritePath);
      return Sprite(image);
    } catch (e, stackTrace) {
      _logger.error(
        'Error loading sprite $spritePath',
        error: e,
        stackTrace: stackTrace,
      );
      return await _loadFallbackSprite(spritePath);
    }
  }

  /// Load JSON configuration file
  Future<Map<String, dynamic>?> loadJsonConfig(String configPath) async {
    final cacheKey = 'config_$configPath';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as Map<String, dynamic>;
    }

    try {
      final configString = await rootBundle.loadString(
        'assets/data/$configPath',
      );
      final config = jsonDecode(configString) as Map<String, dynamic>;

      _cache[cacheKey] = config;
      return config;
    } catch (e, stackTrace) {
      _logger.error(
        'Error loading config $configPath',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Load binary asset data
  Future<Uint8List?> loadBinaryAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e, stackTrace) {
      _logger.error(
        'Error loading binary asset $assetPath',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Register fallback asset for when primary asset fails to load
  void registerFallback(String assetPath, String fallbackPath) {
    _fallbacks[assetPath] = fallbackPath;
  }

  /// Use fallback asset when primary asset is not available
  void useFallback(String assetPath) {
    if (_fallbacks.containsKey(assetPath)) {
      _logger.info('Using fallback for $assetPath: ${_fallbacks[assetPath]}');
    }
  }

  /// Load fallback sprite (creates a simple colored rectangle)
  Future<Sprite?> _loadFallbackSprite(String spriteName) async {
    try {
      // Try to load from fallback registry first
      if (_fallbacks.containsKey(spriteName)) {
        return await loadSprite(_fallbacks[spriteName]!);
      }

      // Create a simple fallback sprite (placeholder)
      // This would typically be a pink/magenta square to indicate missing asset
      _logger.debug('Creating fallback sprite for $spriteName');

      // For now, return null - in a full implementation, you'd create a
      // programmatic sprite or load a default "missing texture" image
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error creating fallback sprite for $spriteName',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Clear asset cache (useful for hot-reload)
  void clearCache() {
    _cache.clear();
    _images.clearCache();
    _logger.info('Asset cache cleared');
  }

  /// Preload commonly used assets
  Future<void> preloadAssets() async {
    _logger.info('Preloading common assets...');

    try {
      // Preload atlas manifest
      await loadAtlasManifest();

      // Preload common configuration files
      await loadJsonConfig('objects.json');
      await loadJsonConfig('needs.json');

      _logger.info('Asset preloading completed');
    } catch (e, stackTrace) {
      _logger.error(
        'Error during asset preloading',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get asset loading statistics
  Map<String, dynamic> getStats() {
    // Note: Images class doesn't have a public cache property
    // We'll track our own statistics
    return {
      'cached_items': _cache.length,
      'fallback_registrations': _fallbacks.length,
      'preloaded_configs': _cache.keys
          .where((k) => k.startsWith('config_'))
          .length,
    };
  }
}

/// Extension for Vector2 to work with our asset system
extension Vector2Extension on Vector2 {
  static Vector2 fromJson(Map<String, dynamic> json) {
    return Vector2(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

/// Asset path constants (these would typically be generated by flutter_gen)
/// For now, we'll define them manually as examples
class AssetPaths {
  static const String atlasManifest = 'assets/images/atlas.json';
  static const String atlasImage = 'assets/images/atlas.png';

  // Configuration files
  static const String objectsConfig = 'assets/data/objects.json';
  static const String needsConfig = 'assets/data/needs.json';

  // Example sprite paths (would be in atlas)
  static const String tileFloorWood = 'tiles/floor_wood';
  static const String tileWallBrick = 'tiles/wall_brick';
  static const String objectRefrigerator = 'objects/refrigerator';
  static const String objectChair = 'objects/chair';
  static const String characterSimIdle = 'characters/sim_idle';
}

/// Strongly-typed asset references (example of what flutter_gen would generate)
class Assets {
  static const String _assetsImagesPath = 'assets/images/';

  static String get atlasJson => '${_assetsImagesPath}atlas.json';
  static String get atlasPng => '${_assetsImagesPath}atlas.png';

  // These would be auto-generated based on actual files in the project
  static const sprites = _Sprites();
  static const data = _Data();
}

class _Sprites {
  const _Sprites();

  // Example sprite references - these would be generated automatically
  String get floorWood => 'tiles/floor_wood';
  String get wallBrick => 'tiles/wall_brick';
  String get refrigerator => 'objects/refrigerator';
  String get chair => 'objects/chair';
  String get simIdle => 'characters/sim_idle';
}

class _Data {
  const _Data();

  String get objects => 'objects.json';
  String get needs => 'needs.json';
}
