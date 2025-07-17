import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/world.dart';
import 'package:sims_like_game/simulation/grid.dart';
import 'package:sims_like_game/simulation/position.dart';
import 'package:sims_like_game/simulation/tile.dart';
import 'package:sims_like_game/infra/events/game_event_bus.dart';
import 'package:sims_like_game/infra/events/game_events.dart';

// Test implementations of abstract classes
class TestSim extends Sim {
  @override
  final String id;
  
  @override
  final Position position;
  
  final List<String> traits;
  bool _disposed = false;
  int _lastTick = -1;

  TestSim({
    required this.id,
    required this.position,
    this.traits = const [],
  });

  @override
  void tick(int currentTick, World world) {
    _lastTick = currentTick;
  }

  @override
  bool hasTrait(String traitName) {
    return traits.contains(traitName);
  }

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position.toJson(),
      'traits': traits,
    };
  }

  bool get isDisposed => _disposed;
  int get lastTick => _lastTick;
}

class TestInteractiveObject extends InteractiveObject {
  @override
  final String id;
  
  @override
  final Position position;
  
  final String objectType;
  bool _disposed = false;
  int _lastTick = -1;

  TestInteractiveObject({
    required this.id,
    required this.position,
    this.objectType = 'test_object',
  });

  @override
  void tick(int currentTick, World world) {
    _lastTick = currentTick;
  }

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position.toJson(),
      'type': objectType,
    };
  }

  bool get isDisposed => _disposed;
  int get lastTick => _lastTick;
}

void main() {
  group('World', () {
    late World world;
    late GameEventBus eventBus;

    setUp(() {
      // Reset event bus for each test
      GameEventBus.instance.dispose();
      eventBus = GameEventBus.instance;
      world = World();
    });

    tearDown(() {
      world.dispose();
      eventBus.dispose();
    });

    group('Initialization', () {
      test('creates world with default grid', () {
        expect(world.grid, isA<Grid>());
        expect(world.sims, isEmpty);
        expect(world.objects, isEmpty);
        expect(world.currentTick, equals(0));
        expect(world.entityCount, equals(0));
      });

      test('creates world with custom grid', () {
        final customGrid = Grid();
        customGrid.setTileAt(0, 0, const Tile.indoor());
        
        final customWorld = World(grid: customGrid);
        expect(customWorld.grid.getTileAt(0, 0).floor, equals(FloorType.wood));
        
        customWorld.dispose();
      });

      test('publishes WorldLoadedEvent on creation', () async {
        // Reset event bus and set up subscription before creating world
        GameEventBus.instance.dispose();
        final freshEventBus = GameEventBus.instance;
        
        WorldLoadedEvent? capturedEvent;
        freshEventBus.subscribe<WorldLoadedEvent>((event) {
          capturedEvent = event;
        });

        final newWorld = World();
        
        // Give the event bus time to process
        await Future.delayed(Duration.zero);
        
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.worldId, equals('main_world'));
        expect(capturedEvent!.worldData['gridSize'], equals(Grid.size));
        
        newWorld.dispose();
        freshEventBus.dispose();
      });
    });

    group('Sim Management', () {
      test('adds sim successfully', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        
        world.addSim(sim);
        
        expect(world.sims, contains(sim));
        expect(world.entityCount, equals(1));
      });

      test('throws error when adding duplicate sim', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        world.addSim(sim);
        
        expect(() => world.addSim(sim), throwsArgumentError);
      });

      test('throws error when adding sim at invalid position', () {
        final sim = TestSim(id: 'test_sim', position: const Position(-1, 5));
        
        expect(() => world.addSim(sim), throwsArgumentError);
      });

      test('throws error when adding sim at non-walkable position', () {
        // Create a wall tile
        world.grid.setTileAt(10, 10, const Tile.wall(wallType: WallType.interior));
        final sim = TestSim(id: 'test_sim', position: const Position(10, 10));
        
        expect(() => world.addSim(sim), throwsArgumentError);
      });

      test('removes sim successfully', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        world.addSim(sim);
        
        final removed = world.removeSim('test_sim');
        
        expect(removed, isTrue);
        expect(world.sims, isEmpty);
        expect(world.entityCount, equals(0));
      });

      test('returns false when removing non-existent sim', () {
        final removed = world.removeSim('non_existent');
        expect(removed, isFalse);
      });

      test('publishes events when adding/removing sims', () async {
        final events = <WorldStateChangedEvent>[];
        eventBus.subscribe<WorldStateChangedEvent>((event) {
          events.add(event);
        });

        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        
        world.addSim(sim);
        world.removeSim('test_sim');
        
        // Give the event bus time to process
        await Future.delayed(Duration.zero);
        
        expect(events, hasLength(2));
        expect(events[0].changeType, equals('sim_added'));
        expect(events[1].changeType, equals('sim_removed'));
      });
    });

    group('Object Management', () {
      test('adds object successfully', () {
        final object = TestInteractiveObject(
          id: 'test_object',
          position: const Position(10, 10),
        );
        
        world.addObject(object);
        
        expect(world.objects, contains(object));
        expect(world.entityCount, equals(1));
      });

      test('throws error when adding duplicate object', () {
        final object = TestInteractiveObject(
          id: 'test_object',
          position: const Position(10, 10),
        );
        world.addObject(object);
        
        expect(() => world.addObject(object), throwsArgumentError);
      });

      test('throws error when adding object at invalid position', () {
        final object = TestInteractiveObject(
          id: 'test_object',
          position: const Position(100, 100),
        );
        
        expect(() => world.addObject(object), throwsArgumentError);
      });

      test('removes object successfully', () {
        final object = TestInteractiveObject(
          id: 'test_object',
          position: const Position(10, 10),
        );
        world.addObject(object);
        
        final removed = world.removeObject('test_object');
        
        expect(removed, isTrue);
        expect(world.objects, isEmpty);
        expect(world.entityCount, equals(0));
      });

      test('returns false when removing non-existent object', () {
        final removed = world.removeObject('non_existent');
        expect(removed, isFalse);
      });

      test('publishes events when adding/removing objects', () async {
        final events = <WorldStateChangedEvent>[];
        eventBus.subscribe<WorldStateChangedEvent>((event) {
          events.add(event);
        });

        final object = TestInteractiveObject(
          id: 'test_object',
          position: const Position(10, 10),
        );
        
        world.addObject(object);
        world.removeObject('test_object');
        
        // Give the event bus time to process
        await Future.delayed(Duration.zero);
        
        expect(events, hasLength(2));
        expect(events[0].changeType, equals('object_added'));
        expect(events[1].changeType, equals('object_removed'));
      });
    });

    group('World State Queries', () {
      late TestSim sim1, sim2;
      late TestInteractiveObject object1, object2;

      setUp(() {
        sim1 = TestSim(id: 'sim1', position: const Position(5, 5));
        sim2 = TestSim(id: 'sim2', position: const Position(10, 10));
        object1 = TestInteractiveObject(id: 'obj1', position: const Position(5, 5));
        object2 = TestInteractiveObject(id: 'obj2', position: const Position(15, 15));
        
        world.addSim(sim1);
        world.addSim(sim2);
        world.addObject(object1);
        world.addObject(object2);
      });

      test('getObjectsAt returns objects at specific position', () {
        final objects = world.getObjectsAt(const Position(5, 5));
        expect(objects, contains(object1));
        expect(objects, hasLength(1));
      });

      test('getSimsAt returns sims at specific position', () {
        final sims = world.getSimsAt(const Position(5, 5));
        expect(sims, contains(sim1));
        expect(sims, hasLength(1));
      });

      test('getObjectsInRange returns objects within range', () {
        final objects = world.getObjectsInRange(const Position(5, 5), 10.0);
        expect(objects, contains(object1));
        expect(objects, hasLength(1));
        
        // Test with larger range to include both objects
        final objectsLargeRange = world.getObjectsInRange(const Position(5, 5), 15.0);
        expect(objectsLargeRange, contains(object1));
        expect(objectsLargeRange, contains(object2));
        expect(objectsLargeRange, hasLength(2));
      });

      test('getSimsInRange returns sims within range', () {
        final sims = world.getSimsInRange(const Position(7, 7), 5.0);
        expect(sims, contains(sim1));
        expect(sims, contains(sim2));
        expect(sims, hasLength(2));
      });

      test('getObjectsOfType returns objects of specific type', () {
        final objects = world.getObjectsOfType<TestInteractiveObject>();
        expect(objects, hasLength(2));
        expect(objects, contains(object1));
        expect(objects, contains(object2));
      });

      test('getSimsWithTrait returns sims with specific trait', () {
        final traitedSim = TestSim(
          id: 'traited_sim',
          position: const Position(20, 20),
          traits: ['friendly', 'outgoing'],
        );
        world.addSim(traitedSim);
        
        final friendlySims = world.getSimsWithTrait('friendly');
        expect(friendlySims, contains(traitedSim));
        expect(friendlySims, hasLength(1));
      });

      test('findNearestObjectOfType returns closest object', () {
        final nearest = world.findNearestObjectOfType<TestInteractiveObject>(
          const Position(6, 6),
        );
        expect(nearest, equals(object1));
      });

      test('findNearestSim returns closest sim', () {
        final nearest = world.findNearestSim(const Position(6, 6));
        expect(nearest, equals(sim1));
      });

      test('findNearestSim excludes specified sim', () {
        final nearest = world.findNearestSim(
          const Position(6, 6),
          excludeSimId: 'sim1',
        );
        expect(nearest, equals(sim2));
      });

      test('isPositionOccupied returns true when occupied', () {
        expect(world.isPositionOccupied(const Position(5, 5)), isTrue);
        expect(world.isPositionOccupied(const Position(0, 0)), isFalse);
      });

      test('getWalkableAdjacentPositions returns unoccupied walkable positions', () {
        final adjacent = world.getWalkableAdjacentPositions(const Position(5, 5));
        
        // Should exclude the occupied position (5,5) but include walkable adjacent ones
        expect(adjacent, isNotEmpty);
        expect(adjacent, everyElement(isA<Position>()));
        
        // Verify none of the returned positions are occupied
        for (final pos in adjacent) {
          expect(world.isPositionOccupied(pos), isFalse);
        }
      });
    });

    group('Global State Management', () {
      test('sets and gets global state values', () {
        world.setGlobalState('test_key', 'test_value');
        expect(world.getGlobalState<String>('test_key'), equals('test_value'));
      });

      test('returns null for non-existent keys', () {
        expect(world.getGlobalState<String>('non_existent'), isNull);
      });

      test('publishes event when global state changes', () async {
        WorldStateChangedEvent? capturedEvent;
        eventBus.subscribe<WorldStateChangedEvent>((event) {
          if (event.changeType == 'global_state_changed') {
            capturedEvent = event;
          }
        });

        world.setGlobalState('test_key', 'new_value');
        
        // Give the event bus time to process
        await Future.delayed(Duration.zero);
        
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.changes['key'], equals('test_key'));
        expect(capturedEvent!.changes['newValue'], equals('new_value'));
      });

      test('does not publish event when value unchanged', () {
        world.setGlobalState('test_key', 'value');
        
        int eventCount = 0;
        eventBus.subscribe<WorldStateChangedEvent>((event) {
          if (event.changeType == 'global_state_changed') {
            eventCount++;
          }
        });

        world.setGlobalState('test_key', 'value'); // Same value
        expect(eventCount, equals(0));
      });
    });

    group('Tick Processing', () {
      test('processes tick and updates entities', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        final object = TestInteractiveObject(id: 'test_obj', position: const Position(10, 10));
        
        world.addSim(sim);
        world.addObject(object);
        
        world.tick(42);
        
        expect(world.currentTick, equals(42));
        expect(sim.lastTick, equals(42));
        expect(object.lastTick, equals(42));
        expect(world.getGlobalState<int>('currentTick'), equals(42));
      });

      test('handles tick processing errors gracefully', () async {
        // Create a sim that throws an error during tick
        final errorSim = _ErrorSim(id: 'error_sim', position: const Position(5, 5));
        world.addSim(errorSim);
        
        SimulationErrorEvent? capturedError;
        eventBus.subscribe<SimulationErrorEvent>((event) {
          capturedError = event;
        });
        
        // Should not throw, but should publish error event
        expect(() => world.tick(1), returnsNormally);
        
        // Give the event bus time to process
        await Future.delayed(Duration.zero);
        
        expect(capturedError, isNotNull);
        expect(capturedError!.context, contains('World tick processing failed'));
      });
    });

    group('Statistics and Debugging', () {
      test('getStatistics returns comprehensive world info', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        final object = TestInteractiveObject(id: 'test_obj', position: const Position(10, 10));
        
        world.addSim(sim);
        world.addObject(object);
        world.setGlobalState('test_key', 'test_value');
        world.tick(10);
        
        final stats = world.getStatistics();
        
        expect(stats['currentTick'], equals(10));
        expect(stats['simCount'], equals(1));
        expect(stats['objectCount'], equals(1));
        expect(stats['entityCount'], equals(2));
        expect(stats['gridSize'], equals(Grid.size));
        expect(stats['globalStateKeys'], contains('test_key'));
      });
    });

    group('Serialization', () {
      test('converts to JSON successfully', () {
        world.setGlobalState('test_key', 'test_value');
        world.tick(5);
        
        final json = world.toJson();
        
        expect(json['currentTick'], equals(5));
        expect(json['globalState']['test_key'], equals('test_value'));
        expect(json['grid'], isA<Map<String, dynamic>>());
        expect(json['sims'], isA<List>());
        expect(json['objects'], isA<List>());
      });

      test('creates from JSON successfully', () {
        final originalWorld = World();
        originalWorld.setGlobalState('test_key', 'test_value');
        originalWorld.tick(5);
        
        final json = originalWorld.toJson();
        final restoredWorld = World.fromJson(json);
        
        expect(restoredWorld.currentTick, equals(5));
        expect(restoredWorld.getGlobalState<String>('test_key'), equals('test_value'));
        
        originalWorld.dispose();
        restoredWorld.dispose();
      });
    });

    group('Resource Management', () {
      test('disposes resources properly', () {
        final sim = TestSim(id: 'test_sim', position: const Position(5, 5));
        final object = TestInteractiveObject(id: 'test_obj', position: const Position(10, 10));
        
        world.addSim(sim);
        world.addObject(object);
        
        world.dispose();
        
        expect(sim.isDisposed, isTrue);
        expect(object.isDisposed, isTrue);
        expect(world.sims, isEmpty);
        expect(world.objects, isEmpty);
        expect(world.globalState, isEmpty);
      });
    });
  });
}

// Helper class for testing error handling
class _ErrorSim extends TestSim {
  _ErrorSim({required super.id, required super.position});

  @override
  void tick(int currentTick, World world) {
    throw Exception('Test error during tick');
  }
}