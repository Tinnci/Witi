import '../events/game_event_bus.dart';
import '../events/game_events.dart';
import '../logging/game_logger.dart';

/// Custom exceptions for rendering errors
abstract class RenderException implements Exception {
  final String message;
  final String context;
  final Map<String, dynamic>? metadata;

  const RenderException(this.message, this.context, {this.metadata});

  @override
  String toString() => 'RenderException: $message (context: $context)';
}

/// Exception thrown when asset loading fails
class AssetLoadException extends RenderException {
  final String assetPath;
  final String assetType;

  AssetLoadException(this.assetPath, this.assetType, String message)
    : super(
        message,
        'asset_loading',
        metadata: {'assetPath': assetPath, 'assetType': assetType},
      );
}

/// Exception thrown when sprite rendering fails
class SpriteRenderException extends RenderException {
  final String spriteId;
  final String renderStage;

  SpriteRenderException(this.spriteId, this.renderStage, String message)
    : super(
        message,
        'sprite_rendering',
        metadata: {'spriteId': spriteId, 'renderStage': renderStage},
      );
}

/// Exception thrown when UI rendering fails
class UIRenderException extends RenderException {
  final String componentName;
  final String uiStage;

  UIRenderException(this.componentName, this.uiStage, String message)
    : super(
        message,
        'ui_rendering',
        metadata: {'componentName': componentName, 'uiStage': uiStage},
      );
}

/// Exception thrown when canvas operations fail
class CanvasException extends RenderException {
  final String operation;
  final Map<String, dynamic> canvasState;

  CanvasException(this.operation, this.canvasState, String message)
    : super(
        message,
        'canvas_operation',
        metadata: {'operation': operation, 'canvasState': canvasState},
      );
}

/// Handles rendering-related errors with fallback mechanisms
///
/// Provides centralized error handling for the presentation layer,
/// ensuring that rendering errors never affect simulation state.
class RenderErrorHandler {
  final Map<Type, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, String> _fallbackAssets = {};

  static const int maxErrorsPerMinute = 10;
  static const Duration errorTrackingWindow = Duration(minutes: 1);

  late final GameEventBus? _eventBus;
  late final GameLogger? _logger;

  /// Initialize the render error handler
  void initialize() {
    try {
      _eventBus = GameEventBus.instance;
      _logger =
          GameLogger.forTesting(); // Use simple logger to avoid circular dependency

      // Set up default fallback assets
      _initializeFallbackAssets();
    } catch (error) {
      // If initialization fails, use null values (graceful degradation)
      _eventBus = null;
      _logger = null;

      // Still set up fallback assets
      _initializeFallbackAssets();
    }
  }

  /// Initialize fallback assets for common failures
  void _initializeFallbackAssets() {
    _fallbackAssets.addAll({
      'missing_texture': 'assets/images/fallback/missing_texture.png',
      'missing_sprite': 'assets/images/fallback/missing_sprite.png',
      'missing_icon': 'assets/images/fallback/missing_icon.png',
      'error_texture': 'assets/images/fallback/error_texture.png',
    });
  }

  /// Handle a rendering error with appropriate fallback
  void handleRenderError(
    Object error,
    StackTrace stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    final errorType = error.runtimeType;
    final errorContext = context ?? 'unknown';
    final errorKey = '$errorType:$errorContext';

    // Update error statistics
    _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
    _lastErrorTimes[errorKey] = DateTime.now();

    // Check for error flooding
    if (_isErrorFlooding(errorKey)) {
      _handleErrorFlooding(error, stackTrace, errorContext, metadata);
      return;
    }

    // Log the error with context
    _logger?.error(
      'Render error: ${error.toString()}',
      error: error,
      stackTrace: stackTrace,
      context: {
        'context': errorContext,
        'errorType': errorType.toString(),
        'totalCount': _errorCounts[errorType],
        'metadata': metadata,
      },
    );

    // Attempt fallback rendering
    final fallbackApplied = _applyRenderFallback(error, errorContext, metadata);

    // Publish error event (render errors should not affect simulation)
    _eventBus?.publishRenderError(error, errorContext, stackTrace);

    if (fallbackApplied) {
      _logger?.info('Applied rendering fallback for: $errorContext');
    } else {
      _logger?.warning('No fallback available for render error: $errorContext');
    }
  }

  /// Check if we're experiencing error flooding
  bool _isErrorFlooding(String errorKey) {
    final recentErrors = _getRecentErrorCount(errorKey);
    return recentErrors > maxErrorsPerMinute;
  }

  /// Get the count of recent errors for a specific key
  int _getRecentErrorCount(String errorKey) {
    final now = DateTime.now();
    return _lastErrorTimes.entries
        .where(
          (entry) =>
              entry.key == errorKey &&
              now.difference(entry.value) <= errorTrackingWindow,
        )
        .length;
  }

  /// Handle error flooding with rate limiting
  void _handleErrorFlooding(
    Object error,
    StackTrace stackTrace,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    _logger?.warning(
      'Render error flooding detected - rate limiting: $context',
      context: {
        'errorType': error.runtimeType.toString(),
        'context': context,
        'recentErrorCount': _getRecentErrorCount('$error.runtimeType:$context'),
      },
    );

    // Apply aggressive fallbacks during flooding
    _applyEmergencyFallbacks(context);
  }

  /// Apply rendering fallbacks based on error type
  bool _applyRenderFallback(
    Object error,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    try {
      switch (error.runtimeType) {
        case AssetLoadException:
          return _handleAssetLoadError(error as AssetLoadException);
        case SpriteRenderException:
          return _handleSpriteRenderError(error as SpriteRenderException);
        case UIRenderException:
          return _handleUIRenderError(error as UIRenderException);
        case CanvasException:
          return _handleCanvasError(error as CanvasException);
        default:
          return _handleGenericRenderError(error, context, metadata);
      }
    } catch (fallbackError) {
      _logger?.error(
        'Fallback rendering failed',
        error: fallbackError,
        context: {'originalError': error.toString(), 'context': context},
      );
      return false;
    }
  }

  /// Handle asset loading errors with fallback assets
  bool _handleAssetLoadError(AssetLoadException error) {
    _logger?.info('Applying asset fallback for: ${error.assetPath}');

    // Determine appropriate fallback based on asset type
    final fallbackKey = switch (error.assetType.toLowerCase()) {
      'texture' => 'missing_texture',
      'sprite' => 'missing_sprite',
      'icon' => 'missing_icon',
      _ => 'error_texture',
    };

    final fallbackPath = _fallbackAssets[fallbackKey];
    if (fallbackPath != null) {
      // TODO: Replace failed asset with fallback
      _logger?.info(
        'Using fallback asset: $fallbackPath for ${error.assetPath}',
      );
      return true;
    }

    return false;
  }

  /// Handle sprite rendering errors
  bool _handleSpriteRenderError(SpriteRenderException error) {
    _logger?.info('Applying sprite fallback for: ${error.spriteId}');

    // TODO: Implement sprite fallback
    // - Use placeholder sprite
    // - Skip sprite rendering
    // - Use simplified rendering mode

    return true; // Placeholder
  }

  /// Handle UI rendering errors
  bool _handleUIRenderError(UIRenderException error) {
    _logger?.info('Applying UI fallback for: ${error.componentName}');

    // TODO: Implement UI fallback
    // - Use placeholder UI component
    // - Hide problematic component
    // - Use simplified UI mode

    return true; // Placeholder
  }

  /// Handle canvas operation errors
  bool _handleCanvasError(CanvasException error) {
    _logger?.info('Applying canvas fallback for: ${error.operation}');

    // TODO: Implement canvas fallback
    // - Skip problematic draw operation
    // - Use alternative canvas method
    // - Clear canvas and continue

    return true; // Placeholder
  }

  /// Handle generic rendering errors
  bool _handleGenericRenderError(
    Object error,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    _logger?.info('Applying generic render fallback for: $context');

    // TODO: Implement generic fallback
    // - Continue without rendering problematic component
    // - Use safe rendering mode
    // - Display error indicator

    return false; // Conservative approach for unknown errors
  }

  /// Apply emergency fallbacks during error flooding
  void _applyEmergencyFallbacks(String context) {
    _logger?.warning('Applying emergency render fallbacks for: $context');

    // TODO: Implement emergency fallbacks
    // - Disable all non-essential rendering
    // - Use text-only mode
    // - Reduce render quality
  }

  /// Register a custom fallback asset
  void registerFallbackAsset(String key, String assetPath) {
    _fallbackAssets[key] = assetPath;
    _logger?.info('Registered fallback asset: $key -> $assetPath');
  }

  /// Remove a fallback asset
  void removeFallbackAsset(String key) {
    final removed = _fallbackAssets.remove(key);
    if (removed != null) {
      _logger?.info('Removed fallback asset: $key');
    }
  }

  /// Get current fallback assets
  Map<String, String> getFallbackAssets() {
    return Map<String, String>.from(_fallbackAssets);
  }

  /// Get error statistics for debugging
  Map<String, dynamic> getErrorStatistics() {
    final recentErrors = <String, int>{};
    final now = DateTime.now();

    for (final entry in _lastErrorTimes.entries) {
      if (now.difference(entry.value) <= errorTrackingWindow) {
        recentErrors[entry.key] = (recentErrors[entry.key] ?? 0) + 1;
      }
    }

    return {
      'errorCounts': Map<String, int>.from(
        _errorCounts.map((type, count) => MapEntry(type.toString(), count)),
      ),
      'recentErrors': recentErrors,
      'fallbackAssets': Map<String, String>.from(_fallbackAssets),
      'totalErrors': _errorCounts.values.fold(0, (sum, count) => sum + count),
    };
  }

  /// Clear error statistics (for testing)
  void clearStatistics() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _logger?.info('Cleared render error statistics');
  }
}
