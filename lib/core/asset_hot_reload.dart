import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:watcher/watcher.dart';
import '../infra/logging/game_logger.dart';
import '../infra/dependency_injection.dart';

/// Hot-reload system for asset changes during development
/// Watches asset directories and triggers rebuilds when files change
class AssetHotReload {
  static AssetHotReload? _instance;
  static AssetHotReload get instance => _instance ??= AssetHotReload._();

  AssetHotReload._();

  final Map<String, StreamSubscription> _watchers = {};
  final StreamController<AssetChangeEvent> _changeController =
      StreamController<AssetChangeEvent>.broadcast();

  GameLogger get _logger {
    try {
      return DependencyInjection.instance.get<GameLogger>();
    } catch (e) {
      // Fallback to a temporary logger if DI not initialized
      return GameLogger.forTesting();
    }
  }

  /// Stream of asset change events
  Stream<AssetChangeEvent> get changes => _changeController.stream;

  /// Start watching asset directories for changes
  Future<void> startWatching() async {
    if (!kDebugMode) {
      // Only enable hot-reload in debug mode
      return;
    }

    _logger.info('Starting asset hot-reload watchers...');

    // Watch sprite directory
    await _watchDirectory('assets/images/sprites', AssetType.sprite, [
      '.png',
      '.jpg',
      '.jpeg',
    ]);

    // Watch data configuration directory
    await _watchDirectory('assets/data', AssetType.config, ['.json']);

    // Watch audio directory
    await _watchDirectory('assets/audio', AssetType.audio, [
      '.mp3',
      '.ogg',
      '.wav',
    ]);

    _logger.info('Asset hot-reload watchers started');
  }

  /// Stop all watchers
  Future<void> stopWatching() async {
    for (final subscription in _watchers.values) {
      await subscription.cancel();
    }
    _watchers.clear();
    _logger.info('Asset hot-reload watchers stopped');
  }

  /// Watch a specific directory for file changes
  Future<void> _watchDirectory(
    String path,
    AssetType type,
    List<String> extensions,
  ) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      _logger.warning('Asset directory does not exist: $path');
      return;
    }

    final watcher = DirectoryWatcher(path);
    final subscription = watcher.events.listen((event) {
      final filePath = event.path;
      final hasValidExtension = extensions.any(
        (ext) => filePath.toLowerCase().endsWith(ext),
      );

      if (hasValidExtension) {
        _handleAssetChange(event, type);
      }
    });

    _watchers[path] = subscription;
    _logger.debug('Watching $path for ${extensions.join(', ')} files');
  }

  /// Handle asset change events
  void _handleAssetChange(WatchEvent event, AssetType type) {
    final changeEvent = AssetChangeEvent(
      path: event.path,
      type: type,
      changeType: _mapChangeType(event.type),
      timestamp: DateTime.now(),
    );

    _logger.info(
      'Asset changed: ${changeEvent.path} (${changeEvent.changeType})',
    );
    _changeController.add(changeEvent);

    // Trigger specific actions based on asset type
    switch (type) {
      case AssetType.sprite:
        _handleSpriteChange(changeEvent);
        break;
      case AssetType.config:
        _handleConfigChange(changeEvent);
        break;
      case AssetType.audio:
        _handleAudioChange(changeEvent);
        break;
    }
  }

  /// Handle sprite file changes
  void _handleSpriteChange(AssetChangeEvent event) {
    if (event.changeType == AssetChangeType.modified ||
        event.changeType == AssetChangeType.added) {
      // Trigger atlas rebuild
      _triggerAtlasRebuild();
    }
  }

  /// Handle configuration file changes
  void _handleConfigChange(AssetChangeEvent event) {
    if (event.path.endsWith('.json')) {
      _validateAndReloadConfig(event.path);
    }
  }

  /// Handle audio file changes
  void _handleAudioChange(AssetChangeEvent event) {
    // Audio files typically don't need processing, just notify
    _logger.debug('Audio file changed: ${event.path}');
  }

  /// Trigger atlas rebuild in background
  void _triggerAtlasRebuild() async {
    try {
      _logger.info('Triggering atlas rebuild...');

      // Run atlas builder as a separate process
      final result = await Process.run('dart', [
        'tool/build_atlas.dart',
      ], workingDirectory: Directory.current.path);

      if (result.exitCode == 0) {
        _logger.info('Atlas rebuilt successfully');

        // Trigger flutter_gen to update asset references
        await _triggerFlutterGen();
      } else {
        _logger.error('Atlas rebuild failed', error: result.stderr);
      }
    } catch (e, stackTrace) {
      _logger.error('Error rebuilding atlas', error: e, stackTrace: stackTrace);
    }
  }

  /// Validate and reload JSON configuration
  void _validateAndReloadConfig(String configPath) async {
    try {
      final file = File(configPath);
      final content = await file.readAsString();
      final json = jsonDecode(content);

      _logger.info('Configuration reloaded: $configPath');

      // Emit specific config change event
      _changeController.add(
        AssetChangeEvent(
          path: configPath,
          type: AssetType.config,
          changeType: AssetChangeType.reloaded,
          timestamp: DateTime.now(),
          data: json,
        ),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error reloading config $configPath',
        error: e,
        stackTrace: stackTrace,
      );

      // Emit error event
      _changeController.add(
        AssetChangeEvent(
          path: configPath,
          type: AssetType.config,
          changeType: AssetChangeType.error,
          timestamp: DateTime.now(),
          error: e.toString(),
        ),
      );
    }
  }

  /// Trigger flutter_gen to update generated asset references
  Future<void> _triggerFlutterGen() async {
    try {
      final result = await Process.run('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ], workingDirectory: Directory.current.path);

      if (result.exitCode == 0) {
        _logger.info('Flutter gen updated successfully');
      } else {
        _logger.error('Flutter gen update failed', error: result.stderr);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating flutter gen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  AssetChangeType _mapChangeType(ChangeType type) {
    switch (type) {
      case ChangeType.ADD:
        return AssetChangeType.added;
      case ChangeType.MODIFY:
        return AssetChangeType.modified;
      case ChangeType.REMOVE:
        return AssetChangeType.removed;
      default:
        return AssetChangeType.modified; // Default fallback
    }
  }
}

/// Types of assets that can be watched
enum AssetType { sprite, config, audio }

/// Types of changes that can occur to assets
enum AssetChangeType { added, modified, removed, reloaded, error }

/// Event representing a change to an asset
class AssetChangeEvent {
  final String path;
  final AssetType type;
  final AssetChangeType changeType;
  final DateTime timestamp;
  final dynamic data;
  final String? error;

  AssetChangeEvent({
    required this.path,
    required this.type,
    required this.changeType,
    required this.timestamp,
    this.data,
    this.error,
  });

  @override
  String toString() {
    return 'AssetChangeEvent(path: $path, type: $type, changeType: $changeType, timestamp: $timestamp)';
  }
}

/// Mixin for widgets that need to respond to asset changes
mixin AssetHotReloadMixin {
  StreamSubscription<AssetChangeEvent>? _assetSubscription;

  /// Start listening to asset changes
  void startListeningToAssetChanges() {
    _assetSubscription = AssetHotReload.instance.changes.listen(onAssetChanged);
  }

  /// Stop listening to asset changes
  void stopListeningToAssetChanges() {
    _assetSubscription?.cancel();
    _assetSubscription = null;
  }

  /// Override this method to handle asset changes
  void onAssetChanged(AssetChangeEvent event);
}
