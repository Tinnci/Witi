/// Core simulation clock interface for deterministic 15Hz fixed timestep
///
/// This clock ensures reproducible gameplay by running simulation logic
/// at a fixed 15 Hz (67ms per tick) regardless of rendering framerate.
abstract class SimulationClock {
  /// Fixed simulation frequency: 15 ticks per second
  static const int ticksPerSecond = 15;

  /// Duration of each simulation tick: ~67 milliseconds
  static const Duration tickDuration = Duration(milliseconds: 67);

  /// Start the simulation clock
  void start();

  /// Pause the simulation clock
  void pause();

  /// Resume the simulation clock
  void resume();

  /// Execute a single simulation tick (for debugging)
  void step();

  /// Stream of tick events for subscribers
  Stream<TickEvent> get tickStream;

  /// Current simulation tick number
  int get currentTick;

  /// Whether the clock is currently running
  bool get isRunning;

  /// Whether the clock is paused
  bool get isPaused;

  /// Game speed multiplier (0.5x, 1x, 2x, 3x)
  double get speedMultiplier;

  /// Set game speed multiplier
  void setSpeedMultiplier(double multiplier);

  /// Dispose resources
  void dispose();
}

/// Event emitted on each simulation tick
class TickEvent {
  /// The current tick number
  final int tick;

  /// Time elapsed since simulation started (in ticks)
  final double simulationTime;

  /// Delta time for this tick (always TICK_DURATION unless speed modified)
  final Duration deltaTime;

  const TickEvent({
    required this.tick,
    required this.simulationTime,
    required this.deltaTime,
  });

  @override
  String toString() => 'TickEvent(tick: $tick, time: ${simulationTime}s)';
}
