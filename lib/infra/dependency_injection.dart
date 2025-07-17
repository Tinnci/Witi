import 'dart:math' as math;

import 'package:get_it/get_it.dart';

import '../core/simulation_clock.dart';
import '../core/deterministic_simulation_clock.dart';
import '../core/debug_clock_controller.dart';
import 'events/game_event_bus.dart';
import 'logging/game_logger.dart';
import 'error_handling/simulation_error_handler.dart';
import 'error_handling/render_error_handler.dart';

/// Dependency injection container for the Sims-like game
///
/// Provides centralized service registration and dependency management
/// using the get_it service locator pattern.
class DependencyInjection {
  static final GetIt _instance = GetIt.instance;

  /// Get the service locator instance
  static GetIt get instance => _instance;

  /// Initialize all dependencies for the game
  static Future<void> initialize({
    int? randomSeed,
    bool isTestMode = false,
  }) async {
    // Register core services
    await _registerCoreServices(randomSeed, isTestMode);

    // Register infrastructure services
    await _registerInfrastructureServices();

    // Register simulation services
    await _registerSimulationServices();
  }

  /// Register core platform services
  static Future<void> _registerCoreServices(
    int? randomSeed,
    bool isTestMode,
  ) async {
    // Register deterministic random number generator
    final seed = randomSeed ?? DateTime.now().millisecondsSinceEpoch;
    _instance.registerSingleton<SeededRandom>(
      SeededRandom(seed),
      signalsReady: true,
    );

    // Register logger (use test mode if specified)
    _instance.registerSingleton<GameLogger>(
      isTestMode ? GameLogger.forTesting() : GameLogger(),
      signalsReady: true,
    );
  }

  /// Register infrastructure services
  static Future<void> _registerInfrastructureServices() async {
    // Register event bus (check if already registered as singleton)
    if (!_instance.isRegistered<GameEventBus>()) {
      _instance.registerSingleton<GameEventBus>(
        GameEventBus.instance,
        signalsReady: true,
      );
    }

    // Register error handlers
    final simulationErrorHandler = SimulationErrorHandler();
    simulationErrorHandler.initialize();
    _instance.registerSingleton<SimulationErrorHandler>(
      simulationErrorHandler,
      signalsReady: true,
    );

    final renderErrorHandler = RenderErrorHandler();
    renderErrorHandler.initialize();
    _instance.registerSingleton<RenderErrorHandler>(
      renderErrorHandler,
      signalsReady: true,
    );
  }

  /// Register simulation services
  static Future<void> _registerSimulationServices() async {
    // Register simulation clock
    _instance.registerSingleton<SimulationClock>(
      DeterministicSimulationClock(),
      signalsReady: true,
    );

    // Register debug controller (depends on simulation clock)
    _instance.registerSingleton<DebugClockController>(
      DebugClockController(_instance<SimulationClock>()),
      signalsReady: true,
    );
  }

  /// Wait for all services to be ready
  static Future<void> waitForReady() async {
    await _instance.allReady();
  }

  /// Reset all dependencies (for testing)
  static Future<void> reset() async {
    await _instance.reset();
  }

  /// Get a registered service
  static T get<T extends Object>() => _instance<T>();

  /// Check if a service is registered
  static bool isRegistered<T extends Object>() => _instance.isRegistered<T>();
}

/// Deterministic random number generator for simulation consistency
///
/// Ensures that the simulation produces identical results given the same
/// initial seed, which is crucial for deterministic gameplay and testing.
class SeededRandom {
  final math.Random _random;
  final int seed;

  /// Create a seeded random number generator
  SeededRandom(this.seed) : _random = math.Random(seed);

  /// Generate a random integer from 0 (inclusive) to [max] (exclusive)
  int nextInt(int max) => _random.nextInt(max);

  /// Generate a random double from 0.0 (inclusive) to 1.0 (exclusive)
  double nextDouble() => _random.nextDouble();

  /// Generate a random boolean
  bool nextBool() => _random.nextBool();

  /// Generate a random double within a range
  double nextDoubleInRange(double min, double max) {
    return min + (_random.nextDouble() * (max - min));
  }

  /// Generate a random integer within a range (inclusive)
  int nextIntInRange(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  /// Choose a random element from a list
  T choice<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot choose from empty list');
    }
    return items[nextInt(items.length)];
  }

  /// Shuffle a list in-place deterministically
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  @override
  String toString() => 'SeededRandom(seed: $seed)';
}
