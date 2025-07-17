import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/simulation_clock.dart';
import '../core/deterministic_simulation_clock.dart';
import '../core/debug_clock_controller.dart';

class SimsGame extends FlameGame with HasKeyboardHandlerComponents {
  late final SimulationClock _simulationClock;
  late final DebugClockController _debugController;
  late final StreamSubscription<TickEvent> _tickSubscription;
  
  bool _showDebugInfo = false;
  
  @override
  Color backgroundColor() => const Color(0xFF2E7D32); // Green background
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize simulation clock
    _simulationClock = DeterministicSimulationClock();
    _debugController = DebugClockController(_simulationClock);
    
    // Subscribe to tick events
    _tickSubscription = _simulationClock.tickStream.listen(_onSimulationTick);
    
    // Start the simulation
    _simulationClock.start();
    
    debugPrint('SimsGame initialized with 15Hz simulation clock!');
    debugPrint('Press F1 to toggle debug info, SPACE to pause/resume, +/- to change speed');
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // TODO: Update simulation systems here
    // This will be called every frame (~60 FPS)
    // The actual simulation will run at 15 Hz via SimulationClock
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.f1:
          _showDebugInfo = !_showDebugInfo;
          return true;
        case LogicalKeyboardKey.space:
          _debugController.togglePause();
          return true;
        case LogicalKeyboardKey.equal:
        case LogicalKeyboardKey.numpadAdd:
          _debugController.cycleSpeed();
          return true;
        case LogicalKeyboardKey.minus:
        case LogicalKeyboardKey.numpadSubtract:
          // Cycle speed backwards
          for (int i = 0; i < 3; i++) {
            _debugController.cycleSpeed();
          }
          return true;
        case LogicalKeyboardKey.period:
          if (_simulationClock.isPaused) {
            _debugController.stepOnce();
          }
          return true;
      }
    }
    return false;
  }
  
  void _onSimulationTick(TickEvent event) {
    // Handle simulation tick
    
    // For now, just log every 15 ticks (1 second of simulation time)
    if (event.tick % 15 == 0) {
      debugPrint('Simulation: ${event.simulationTime.toStringAsFixed(1)}s (Tick ${event.tick})');
    }
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
            text: 'Simulation Clock: ${_simulationClock.isRunning ? (_simulationClock.isPaused ? 'PAUSED' : 'RUNNING') : 'STOPPED'}\n',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          TextSpan(
            text: 'Tick: ${_simulationClock.currentTick} | Speed: ${_simulationClock.speedMultiplier}x\n',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const TextSpan(
            text: '\nControls:\nF1 - Debug Info | SPACE - Pause/Resume\n+/- - Speed | . - Step (when paused)',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
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
    
    final debugText = '''
$debugInfo
Recent Ticks: ${_debugController.tickHistory.length}
Actual TPS: ${metrics.ticksPerSecond.toStringAsFixed(2)}
Avg Tick Time: ${metrics.averageTickDuration.inMicroseconds}μs
Memory Usage: ~${metrics.memoryUsage}KB
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
      Paint()..color = Colors.black.withOpacity(0.8),
    );
    
    textPainter.paint(canvas, const Offset(20, 20));
  }
  
  @override
  void onRemove() {
    _tickSubscription.cancel();
    _simulationClock.dispose();
    super.onRemove();
  }
}
