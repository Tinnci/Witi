import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/infra/events/game_event_bus.dart';
import 'package:sims_like_game/infra/events/game_events.dart';
import 'package:sims_like_game/core/simulation_clock.dart';

void main() {
  group('GameEventBus', () {
    late GameEventBus eventBus;

    setUp(() {
      eventBus = GameEventBus.instance;
      eventBus.clearHistory(); // Clear any previous test data
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('should be a singleton', () {
      final instance1 = GameEventBus.instance;
      final instance2 = GameEventBus.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should publish and receive events', () async {
      final receivedEvents = <SimulationStartedEvent>[];

      final subscription = eventBus.subscribe<SimulationStartedEvent>(
        (event) => receivedEvents.add(event),
      );

      final testEvent = SimulationStartedEvent(timestamp: DateTime.now());
      eventBus.publish(testEvent);

      // Wait for event to be processed
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first, equals(testEvent));

      subscription.cancel();
    });

    test('should filter events with where clause', () async {
      final receivedEvents = <SimulationSpeedChangedEvent>[];

      final subscription = eventBus.subscribe<SimulationSpeedChangedEvent>(
        (event) => receivedEvents.add(event),
        where: (event) => event.newSpeed > 1.0,
      );

      // This should be filtered out
      eventBus.publish(
        SimulationSpeedChangedEvent(
          oldSpeed: 1.0,
          newSpeed: 0.5,
          timestamp: DateTime.now(),
        ),
      );

      // This should pass through
      eventBus.publish(
        SimulationSpeedChangedEvent(
          oldSpeed: 1.0,
          newSpeed: 2.0,
          timestamp: DateTime.now(),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.newSpeed, equals(2.0));

      subscription.cancel();
    });

    test('should track event statistics', () {
      final event1 = SimulationStartedEvent(timestamp: DateTime.now());
      final event2 = SimulationPausedEvent(timestamp: DateTime.now());
      final event3 = SimulationStartedEvent(timestamp: DateTime.now());

      eventBus.publish(event1);
      eventBus.publish(event2);
      eventBus.publish(event3);

      final counts = eventBus.eventCounts;
      expect(counts[SimulationStartedEvent], equals(2));
      expect(counts[SimulationPausedEvent], equals(1));
    });

    test('should maintain event history', () {
      final event1 = SimulationStartedEvent(timestamp: DateTime.now());
      final event2 = SimulationPausedEvent(timestamp: DateTime.now());

      eventBus.publish(event1);
      eventBus.publish(event2);

      final history = eventBus.eventHistory;
      expect(history.length, equals(2));
      expect(history[0], equals(event1));
      expect(history[1], equals(event2));
    });

    test('should limit history size', () {
      // Publish more events than the history limit
      for (int i = 0; i < 1100; i++) {
        eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));
      }

      final history = eventBus.eventHistory;
      expect(history.length, equals(1000)); // Should be capped at MAX_HISTORY
    });

    test('should provide debug information', () {
      eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));
      eventBus.publish(SimulationPausedEvent(timestamp: DateTime.now()));

      final debugInfo = eventBus.getDebugInfo();
      expect(debugInfo, contains('Total Events: 2'));
      expect(debugInfo, contains('History Size: 2'));
      expect(debugInfo, contains('SimulationStartedEvent'));
    });

    test('should clear history and statistics', () {
      eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));

      expect(eventBus.eventHistory.length, equals(1));
      expect(eventBus.eventCounts.isNotEmpty, isTrue);

      eventBus.clearHistory();

      expect(eventBus.eventHistory.length, equals(0));
      expect(eventBus.eventCounts.isEmpty, isTrue);
    });
  });

  group('EventSubscriptionManager', () {
    late GameEventBus eventBus;
    late EventSubscriptionManager manager;

    setUp(() {
      eventBus = GameEventBus.instance;
      eventBus.clearHistory();
      manager = eventBus.createSubscriptionManager();
    });

    tearDown(() {
      manager.dispose();
      eventBus.dispose();
    });

    test('should manage subscriptions automatically', () async {
      final receivedEvents = <SimulationStartedEvent>[];

      manager.subscribe<SimulationStartedEvent>(
        (event) => receivedEvents.add(event),
      );

      expect(manager.subscriptionCount, equals(1));

      eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));

      manager.dispose();
      expect(manager.subscriptionCount, equals(0));
      expect(manager.isDisposed, isTrue);
    });

    test('should handle multiple subscriptions', () async {
      final startEvents = <SimulationStartedEvent>[];
      final pauseEvents = <SimulationPausedEvent>[];

      manager.subscribe<SimulationStartedEvent>(
        (event) => startEvents.add(event),
      );

      manager.subscribe<SimulationPausedEvent>(
        (event) => pauseEvents.add(event),
      );

      expect(manager.subscriptionCount, equals(2));

      eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));
      eventBus.publish(SimulationPausedEvent(timestamp: DateTime.now()));

      await Future.delayed(const Duration(milliseconds: 10));

      expect(startEvents.length, equals(1));
      expect(pauseEvents.length, equals(1));
    });

    test('should prevent operations after disposal', () {
      manager.dispose();

      expect(
        () => manager.subscribe<SimulationStartedEvent>((_) {}),
        throwsStateError,
      );
    });

    test('should allow manual unsubscription', () async {
      final receivedEvents = <SimulationStartedEvent>[];

      final subscription = manager.subscribe<SimulationStartedEvent>(
        (event) => receivedEvents.add(event),
      );

      expect(manager.subscriptionCount, equals(1));

      manager.unsubscribe(subscription);
      expect(manager.subscriptionCount, equals(0));

      // Event should not be received after unsubscription
      eventBus.publish(SimulationStartedEvent(timestamp: DateTime.now()));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(0));
    });
  });

  group('GameEventBusExtensions', () {
    late GameEventBus eventBus;

    setUp(() {
      eventBus = GameEventBus.instance;
      eventBus.clearHistory();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('should publish tick events', () async {
      final receivedEvents = <SimulationTickEvent>[];

      final subscription = eventBus.subscribe<SimulationTickEvent>(
        (event) => receivedEvents.add(event),
      );

      final tickEvent = TickEvent(
        tick: 1,
        simulationTime: 1.0 / 15.0,
        deltaTime: const Duration(milliseconds: 67),
      );

      eventBus.publishTick(tickEvent);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.tick, equals(1));
      expect(receivedEvents.first.simulationTime, closeTo(1.0 / 15.0, 0.01));

      subscription.cancel();
    });

    test('should publish error events', () async {
      final simulationErrors = <SimulationErrorEvent>[];
      final renderErrors = <RenderErrorEvent>[];

      final sub1 = eventBus.subscribe<SimulationErrorEvent>(
        (event) => simulationErrors.add(event),
      );

      final sub2 = eventBus.subscribe<RenderErrorEvent>(
        (event) => renderErrors.add(event),
      );

      eventBus.publishSimulationError(
        Exception('Test simulation error'),
        'test context',
      );

      eventBus.publishRenderError(
        Exception('Test render error'),
        'render context',
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(simulationErrors.length, equals(1));
      expect(simulationErrors.first.context, equals('test context'));

      expect(renderErrors.length, equals(1));
      expect(renderErrors.first.context, equals('render context'));

      sub1.cancel();
      sub2.cancel();
    });

    test('should publish user input events', () async {
      final receivedEvents = <UserInputEvent>[];

      final subscription = eventBus.subscribe<UserInputEvent>(
        (event) => receivedEvents.add(event),
      );

      eventBus.publishUserInput('keyboard', {'key': 'space', 'pressed': true});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.inputType, equals('keyboard'));
      expect(receivedEvents.first.data['key'], equals('space'));

      subscription.cancel();
    });

    test('should publish sound events', () async {
      final receivedEvents = <PlaySoundEvent>[];

      final subscription = eventBus.subscribe<PlaySoundEvent>(
        (event) => receivedEvents.add(event),
      );

      eventBus.publishPlaySound('click', 'ui', 0.8);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.soundId, equals('click'));
      expect(receivedEvents.first.audioGroup, equals('ui'));
      expect(receivedEvents.first.volume, equals(0.8));

      subscription.cancel();
    });
  });
}
