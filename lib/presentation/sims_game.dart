import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/simulation_clock.dart';
import '../core/debug_clock_controller.dart';
import '../infra/dependency_injection.dart';
import '../infra/events/game_event_bus.dart';
import '../infra/events/game_events.dart';
import '../infra/logging/game_logger.dart';
import '../infra/error_handling/simulation_error_handler.dart';
import '../infra/error_handling/render_error_handler.dart';

class SimsGame extends FlameGame with HasKeyboardHandlerComponents {
  late final SimulationClock _simulationClock;
  late final DebugClockController _debugController;
  late final GameEventBus _eventBus;
  late final EventSubscriptionManager _subscriptionManager;
  late final GameLogger _logger;
  late final SimulationErrorHandler _simulationErrorHandler;
  late final RenderErrorHandler _renderErrorHandler;

  bool _showDebugInfo = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
      // Get services from dependency injection
      _simulationClock = DependencyInjection.get<SimulationClock>();
      _debugController = DependencyInjection.get<DebugClockController>();
      _eventBus = DependencyInjection.get<GameEventBus>();
      _logger = DependencyInjection.get<GameLogger>();
      _simulationErrorHandler =
          DependencyInjection.get<SimulationErrorHandler>();
      _renderErrorHandler = DependencyInjection.get<RenderErrorHandler>();

      // Create subscription manager
      _subscriptionManager = _eventBus.createSubscriptionManager();

      // Subscribe to simulation events via event bus
      _subscriptionManager.subscribe<SimulationTickEvent>(
        _onSimulationTickEvent,
      );
      _subscriptionManager.subscribe<SimulationErrorEvent>(_onSimulationError);
      _subscriptionManager.subscribe<RenderErrorEvent>(_onRenderError);

      // Connect simulation clock to event bus
      _simulationClock.tickStream.listen((tickEvent) {
        _eventBus.publishTick(tickEvent);
      });

      // Start the simulation and publish start event
      _simulationClock.start();
      _eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));

      _logger.info('SimsGame initialized with dependency injection');
      _logger.info('Simulation clock: ${_simulationClock.runtimeType}');
      _logger.info('Event bus: ${_eventBus.runtimeType}');
      _logger.info(
        'Press F1 for debug info, SPACE to pause/resume, +/- to change speed',
      );
    } catch (error, stackTrace) {
      // Handle initialization errors
      _renderErrorHandler.handleRenderError(
        error,
        stackTrace,
        context: 'game_initialization',
      );
      rethrow;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final result = super.onKeyEvent(event, keysPressed);
    if (result == KeyEventResult.handled) {
      return result;
    }

    if (event is KeyDownEvent) {
      try {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f1:
            _showDebugInfo = !_showDebugInfo;
            _eventBus.publish(
              DebugOverlayToggledEvent(
                isVisible: _showDebugInfo,
                timestamp: DateTime.now(),
              ),
            );
            _logger.debug('Debug overlay toggled: $_showDebugInfo');
            return KeyEventResult.handled;
          case LogicalKeyboardKey.space:
            final wasPaused = _simulationClock.isPaused;
            _debugController.togglePause();

            // Publish appropriate event
            if (wasPaused) {
              _eventBus.publish(
                SimulationResumedEvent(timestamp: DateTime.now()),
              );
              _logger.info('Simulation resumed');
            } else {
              _eventBus.publish(
                SimulationPausedEvent(timestamp: DateTime.now()),
              );
              _logger.info('Simulation paused');
            }
            return KeyEventResult.handled;
          case LogicalKeyboardKey.equal:
          case LogicalKeyboardKey.numpadAdd:
            final oldSpeed = _simulationClock.speedMultiplier;
            _debugController.cycleSpeed();
            _eventBus.publish(
              SimulationSpeedChangedEvent(
                oldSpeed: oldSpeed,
                newSpeed: _simulationClock.speedMultiplier,
                timestamp: DateTime.now(),
              ),
            );
            _logger.debug(
              'Speed changed: ${oldSpeed}x -> ${_simulationClock.speedMultiplier}x',
            );
            return KeyEventResult.handled;
          case LogicalKeyboardKey.minus:
          case LogicalKeyboardKey.numpadSubtract:
            final oldSpeed = _simulationClock.speedMultiplier;
            // Cycle speed backwards
            for (int i = 0; i < 3; i++) {
              _debugController.cycleSpeed();
            }
            _eventBus.publish(
              SimulationSpeedChangedEvent(
                oldSpeed: oldSpeed,
                newSpeed: _simulationClock.speedMultiplier,
                timestamp: DateTime.now(),
              ),
            );
            _logger.debug(
              'Speed changed backwards: ${oldSpeed}x -> ${_simulationClock.speedMultiplier}x',
            );
            return KeyEventResult.handled;
          case LogicalKeyboardKey.period:
            if (_simulationClock.isPaused) {
              _debugController.stepOnce();
              _logger.debug('Simulation stepped one tick');
            }
            return KeyEventResult.handled;
        }
      } catch (error, stackTrace) {
        _simulationErrorHandler.handleSimulationError(
          error,
          stackTrace,
          context: 'key_handling',
        );
      }
    }
    return KeyEventResult.ignored;
  }

  void _onSimulationTickEvent(SimulationTickEvent event) {
    try {
      // Handle simulation tick event from event bus
      // TODO: Update world state, AI, pathfinding, etc.

      // For now, just log every 15 ticks (1 second of simulation time)
      if (event.tick % 15 == 0) {
        _logger.debug(
          'Simulation: ${event.simulationTime.toStringAsFixed(1)}s (Tick ${event.tick})',
        );
      }
    } catch (error, stackTrace) {
      _simulationErrorHandler.handleSimulationError(
        error,
        stackTrace,
        context: 'tick_processing',
      );
    }
  }

  void _onSimulationError(SimulationErrorEvent event) {
    _logger.error('Simulation Error: ${event.error} in ${event.context}');
    // Error is already handled by SimulationErrorHandler
    // Just log it here for immediate visibility
  }

  void _onRenderError(RenderErrorEvent event) {
    _logger.error('Render Error: ${event.error} in ${event.context}');
    // Error is already handled by RenderErrorHandler
    // Just log it here for immediate visibility
  }

  @override
  void render(Canvas canvas) {
    try {
      super.render(canvas);

      // Render main game content
      _renderGameContent(canvas);

      // Render debug overlay if enabled
      if (_showDebugInfo) {
        _renderDebugOverlay(canvas);
      }
    } catch (error, stackTrace) {
      _renderErrorHandler.handleRenderError(
        error,
        stackTrace,
        context: 'main_render',
      );
    }
  }

  void _renderGameContent(Canvas canvas) {
    try {
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Sims-Like Game\n',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text:
                  'Simulation Clock: ${_simulationClock.isRunning ? (_simulationClock.isPaused ? 'PAUSED' : 'RUNNING') : 'STOPPED'}\n',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            TextSpan(
              text:
                  'Tick: ${_simulationClock.currentTick} | Speed: ${_simulationClock.speedMultiplier}x\n',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const TextSpan(
              text:
                  '\nControls:\nF1 - Debug Info | SPACE - Pause/Resume\n+/- - Speed | . - Step (when paused)\n\nDependency Injection: ✅ Active',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.x - textPainter.width) / 2,
          (size.y - textPainter.height) / 2,
        ),
      );
    } catch (error, stackTrace) {
      _renderErrorHandler.handleRenderError(
        error,
        stackTrace,
        context: 'game_content_render',
      );
    }
  }

  void _renderDebugOverlay(Canvas canvas) {
    try {
      final debugInfo = _debugController.getDebugInfo();
      final metrics = _debugController.performanceMetrics;
      final eventBusInfo = _eventBus.getDebugInfo();
      final errorStats = _simulationErrorHandler.getErrorStatistics();
      final renderStats = _renderErrorHandler.getErrorStatistics();

      final debugText =
          '''
$debugInfo
Recent Ticks: ${_debugController.tickHistory.length}
Actual TPS: ${metrics.ticksPerSecond.toStringAsFixed(2)}
Avg Tick Time: ${metrics.averageTickDuration.inMicroseconds}μs
Memory Usage: ~${metrics.memoryUsage}KB

$eventBusInfo
Subscriptions: ${_subscriptionManager.subscriptionCount}

Error Statistics:
Sim Errors: ${errorStats['totalErrors'] ?? 0}
Render Errors: ${renderStats['totalErrors'] ?? 0}

Services:
Clock: ${DependencyInjection.isRegistered<SimulationClock>() ? '✅' : '❌'}
EventBus: ${DependencyInjection.isRegistered<GameEventBus>() ? '✅' : '❌'}
Logger: ${DependencyInjection.isRegistered<GameLogger>() ? '✅' : '❌'}
''';

      final textPainter = TextPainter(
        text: TextSpan(
          text: debugText,
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Draw debug background
      final debugRect = Rect.fromLTWH(
        10,
        10,
        textPainter.width + 20,
        textPainter.height + 20,
      );

      canvas.drawRect(
        debugRect,
        Paint()..color = Colors.black.withValues(alpha: 0.8),
      );

      textPainter.paint(canvas, const Offset(20, 20));
    } catch (error, stackTrace) {
      _renderErrorHandler.handleRenderError(
        error,
        stackTrace,
        context: 'debug_overlay_render',
      );
    }
  }

  @override
  void onRemove() {
    try {
      _subscriptionManager.dispose();
      _simulationClock.dispose();
      _logger.info('SimsGame disposed successfully');
    } catch (error, stackTrace) {
      _logger.error(
        'Error during game disposal',
        error: error,
        stackTrace: stackTrace,
      );
    }
    super.onRemove();
  }
}
