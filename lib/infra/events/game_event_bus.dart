import 'dart:async';
import 'package:event_bus/event_bus.dart';
import '../../core/simulation_clock.dart';
import 'game_events.dart';

/// Centralized event bus for the Sims-like game
///
/// Provides type-safe event publishing and subscription with automatic
/// cleanup and debugging capabilities.
class GameEventBus {
  static GameEventBus? _instance;
  static GameEventBus get instance => _instance ??= GameEventBus._();

  final EventBus _eventBus = EventBus();
  final Map<Type, int> _eventCounts = {};
  final List<GameEvent> _eventHistory = [];
  final Set<StreamSubscription> _activeSubscriptions = {};

  static const int maxHistory = 1000;

  GameEventBus._();

  /// Publish an event to all subscribers
  void publish<T extends GameEvent>(T event) {
    // Track event statistics
    _eventCounts[T] = (_eventCounts[T] ?? 0) + 1;

    // Add to history (with size limit)
    _eventHistory.add(event);
    if (_eventHistory.length > maxHistory) {
      _eventHistory.removeAt(0);
    }

    // Publish to event bus
    _eventBus.fire(event);
  }

  /// Subscribe to events of a specific type
  StreamSubscription<T> subscribe<T extends GameEvent>(
    void Function(T event) onEvent, {
    bool Function(T event)? where,
  }) {
    final subscription = _eventBus
        .on<T>()
        .where(where ?? (_) => true)
        .listen(onEvent);
    _activeSubscriptions.add(subscription);
    return subscription;
  }

  /// Subscribe to multiple event types
  List<StreamSubscription> subscribeMultiple<T extends GameEvent>(
    List<Type> eventTypes,
    void Function(T event) onEvent, {
    bool Function(T event)? where,
  }) {
    final subscriptions = <StreamSubscription>[];

    for (final eventType in eventTypes) {
      final subscription = _eventBus
          .on<T>()
          .where((event) {
            if (event.runtimeType != eventType) return false;
            return where?.call(event) ?? true;
          })
          .listen(onEvent);

      subscriptions.add(subscription);
      _activeSubscriptions.add(subscription);
    }

    return subscriptions;
  }

  /// Create a subscription manager for automatic cleanup
  EventSubscriptionManager createSubscriptionManager() {
    return EventSubscriptionManager._(this);
  }

  /// Get event statistics for debugging
  Map<Type, int> get eventCounts => Map.unmodifiable(_eventCounts);

  /// Get recent event history for debugging
  List<GameEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Get count of active subscriptions
  int get activeSubscriptionCount => _activeSubscriptions.length;

  /// Clear event history and statistics
  void clearHistory() {
    _eventHistory.clear();
    _eventCounts.clear();
  }

  /// Dispose of a subscription and remove from tracking
  void _disposeSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _activeSubscriptions.remove(subscription);
  }

  /// Get debug information as formatted string
  String getDebugInfo() {
    final totalEvents = _eventCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final topEvents = _eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer();
    buffer.writeln('Event Bus Debug Info:');
    buffer.writeln('  Total Events: $totalEvents');
    buffer.writeln('  Active Subscriptions: $activeSubscriptionCount');
    buffer.writeln('  History Size: ${_eventHistory.length}');
    buffer.writeln('  Top Event Types:');

    for (int i = 0; i < topEvents.length && i < 5; i++) {
      final entry = topEvents[i];
      buffer.writeln(
        '    ${entry.key.toString().split('.').last}: ${entry.value}',
      );
    }

    return buffer.toString();
  }

  /// Dispose all resources (for testing)
  void dispose() {
    for (final subscription in _activeSubscriptions.toList()) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _eventHistory.clear();
    _eventCounts.clear();
  }
}

/// Manages event subscriptions with automatic cleanup
///
/// Use this to ensure subscriptions are properly disposed when
/// components are destroyed (e.g., in Flutter widgets or game components).
class EventSubscriptionManager {
  final GameEventBus _eventBus;
  final Set<StreamSubscription> _subscriptions = {};
  bool _disposed = false;

  EventSubscriptionManager._(this._eventBus);

  /// Subscribe to events with automatic cleanup
  StreamSubscription<T> subscribe<T extends GameEvent>(
    void Function(T event) onEvent, {
    bool Function(T event)? where,
  }) {
    if (_disposed) {
      throw StateError('EventSubscriptionManager has been disposed');
    }

    final subscription = _eventBus.subscribe<T>(onEvent, where: where);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Subscribe to multiple event types with automatic cleanup
  List<StreamSubscription> subscribeMultiple<T extends GameEvent>(
    List<Type> eventTypes,
    void Function(T event) onEvent, {
    bool Function(T event)? where,
  }) {
    if (_disposed) {
      throw StateError('EventSubscriptionManager has been disposed');
    }

    final subscriptions = _eventBus.subscribeMultiple<T>(
      eventTypes,
      onEvent,
      where: where,
    );
    _subscriptions.addAll(subscriptions);
    return subscriptions;
  }

  /// Manually unsubscribe from a specific subscription
  void unsubscribe(StreamSubscription subscription) {
    if (_subscriptions.contains(subscription)) {
      _eventBus._disposeSubscription(subscription);
      _subscriptions.remove(subscription);
    }
  }

  /// Get count of managed subscriptions
  int get subscriptionCount => _subscriptions.length;

  /// Dispose all managed subscriptions
  void dispose() {
    if (_disposed) return;

    for (final subscription in _subscriptions) {
      _eventBus._disposeSubscription(subscription);
    }
    _subscriptions.clear();
    _disposed = true;
  }

  /// Whether this manager has been disposed
  bool get isDisposed => _disposed;
}

/// Convenience methods for common event operations
extension GameEventBusExtensions on GameEventBus {
  /// Publish a simulation tick event
  void publishTick(TickEvent tickEvent) {
    publish(
      SimulationTickEvent(tickEvent: tickEvent, timestamp: DateTime.now()),
    );
  }

  /// Publish a simulation error
  void publishSimulationError(
    Object error,
    String context, [
    StackTrace? stackTrace,
  ]) {
    publish(
      SimulationErrorEvent(
        error: error,
        context: context,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Publish a render error
  void publishRenderError(
    Object error,
    String context, [
    StackTrace? stackTrace,
  ]) {
    publish(
      RenderErrorEvent(
        error: error,
        context: context,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Publish a user input event
  void publishUserInput(String inputType, Map<String, dynamic> data) {
    publish(
      UserInputEvent(
        inputType: inputType,
        data: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Publish a sound play request
  void publishPlaySound(String soundId, String audioGroup, double volume) {
    publish(
      PlaySoundEvent(
        soundId: soundId,
        audioGroup: audioGroup,
        volume: volume,
        timestamp: DateTime.now(),
      ),
    );
  }
}
