import '../../../core/simulation_clock.dart';

/// Base class for all game events
abstract class GameEvent {
  /// Timestamp when the event was created
  final DateTime timestamp;

  /// Optional event ID for tracking
  final String? id;

  const GameEvent({required this.timestamp, this.id});

  @override
  String toString() =>
      '$runtimeType(timestamp: $timestamp${id != null ? ', id: $id' : ''})';
}

/// Events related to simulation lifecycle
abstract class SimulationEvent extends GameEvent {
  const SimulationEvent({required super.timestamp, super.id});
}

/// Event emitted when simulation starts
class SimulationStartedEvent extends SimulationEvent {
  const SimulationStartedEvent({required super.timestamp, super.id});
}

/// Event emitted when simulation is paused
class SimulationPausedEvent extends SimulationEvent {
  const SimulationPausedEvent({required super.timestamp, super.id});
}

/// Event emitted when simulation is resumed
class SimulationResumedEvent extends SimulationEvent {
  const SimulationResumedEvent({required super.timestamp, super.id});
}

/// Event emitted when simulation speed changes
class SimulationSpeedChangedEvent extends SimulationEvent {
  final double oldSpeed;
  final double newSpeed;

  const SimulationSpeedChangedEvent({
    required this.oldSpeed,
    required this.newSpeed,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() =>
      'SimulationSpeedChangedEvent(${oldSpeed}x -> ${newSpeed}x)';
}

/// Event emitted on each simulation tick (extends the core TickEvent)
class SimulationTickEvent extends SimulationEvent {
  final TickEvent tickEvent;

  const SimulationTickEvent({
    required this.tickEvent,
    required super.timestamp,
    super.id,
  });

  /// Convenience getters from the wrapped TickEvent
  int get tick => tickEvent.tick;
  double get simulationTime => tickEvent.simulationTime;
  Duration get deltaTime => tickEvent.deltaTime;

  @override
  String toString() =>
      'SimulationTickEvent(tick: $tick, time: ${simulationTime}s)';
}

/// Events related to error handling
abstract class ErrorEvent extends GameEvent {
  final Object error;
  final StackTrace? stackTrace;
  final String context;

  const ErrorEvent({
    required this.error,
    required this.context,
    this.stackTrace,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => '$runtimeType(error: $error, context: $context)';
}

/// Event for simulation-related errors
class SimulationErrorEvent extends ErrorEvent {
  const SimulationErrorEvent({
    required super.error,
    required super.context,
    super.stackTrace,
    required super.timestamp,
    super.id,
  });
}

/// Event for rendering-related errors
class RenderErrorEvent extends ErrorEvent {
  const RenderErrorEvent({
    required super.error,
    required super.context,
    super.stackTrace,
    required super.timestamp,
    super.id,
  });
}

/// Events related to user interface
abstract class UIEvent extends GameEvent {
  const UIEvent({required super.timestamp, super.id});
}

/// Event emitted when debug overlay is toggled
class DebugOverlayToggledEvent extends UIEvent {
  final bool isVisible;

  const DebugOverlayToggledEvent({
    required this.isVisible,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'DebugOverlayToggledEvent(visible: $isVisible)';
}

/// Event emitted when user input is received
class UserInputEvent extends UIEvent {
  final String inputType;
  final Map<String, dynamic> data;

  const UserInputEvent({
    required this.inputType,
    required this.data,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'UserInputEvent(type: $inputType, data: $data)';
}

/// Events related to game world
abstract class WorldEvent extends GameEvent {
  const WorldEvent({required super.timestamp, super.id});
}

/// Event emitted when world is loaded
class WorldLoadedEvent extends WorldEvent {
  final String worldId;
  final Map<String, dynamic> worldData;

  const WorldLoadedEvent({
    required this.worldId,
    required this.worldData,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'WorldLoadedEvent(worldId: $worldId)';
}

/// Event emitted when world state changes
class WorldStateChangedEvent extends WorldEvent {
  final String changeType;
  final Map<String, dynamic> changes;

  const WorldStateChangedEvent({
    required this.changeType,
    required this.changes,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'WorldStateChangedEvent(type: $changeType)';
}

/// Events related to audio system
abstract class AudioEvent extends GameEvent {
  const AudioEvent({required super.timestamp, super.id});
}

/// Event to request sound playback
class PlaySoundEvent extends AudioEvent {
  final String soundId;
  final String audioGroup;
  final double volume;

  const PlaySoundEvent({
    required this.soundId,
    required this.audioGroup,
    required this.volume,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() =>
      'PlaySoundEvent(sound: $soundId, group: $audioGroup, volume: $volume)';
}

/// Event emitted when audio volume changes
class AudioVolumeChangedEvent extends AudioEvent {
  final String audioGroup;
  final double oldVolume;
  final double newVolume;

  const AudioVolumeChangedEvent({
    required this.audioGroup,
    required this.oldVolume,
    required this.newVolume,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() =>
      'AudioVolumeChangedEvent(group: $audioGroup, $oldVolume -> $newVolume)';
}

/// Events related to save/load system
abstract class SaveEvent extends GameEvent {
  const SaveEvent({required super.timestamp, super.id});
}

/// Event emitted when game is saved
class GameSavedEvent extends SaveEvent {
  final String saveId;
  final bool isAutosave;

  const GameSavedEvent({
    required this.saveId,
    required this.isAutosave,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'GameSavedEvent(saveId: $saveId, autosave: $isAutosave)';
}

/// Event emitted when game is loaded
class GameLoadedEvent extends SaveEvent {
  final String saveId;
  final Map<String, dynamic> saveData;

  const GameLoadedEvent({
    required this.saveId,
    required this.saveData,
    required super.timestamp,
    super.id,
  });

  @override
  String toString() => 'GameLoadedEvent(saveId: $saveId)';
}
