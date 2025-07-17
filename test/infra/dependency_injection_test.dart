import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/infra/dependency_injection.dart';
import 'package:sims_like_game/core/simulation_clock.dart';
import 'package:sims_like_game/core/debug_clock_controller.dart';
import 'package:sims_like_game/infra/events/game_event_bus.dart';
import 'package:sims_like_game/infra/logging/game_logger.dart';
import 'package:sims_like_game/infra/error_handling/simulation_error_handler.dart';
import 'package:sims_like_game/infra/error_handling/render_error_handler.dart';

void main() {
  group('DependencyInjection', () {
    setUp(() async {
      // Reset dependency injection before each test
      await DependencyInjection.reset();
    });

    tearDown(() async {
      // Clean up after each test
      await DependencyInjection.reset();
    });

    test('should initialize all core services', () async {
      await DependencyInjection.initialize(isTestMode: true);
      await DependencyInjection.waitForReady();

      expect(DependencyInjection.isRegistered<SeededRandom>(), isTrue);
      expect(DependencyInjection.isRegistered<GameLogger>(), isTrue);
      expect(DependencyInjection.isRegistered<GameEventBus>(), isTrue);
      expect(
        DependencyInjection.isRegistered<SimulationErrorHandler>(),
        isTrue,
      );
      expect(DependencyInjection.isRegistered<RenderErrorHandler>(), isTrue);
      expect(DependencyInjection.isRegistered<SimulationClock>(), isTrue);
      expect(DependencyInjection.isRegistered<DebugClockController>(), isTrue);
    });

    test('should provide access to registered services', () async {
      await DependencyInjection.initialize(isTestMode: true);
      await DependencyInjection.waitForReady();

      final random = DependencyInjection.get<SeededRandom>();
      final logger = DependencyInjection.get<GameLogger>();
      final eventBus = DependencyInjection.get<GameEventBus>();
      final simulationErrorHandler =
          DependencyInjection.get<SimulationErrorHandler>();
      final renderErrorHandler = DependencyInjection.get<RenderErrorHandler>();
      final clock = DependencyInjection.get<SimulationClock>();
      final debugController = DependencyInjection.get<DebugClockController>();

      expect(random, isNotNull);
      expect(logger, isNotNull);
      expect(eventBus, isNotNull);
      expect(simulationErrorHandler, isNotNull);
      expect(renderErrorHandler, isNotNull);
      expect(clock, isNotNull);
      expect(debugController, isNotNull);
    });

    test('should use deterministic random seed', () async {
      const testSeed = 12345;
      await DependencyInjection.initialize(
        randomSeed: testSeed,
        isTestMode: true,
      );
      await DependencyInjection.waitForReady();

      final random = DependencyInjection.get<SeededRandom>();
      expect(random.seed, equals(testSeed));
    });

    test('should provide singleton instances', () async {
      await DependencyInjection.initialize(isTestMode: true);
      await DependencyInjection.waitForReady();

      final logger1 = DependencyInjection.get<GameLogger>();
      final logger2 = DependencyInjection.get<GameLogger>();
      expect(identical(logger1, logger2), isTrue);

      final eventBus1 = DependencyInjection.get<GameEventBus>();
      final eventBus2 = DependencyInjection.get<GameEventBus>();
      expect(identical(eventBus1, eventBus2), isTrue);

      final clock1 = DependencyInjection.get<SimulationClock>();
      final clock2 = DependencyInjection.get<SimulationClock>();
      expect(identical(clock1, clock2), isTrue);
    });

    test('should handle service dependencies correctly', () async {
      await DependencyInjection.initialize(isTestMode: true);
      await DependencyInjection.waitForReady();

      final clock = DependencyInjection.get<SimulationClock>();
      final debugController = DependencyInjection.get<DebugClockController>();

      // Debug controller should be using the same clock instance
      expect(debugController.clock, equals(clock));
    });

    test('should reset properly', () async {
      await DependencyInjection.initialize(isTestMode: true);
      await DependencyInjection.waitForReady();

      expect(DependencyInjection.isRegistered<GameLogger>(), isTrue);

      await DependencyInjection.reset();

      expect(DependencyInjection.isRegistered<GameLogger>(), isFalse);
    });
  });

  group('SeededRandom', () {
    test('should produce deterministic results', () {
      const seed = 42;
      final random1 = SeededRandom(seed);
      final random2 = SeededRandom(seed);

      expect(random1.nextInt(100), equals(random2.nextInt(100)));
      expect(random1.nextDouble(), equals(random2.nextDouble()));
      expect(random1.nextBool(), equals(random2.nextBool()));
    });

    test('should provide utility methods', () {
      final random = SeededRandom(123);

      final rangeInt = random.nextIntInRange(10, 20);
      expect(rangeInt, greaterThanOrEqualTo(10));
      expect(rangeInt, lessThanOrEqualTo(20));

      final rangeDouble = random.nextDoubleInRange(1.0, 2.0);
      expect(rangeDouble, greaterThanOrEqualTo(1.0));
      expect(rangeDouble, lessThan(2.0));

      final list = [1, 2, 3, 4, 5];
      final choice = random.choice(list);
      expect(list, contains(choice));

      final shuffleList = [1, 2, 3, 4, 5];
      random.shuffle(shuffleList);
      expect(shuffleList, hasLength(5));
      expect(shuffleList, containsAll([1, 2, 3, 4, 5]));
    });

    test('should handle edge cases', () {
      final random = SeededRandom(999);

      expect(() => random.choice([]), throwsArgumentError);
      expect(random.nextIntInRange(5, 5), equals(5));
    });
  });
}
