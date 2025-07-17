import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/simulation_clock.dart';
import '../core/deterministic_simulation_clock.dart';
import '../core/debug_clock_controller.dart';
import '../infra/events/game_event_bus.dart';
import '../infra/events/game_events.dart';

class SimsGame extends FlameGame with HasKeyboardHandlerComponents {
  late final SimulationClock _simulationClock;
  late final DebugClockController _debugController;
  late final GameEventBus _eventBus;
  late final EventSubscriptionManager _subscriptionManager;

  bool _showDebugInfo = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Initialize event bus and subscription manager
    _eventBus = GameEventBus.instance;
    _subscriptionManager = _eventBus.createSubscriptionManager();

    // Initialize simulation clock
    _simulationClock = DeterministicSimulationClock();
    _debugController = DebugClockController(_simulationClock);

    // Subscribe to simulation events via event bus
    _subscriptionManager.subscribe<SimulationTickEvent>(_onSimulationTickEvent);
    _subscriptionManager.subscribe<SimulationErrorEvent>(_onSimulationError);
    _subscriptionManager.subscribe<RenderErrorEvent>(_onRenderError);

    // Connect simulation clock to event bus
    _simulationClock.tickStream.listen((tickEvent) {
      _eventBus.publishTick(tickEvent);
    });

    // Start the simulation and publish start event
    _simulationClock.start();
    _eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));

    debugPrint(
      'SimsGame initialized with 15Hz simulation clock and event bus!',
    );
    debugPrint(
      'Press F1 to toggle debug info, SPACE to pause/resume, +/- to change speed',
    );
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
      switch (event.logicalKey) {
        case LogicalKeyboardKey.f1:
          _showDebugInfo = !_showDebugInfo;
          _eventBus.publish(
            DebugOverlayToggledEvent(
              isVisible: _showDebugInfo,
              timestamp: DateTime.now(),
            ),
          );
          return KeyEventResult.handled;
        case LogicalKeyboardKey.space:
          final wasPaused = _simulationClock.isPaused;
          _debugController.togglePause();

          // Publish appropriate event
          if (wasPaused) {
            _eventBus.publish(
              SimulationResumedEvent(timestamp: DateTime.now()),
            );
          } else {
            _eventBus.publish(SimulationPausedEvent(timestamp: DateTime.now()));
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
          return KeyEventResult.handled;
        case LogicalKeyboardKey.period:
          if (_simulationClock.isPaused) {
            _debugController.stepOnce();
          }
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onSimulationTickEvent(SimulationTickEvent event) {
    // Handle simulation tick event from event bus
    // TODO: Update world state, AI, pathfinding, etc.

    // For now, just log every 15 ticks (1 second of simulation time)
    if (event.tick % 15 == 0) {
      debugPrint(
        'Simulation: ${event.simulationTime.toStringAsFixed(1)}s (Tick ${event.tick})',
      );
    }
  }

  void _onSimulationError(SimulationErrorEvent event) {
    debugPrint('Simulation Error: ${event.error} in ${event.context}');
    // TODO: Handle simulation errors gracefully
    // - Reset affected systems
    // - Show user notification
    // - Log for debugging
  }

  void _onRenderError(RenderErrorEvent event) {
    debugPrint('Render Error: ${event.error} in ${event.context}');
    // TODO: Handle render errors gracefully
    // - Use fallback rendering
    // - Show placeholder graphics
    // - Continue simulation
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Render main game content
    _renderGameContent(canvas);

    // Render debug overlay if enabled
    if (_showDebugInfo) {
      _renderDebugOverlay(canvas);
    }
  }

  void _renderGameContent(Canvas canvas) {
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
                '\nControls:\nF1 - Debug Info | SPACE - Pause/Resume\n+/- - Speed | . - Step (when paused)',
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
  }

  void _renderDebugOverlay(Canvas canvas) {
    final debugInfo = _debugController.getDebugInfo();
    final metrics = _debugController.performanceMetrics;
    final eventBusInfo = _eventBus.getDebugInfo();

    final debugText =
        '''
$debugInfo
Recent Ticks: ${_debugController.tickHistory.length}
Actual TPS: ${metrics.ticksPerSecond.toStringAsFixed(2)}
Avg Tick Time: ${metrics.averageTickDuration.inMicroseconds}μs
Memory Usage: ~${metrics.memoryUsage}KB

$eventBusInfo
Subscriptions: ${_subscriptionManager.subscriptionCount}
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
  }

  @override
  void onRemove() {
    _subscriptionManager.dispose();
    _simulationClock.dispose();
    super.onRemove();
  }
}
