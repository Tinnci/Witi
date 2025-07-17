import 'dart:async';
import 'dart:math' as math;

import 'simulation_clock.dart';

/// Deterministic implementation of SimulationClock with 15Hz fixed timestep
/// 
/// This implementation ensures reproducible gameplay by maintaining a fixed
/// simulation rate regardless of rendering framerate or system performance.
class DeterministicSimulationClock implements SimulationClock {
  static const List<double> _SPEED_MULTIPLIERS = [0.5, 1.0, 2.0, 3.0];
  
  Timer? _timer;
  final StreamController<TickEvent> _tickController = StreamController<TickEvent>.broadcast();
  
  int _currentTick = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  double _speedMultiplier = 1.0;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _totalPausedDuration = Duration.zero;
  
  @override
  int get currentTick => _currentTick;
  
  @override
  bool get isRunning => _isRunning;
  
  @override
  bool get isPaused => _isPaused;
  
  @override
  double get speedMultiplier => _speedMultiplier;
  
  @override
  Stream<TickEvent> get tickStream => _tickController.stream;
  
  @override
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _isPaused = false;
    _startTime ??= DateTime.now();
    
    if (_pauseTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
    }
    
    _scheduleNextTick();
  }
  
  @override
  void pause() {
    if (!_isRunning || _isPaused) return;
    
    _isPaused = true;
    _pauseTime = DateTime.now();
    _timer?.cancel();
    _timer = null;
  }
  
  @override
  void resume() {
    if (!_isPaused) return;
    
    _isPaused = false;
    
    if (_pauseTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
    }
    
    _scheduleNextTick();
  }
  
  @override
  void step() {
    if (_isRunning && !_isPaused) {
      throw StateError('Cannot step while clock is running. Pause first.');
    }
    
    _executeTick();
  }
  
  @override
  void setSpeedMultiplier(double multiplier) {
    // Clamp to valid speed multipliers
    _speedMultiplier = _SPEED_MULTIPLIERS.reduce((a, b) => 
        (a - multiplier).abs() < (b - multiplier).abs() ? a : b);
    
    // Restart timer with new speed if running
    if (_isRunning && !_isPaused) {
      _timer?.cancel();
      _scheduleNextTick();
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isPaused = false;
    _tickController.close();
  }
  
  void _scheduleNextTick() {
    if (!_isRunning || _isPaused) return;
    
    final adjustedDuration = Duration(
      milliseconds: (TICK_DURATION.inMilliseconds / _speedMultiplier).round(),
    );
    
    _timer = Timer(adjustedDuration, () {
      _executeTick();
      _scheduleNextTick();
    });
  }
  
  void _executeTick() {
    _currentTick++;
    
    final simulationTime = _currentTick / TICKS_PER_SECOND;
    final deltaTime = Duration(
      milliseconds: (TICK_DURATION.inMilliseconds * _speedMultiplier).round(),
    );
    
    final tickEvent = TickEvent(
      tick: _currentTick,
      simulationTime: simulationTime,
      deltaTime: deltaTime,
    );
    
    _tickController.add(tickEvent);
  }
  
  /// Get elapsed real time since simulation started (excluding paused time)
  Duration get elapsedRealTime {
    if (_startTime == null) return Duration.zero;
    
    final now = DateTime.now();
    final totalElapsed = now.difference(_startTime!);
    final currentPauseDuration = _isPaused && _pauseTime != null 
        ? now.difference(_pauseTime!) 
        : Duration.zero;
    
    return totalElapsed - _totalPausedDuration - currentPauseDuration;
  }
  
  /// Get simulation time as duration (tick-based)
  Duration get simulationTime => Duration(
    milliseconds: (_currentTick * TICK_DURATION.inMilliseconds).round(),
  );
  
  /// Reset the clock to initial state
  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentTick = 0;
    _isRunning = false;
    _isPaused = false;
    _speedMultiplier = 1.0;
    _startTime = null;
    _pauseTime = null;
    _totalPausedDuration = Duration.zero;
  }
  
  @override
  String toString() {
    return 'DeterministicSimulationClock('
        'tick: $_currentTick, '
        'running: $_isRunning, '
        'paused: $_isPaused, '
        'speed: ${_speedMultiplier}x'
        ')';
  }
}