import '../core/simulation_clock.dart';
import '../infra/events/game_event_bus.dart';
import '../infra/events/game_events.dart';
import 'grid.dart';
import 'position.dart';

/// Core world state management for the Sims-like game
///
/// The World class manages the complete game state including the tile grid,
/// characters (Sims), interactive objects, and global world properties.
/// It processes simulation ticks and provides query methods for game systems.
class World {
  /// The tile grid representing the physical world layout
  final Grid grid;

  /// List of all Sims in the world
  final List<Sim> _sims = [];

  /// List of all interactive objects in the world
  final List<InteractiveObject> _objects = [];

  /// Global world state properties
  final Map<String, dynamic> _globalState = {};

  /// Current simulation tick
  int _currentTick = 0;

  /// World creation timestamp
  final DateTime _createdAt;

  /// Event subscription manager for cleanup
  late final EventSubscriptionManager _subscriptionManager;

  /// Create a new world with the specified grid
  World({Grid? grid}) 
      : grid = grid ?? Grid(),
        _createdAt = DateTime.now() {
    _subscriptionManager = GameEventBus.instance.createSubscriptionManager();
    _initialize();
  }

  /// Initialize the world and set up event subscriptions
  void _initialize() {
    // Subscribe to simulation tick events
    _subscriptionManager.subscribe<SimulationTickEvent>((event) {
      tick(event.tick);
    });

    // Publish world loaded event
    GameEventBus.instance.publish(
      WorldLoadedEvent(
        worldId: 'main_world',
        worldData: {
          'createdAt': _createdAt.toIso8601String(),
          'gridSize': Grid.size,
        },
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Process a single simulation tick
  ///
  /// Updates all entities in the world and handles state changes.
  /// This method is called by the simulation clock at 15Hz.
  void tick(int currentTick) {
    _currentTick = currentTick;

    try {
      // Update all Sims
      for (final sim in _sims) {
        sim.tick(currentTick, this);
      }

      // Update all interactive objects
      for (final object in _objects) {
        object.tick(currentTick, this);
      }

      // Process any global world state updates
      _processGlobalStateUpdates(currentTick);

    } catch (error, stackTrace) {
      // Handle simulation errors gracefully
      GameEventBus.instance.publishSimulationError(
        error,
        'World tick processing failed at tick $currentTick',
        stackTrace,
      );
    }
  }

  /// Process global world state updates
  void _processGlobalStateUpdates(int currentTick) {
    // Update world time
    _globalState['currentTick'] = currentTick;
    _globalState['simulationTime'] = currentTick / SimulationClock.ticksPerSecond;
    
    // Add any other global state processing here
    // (weather, time of day, global events, etc.)
  }

  /// Add a Sim to the world
  void addSim(Sim sim) {
    if (_sims.contains(sim)) {
      throw ArgumentError('Sim ${sim.id} is already in the world');
    }

    // Validate position is within grid bounds
    if (!Grid.isValidPosition(sim.position)) {
      throw ArgumentError('Sim position ${sim.position} is out of bounds');
    }

    // Ensure position is walkable
    if (!grid.isWalkable(sim.position)) {
      throw ArgumentError('Sim position ${sim.position} is not walkable');
    }

    _sims.add(sim);
    
    // Publish world state change event
    GameEventBus.instance.publish(
      WorldStateChangedEvent(
        changeType: 'sim_added',
        changes: {
          'simId': sim.id,
          'position': sim.position.toJson(),
        },
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Remove a Sim from the world
  bool removeSim(String simId) {
    final index = _sims.indexWhere((sim) => sim.id == simId);
    if (index == -1) return false;

    final removedSim = _sims.removeAt(index);
    
    // Publish world state change event
    GameEventBus.instance.publish(
      WorldStateChangedEvent(
        changeType: 'sim_removed',
        changes: {
          'simId': removedSim.id,
          'position': removedSim.position.toJson(),
        },
        timestamp: DateTime.now(),
      ),
    );

    return true;
  }

  /// Add an interactive object to the world
  void addObject(InteractiveObject object) {
    if (_objects.contains(object)) {
      throw ArgumentError('Object ${object.id} is already in the world');
    }

    // Validate position is within grid bounds
    if (!Grid.isValidPosition(object.position)) {
      throw ArgumentError('Object position ${object.position} is out of bounds');
    }

    _objects.add(object);
    
    // Publish world state change event
    GameEventBus.instance.publish(
      WorldStateChangedEvent(
        changeType: 'object_added',
        changes: {
          'objectId': object.id,
          'position': object.position.toJson(),
          'type': object.runtimeType.toString(),
        },
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Remove an interactive object from the world
  bool removeObject(String objectId) {
    final index = _objects.indexWhere((obj) => obj.id == objectId);
    if (index == -1) return false;

    final removedObject = _objects.removeAt(index);
    
    // Publish world state change event
    GameEventBus.instance.publish(
      WorldStateChangedEvent(
        changeType: 'object_removed',
        changes: {
          'objectId': removedObject.id,
          'position': removedObject.position.toJson(),
          'type': removedObject.runtimeType.toString(),
        },
        timestamp: DateTime.now(),
      ),
    );

    return true;
  }

  /// Get all objects at a specific position
  List<InteractiveObject> getObjectsAt(Position position) {
    return _objects.where((obj) => obj.position == position).toList();
  }

  /// Get all Sims at a specific position
  List<Sim> getSimsAt(Position position) {
    return _sims.where((sim) => sim.position == position).toList();
  }

  /// Get all objects within a specified range of a position
  List<InteractiveObject> getObjectsInRange(Position center, double range) {
    return _objects
        .where((obj) => center.euclideanDistanceTo(obj.position) <= range)
        .toList();
  }

  /// Get all Sims within a specified range of a position
  List<Sim> getSimsInRange(Position center, double range) {
    return _sims
        .where((sim) => center.euclideanDistanceTo(sim.position) <= range)
        .toList();
  }

  /// Get all objects of a specific type
  List<T> getObjectsOfType<T extends InteractiveObject>() {
    return _objects.whereType<T>().toList();
  }

  /// Get all Sims with a specific trait
  List<Sim> getSimsWithTrait(String traitName) {
    return _sims.where((sim) => sim.hasTrait(traitName)).toList();
  }

  /// Find the nearest object of a specific type to a position
  T? findNearestObjectOfType<T extends InteractiveObject>(Position position) {
    T? nearest;
    double nearestDistance = double.infinity;

    for (final object in _objects.whereType<T>()) {
      final distance = position.euclideanDistanceTo(object.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = object;
      }
    }

    return nearest;
  }

  /// Find the nearest Sim to a position
  Sim? findNearestSim(Position position, {String? excludeSimId}) {
    Sim? nearest;
    double nearestDistance = double.infinity;

    for (final sim in _sims) {
      if (excludeSimId != null && sim.id == excludeSimId) continue;
      
      final distance = position.euclideanDistanceTo(sim.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = sim;
      }
    }

    return nearest;
  }

  /// Check if a position is occupied by any Sim or object
  bool isPositionOccupied(Position position) {
    return getSimsAt(position).isNotEmpty || getObjectsAt(position).isNotEmpty;
  }

  /// Get all walkable positions adjacent to a given position
  List<Position> getWalkableAdjacentPositions(Position position) {
    return grid.getWalkableAdjacent(position)
        .where((pos) => !isPositionOccupied(pos))
        .toList();
  }

  /// Get global state value
  T? getGlobalState<T>(String key) {
    return _globalState[key] as T?;
  }

  /// Set global state value
  void setGlobalState(String key, dynamic value) {
    final oldValue = _globalState[key];
    _globalState[key] = value;

    // Publish state change if value actually changed
    if (oldValue != value) {
      GameEventBus.instance.publish(
        WorldStateChangedEvent(
          changeType: 'global_state_changed',
          changes: {
            'key': key,
            'oldValue': oldValue,
            'newValue': value,
          },
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Get read-only access to all Sims
  List<Sim> get sims => List.unmodifiable(_sims);

  /// Get read-only access to all objects
  List<InteractiveObject> get objects => List.unmodifiable(_objects);

  /// Get read-only access to global state
  Map<String, dynamic> get globalState => Map.unmodifiable(_globalState);

  /// Get current simulation tick
  int get currentTick => _currentTick;

  /// Get world creation timestamp
  DateTime get createdAt => _createdAt;

  /// Get total number of entities in the world
  int get entityCount => _sims.length + _objects.length;

  /// Get world statistics for debugging
  Map<String, dynamic> getStatistics() {
    return {
      'currentTick': _currentTick,
      'simulationTime': _currentTick / SimulationClock.ticksPerSecond,
      'simCount': _sims.length,
      'objectCount': _objects.length,
      'entityCount': entityCount,
      'createdAt': _createdAt.toIso8601String(),
      'gridSize': Grid.size,
      'globalStateKeys': _globalState.keys.toList(),
    };
  }

  /// Clean up world resources
  void dispose() {
    // Dispose all Sims
    for (final sim in _sims) {
      sim.dispose();
    }
    _sims.clear();

    // Dispose all objects
    for (final object in _objects) {
      object.dispose();
    }
    _objects.clear();

    // Clear global state
    _globalState.clear();

    // Dispose event subscriptions
    _subscriptionManager.dispose();
  }

  /// Convert world to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'currentTick': _currentTick,
      'createdAt': _createdAt.toIso8601String(),
      'grid': grid.toJson(),
      'sims': _sims.map((sim) => sim.toJson()).toList(),
      'objects': _objects.map((obj) => obj.toJson()).toList(),
      'globalState': _globalState,
    };
  }

  /// Create world from JSON data
  factory World.fromJson(Map<String, dynamic> json) {
    final grid = Grid.fromJson(json['grid'] as Map<String, dynamic>);
    final world = World(grid: grid);

    world._currentTick = json['currentTick'] as int;
    
    // Load global state
    final globalState = json['globalState'] as Map<String, dynamic>;
    world._globalState.addAll(globalState);

    // Load Sims (will be implemented when Sim class is available)
    final simsJson = json['sims'] as List<dynamic>;
    for (final _ in simsJson) {
      // TODO: Implement when Sim class is available
      // final sim = Sim.fromJson(simJson as Map<String, dynamic>);
      // world.addSim(sim);
    }

    // Load objects (will be implemented when InteractiveObject class is available)
    final objectsJson = json['objects'] as List<dynamic>;
    for (final _ in objectsJson) {
      // TODO: Implement when InteractiveObject class is available
      // final object = InteractiveObject.fromJson(objectJson as Map<String, dynamic>);
      // world.addObject(object);
    }

    return world;
  }

  @override
  String toString() => 'World(tick: $_currentTick, sims: ${_sims.length}, objects: ${_objects.length})';
}

/// Placeholder for Sim class (will be implemented in future tasks)
abstract class Sim {
  String get id;
  Position get position;
  
  void tick(int currentTick, World world);
  bool hasTrait(String traitName);
  void dispose();
  Map<String, dynamic> toJson();
}

/// Placeholder for InteractiveObject class (will be implemented in future tasks)
abstract class InteractiveObject {
  String get id;
  Position get position;
  
  void tick(int currentTick, World world);
  void dispose();
  Map<String, dynamic> toJson();
}