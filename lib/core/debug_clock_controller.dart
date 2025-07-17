import 'simulation_clock.dart';
import 'deterministic_simulation_clock.dart';

/// Debug controller for simulation clock with development tools
///
/// Provides debugging capabilities like step-by-step execution,
/// speed control, and performance monitoring.
class DebugClockController {
  final SimulationClock _clock;
  final List<TickEvent> _tickHistory = [];
  static const int maxHistory = 100;

  DateTime? _lastTickTime;
  Duration _averageTickDuration = Duration.zero;
  int _tickCount = 0;

  DebugClockController(this._clock) {
    _clock.tickStream.listen(_onTick);
  }

  /// Get the underlying simulation clock
  SimulationClock get clock => _clock;

  /// Get recent tick history for debugging
  List<TickEvent> get tickHistory => List.unmodifiable(_tickHistory);

  /// Get average tick processing time
  Duration get averageTickDuration => _averageTickDuration;

  /// Get current performance metrics
  PerformanceMetrics get performanceMetrics => PerformanceMetrics(
    currentTick: _clock.currentTick,
    isRunning: _clock.isRunning,
    isPaused: _clock.isPaused,
    speedMultiplier: _clock.speedMultiplier,
    averageTickDuration: _averageTickDuration,
    ticksPerSecond: _calculateActualTicksPerSecond(),
    memoryUsage: _getApproximateMemoryUsage(),
  );

  /// Toggle pause/resume
  void togglePause() {
    if (_clock.isPaused) {
      _clock.resume();
    } else {
      _clock.pause();
    }
  }

  /// Cycle through speed multipliers (0.5x -> 1x -> 2x -> 3x -> 0.5x)
  void cycleSpeed() {
    const speeds = [0.5, 1.0, 2.0, 3.0];
    final currentIndex = speeds.indexOf(_clock.speedMultiplier);
    final nextIndex = (currentIndex + 1) % speeds.length;
    _clock.setSpeedMultiplier(speeds[nextIndex]);
  }

  /// Execute a single step (only when paused)
  void stepOnce() {
    if (!_clock.isPaused) {
      throw StateError('Can only step when simulation is paused');
    }
    _clock.step();
  }

  /// Execute multiple steps (only when paused)
  void stepMultiple(int count) {
    if (!_clock.isPaused) {
      throw StateError('Can only step when simulation is paused');
    }

    for (int i = 0; i < count; i++) {
      _clock.step();
    }
  }

  /// Reset clock and clear debug data
  void reset() {
    if (_clock case DeterministicSimulationClock clock) {
      clock.reset();
    }
    _tickHistory.clear();
    _lastTickTime = null;
    _averageTickDuration = Duration.zero;
    _tickCount = 0;
  }

  /// Get debug information as formatted string
  String getDebugInfo() {
    final metrics = performanceMetrics;
    return '''
Debug Clock Info:
  Tick: ${metrics.currentTick}
  Status: ${metrics.isRunning ? (metrics.isPaused ? 'PAUSED' : 'RUNNING') : 'STOPPED'}
  Speed: ${metrics.speedMultiplier}x
  Avg Tick Time: ${metrics.averageTickDuration.inMicroseconds}μs
  Actual TPS: ${metrics.ticksPerSecond.toStringAsFixed(1)}
  Memory: ~${metrics.memoryUsage}KB
''';
  }

  void _onTick(TickEvent event) {
    final now = DateTime.now();

    // Update tick history
    _tickHistory.add(event);
    if (_tickHistory.length > maxHistory) {
      _tickHistory.removeAt(0);
    }

    // Update performance metrics
    if (_lastTickTime != null) {
      final tickDuration = now.difference(_lastTickTime!);
      _averageTickDuration = Duration(
        microseconds:
            ((_averageTickDuration.inMicroseconds * _tickCount +
                        tickDuration.inMicroseconds) /
                    (_tickCount + 1))
                .round(),
      );
      _tickCount++;
    }

    _lastTickTime = now;
  }

  double _calculateActualTicksPerSecond() {
    if (_tickHistory.length < 2) return 0.0;

    final recentTicks = _tickHistory.length >= 15
        ? _tickHistory.sublist(_tickHistory.length - 15)
        : _tickHistory;

    if (recentTicks.length < 2) return 0.0;

    final timeSpan =
        recentTicks.last.simulationTime - recentTicks.first.simulationTime;
    return timeSpan > 0 ? (recentTicks.length - 1) / timeSpan : 0.0;
  }

  int _getApproximateMemoryUsage() {
    // Rough estimate of memory usage for debugging
    return _tickHistory.length * 64 + 1024; // bytes -> KB
  }
}

/// Performance metrics for debugging
class PerformanceMetrics {
  final int currentTick;
  final bool isRunning;
  final bool isPaused;
  final double speedMultiplier;
  final Duration averageTickDuration;
  final double ticksPerSecond;
  final int memoryUsage; // in KB

  const PerformanceMetrics({
    required this.currentTick,
    required this.isRunning,
    required this.isPaused,
    required this.speedMultiplier,
    required this.averageTickDuration,
    required this.ticksPerSecond,
    required this.memoryUsage,
  });

  @override
  String toString() {
    return 'PerformanceMetrics('
        'tick: $currentTick, '
        'tps: ${ticksPerSecond.toStringAsFixed(1)}, '
        'avgTime: ${averageTickDuration.inMicroseconds}μs'
        ')';
  }
}
