import '../events/game_event_bus.dart';
import '../logging/game_logger.dart';

/// Custom exceptions for simulation errors
abstract class SimulationException implements Exception {
  final String message;
  final String context;
  final Map<String, dynamic>? metadata;

  const SimulationException(this.message, this.context, {this.metadata});

  @override
  String toString() => 'SimulationException: $message (context: $context)';
}

/// Exception thrown when pathfinding fails
class PathfindingException extends SimulationException {
  final String simId;
  final dynamic startPosition;
  final dynamic targetPosition;

  const PathfindingException(
    this.simId,
    this.startPosition,
    this.targetPosition,
    String message,
  ) : super(message, 'pathfinding');
}

/// Exception thrown when AI decision making fails
class AIDecisionException extends SimulationException {
  final String simId;
  final String decisionContext;

  AIDecisionException(this.simId, this.decisionContext, String message)
    : super(
        message,
        'ai_decision',
        metadata: {'simId': simId, 'decisionContext': decisionContext},
      );
}

/// Exception thrown when world state becomes invalid
class WorldStateException extends SimulationException {
  final int tick;
  final String worldId;

  WorldStateException(this.tick, this.worldId, String message)
    : super(
        message,
        'world_state',
        metadata: {'tick': tick, 'worldId': worldId},
      );
}

/// Exception thrown when need calculation fails
class NeedCalculationException extends SimulationException {
  final String simId;
  final String needType;

  NeedCalculationException(this.simId, this.needType, String message)
    : super(
        message,
        'need_calculation',
        metadata: {'simId': simId, 'needType': needType},
      );
}

/// Handles simulation-related errors with recovery mechanisms
///
/// Provides centralized error handling for the core simulation engine,
/// attempting graceful recovery and maintaining simulation integrity.
class SimulationErrorHandler {
  final Map<Type, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, int> _consecutiveErrors = {};

  static const int maxConsecutiveErrors = 5;
  static const Duration errorCooldownPeriod = Duration(seconds: 30);

  late final GameEventBus? _eventBus;
  late final GameLogger? _logger;

  /// Initialize the simulation error handler
  void initialize() {
    try {
      // Note: We can't use dependency injection here because this class
      // is being registered in the DI container itself
      _eventBus = GameEventBus.instance;
      _logger =
          GameLogger.forTesting(); // Use simple logger to avoid circular dependency
    } catch (error) {
      // If initialization fails, use null values (graceful degradation)
      _eventBus = null;
      _logger = null;
    }
  }

  /// Handle a simulation error with appropriate recovery
  void handleSimulationError(
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
    _consecutiveErrors[errorKey] = (_consecutiveErrors[errorKey] ?? 0) + 1;

    // Log the error with full context
    _logger?.error(
      'Simulation error: ${error.toString()}',
      error: error,
      stackTrace: stackTrace,
      context: {
        'context': errorContext,
        'errorType': errorType.toString(),
        'consecutiveCount': _consecutiveErrors[errorKey],
        'totalCount': _errorCounts[errorType],
        'metadata': metadata,
      },
    );

    // Check for error escalation
    if (_shouldEscalateError(errorKey)) {
      _handleErrorEscalation(error, stackTrace, errorContext, metadata);
      return;
    }

    // Attempt recovery based on error type
    final recovered = _attemptErrorRecovery(
      error,
      stackTrace,
      errorContext,
      metadata,
    );

    // Publish error event
    _eventBus?.publishSimulationError(error, errorContext, stackTrace);

    if (recovered) {
      _logger?.info(
        'Successfully recovered from simulation error: $errorContext',
      );
      // Reset consecutive error count on successful recovery
      _consecutiveErrors[errorKey] = 0;
    } else {
      _logger?.warning(
        'Could not recover from simulation error: $errorContext',
      );
    }
  }

  /// Check if an error should be escalated to critical
  bool _shouldEscalateError(String errorKey) {
    final consecutiveCount = _consecutiveErrors[errorKey] ?? 0;
    final lastErrorTime = _lastErrorTimes[errorKey];

    if (consecutiveCount >= maxConsecutiveErrors) {
      _logger?.critical(
        'Error escalated due to consecutive failures: $errorKey',
      );
      return true;
    }

    if (lastErrorTime != null) {
      final timeSinceLastError = DateTime.now().difference(lastErrorTime);
      if (timeSinceLastError < errorCooldownPeriod && consecutiveCount > 2) {
        _logger?.critical('Error escalated due to rapid occurrence: $errorKey');
        return true;
      }
    }

    return false;
  }

  /// Handle error escalation with emergency measures
  void _handleErrorEscalation(
    Object error,
    StackTrace stackTrace,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    _logger?.critical(
      'Simulation error escalated - implementing emergency measures',
      error: error,
      stackTrace: stackTrace,
      context: {
        'context': context,
        'escalationReason': 'consecutive_failures',
        'metadata': metadata,
      },
    );

    // Implement emergency measures based on context
    switch (context) {
      case 'pathfinding':
        _emergencyPathfindingReset();
        break;
      case 'ai_decision':
        _emergencyAIReset();
        break;
      case 'world_state':
        _emergencyWorldStateReset();
        break;
      case 'need_calculation':
        _emergencyNeedSystemReset();
        break;
      default:
        _emergencySimulationPause();
    }
  }

  /// Attempt to recover from a specific error
  bool _attemptErrorRecovery(
    Object error,
    StackTrace stackTrace,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    try {
      switch (error.runtimeType) {
        case PathfindingException:
          return _recoverFromPathfindingError(error as PathfindingException);
        case AIDecisionException:
          return _recoverFromAIError(error as AIDecisionException);
        case WorldStateException:
          return _recoverFromWorldStateError(error as WorldStateException);
        case NeedCalculationException:
          return _recoverFromNeedError(error as NeedCalculationException);
        default:
          return _recoverFromGenericError(error, context, metadata);
      }
    } catch (recoveryError) {
      _logger?.error(
        'Failed to recover from error',
        error: recoveryError,
        context: {'originalError': error.toString(), 'context': context},
      );
      return false;
    }
  }

  /// Recover from pathfinding errors
  bool _recoverFromPathfindingError(PathfindingException error) {
    _logger?.info('Attempting pathfinding recovery for sim: ${error.simId}');

    // TODO: Implement pathfinding recovery
    // - Reset sim to safe position
    // - Clear pathfinding cache
    // - Use alternative pathfinding algorithm

    return true; // Placeholder
  }

  /// Recover from AI decision errors
  bool _recoverFromAIError(AIDecisionException error) {
    _logger?.info('Attempting AI recovery for sim: ${error.simId}');

    // TODO: Implement AI recovery
    // - Reset AI state machine
    // - Use fallback decision
    // - Clear action queue

    return true; // Placeholder
  }

  /// Recover from world state errors
  bool _recoverFromWorldStateError(WorldStateException error) {
    _logger?.info('Attempting world state recovery at tick: ${error.tick}');

    // TODO: Implement world state recovery
    // - Validate world state
    // - Restore from backup
    // - Reset affected components

    return true; // Placeholder
  }

  /// Recover from need calculation errors
  bool _recoverFromNeedError(NeedCalculationException error) {
    _logger?.info(
      'Attempting need calculation recovery for sim: ${error.simId}',
    );

    // TODO: Implement need recovery
    // - Reset need values to safe defaults
    // - Recalculate need decay
    // - Clear need calculation cache

    return true; // Placeholder
  }

  /// Recover from generic errors
  bool _recoverFromGenericError(
    Object error,
    String context,
    Map<String, dynamic>? metadata,
  ) {
    _logger?.info('Attempting generic recovery for context: $context');

    // TODO: Implement generic recovery strategies
    // - Log and continue
    // - Reset affected system
    // - Use fallback behavior

    return false; // Conservative approach for unknown errors
  }

  /// Emergency pathfinding system reset
  void _emergencyPathfindingReset() {
    _logger?.critical('Performing emergency pathfinding reset');
    // TODO: Reset all pathfinding state
  }

  /// Emergency AI system reset
  void _emergencyAIReset() {
    _logger?.critical('Performing emergency AI reset');
    // TODO: Reset all AI decision makers
  }

  /// Emergency world state reset
  void _emergencyWorldStateReset() {
    _logger?.critical('Performing emergency world state reset');
    // TODO: Reset world to last known good state
  }

  /// Emergency need system reset
  void _emergencyNeedSystemReset() {
    _logger?.critical('Performing emergency need system reset');
    // TODO: Reset all need calculations
  }

  /// Emergency simulation pause
  void _emergencySimulationPause() {
    _logger?.critical('Performing emergency simulation pause');
    // TODO: Pause simulation and notify user
  }

  /// Get error statistics for debugging
  Map<String, dynamic> getErrorStatistics() {
    return {
      'errorCounts': Map<String, int>.from(
        _errorCounts.map((type, count) => MapEntry(type.toString(), count)),
      ),
      'lastErrorTimes': Map<String, String>.from(
        _lastErrorTimes.map(
          (key, time) => MapEntry(key, time.toIso8601String()),
        ),
      ),
      'consecutiveErrors': Map<String, int>.from(_consecutiveErrors),
      'totalErrors': _errorCounts.values.fold(0, (sum, count) => sum + count),
    };
  }

  /// Clear error statistics (for testing)
  void clearStatistics() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _consecutiveErrors.clear();
    _logger?.info('Cleared simulation error statistics');
  }
}
