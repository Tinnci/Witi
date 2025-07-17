import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/save_data.dart';
import 'package:sims_like_game/simulation/world.dart';
import 'package:sims_like_game/simulation/grid.dart';
import 'package:sims_like_game/simulation/tile.dart';

void main() {
  group('SaveData', () {
    test('should create SaveData with required fields', () {
      final now = DateTime.now();
      final saveData = SaveData(
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        worldCreatedAt: now,
        gridData: {'size': 64, 'tiles': []},
      );

      expect(saveData.saveId, equals('test-save-1'));
      expect(saveData.saveName, equals('Test Save'));
      expect(saveData.version, equals(1));
      expect(saveData.currentTick, equals(0));
      expect(saveData.simsData, isEmpty);
      expect(saveData.objectsData, isEmpty);
      expect(saveData.globalState, isEmpty);
      expect(saveData.metadata, isEmpty);
    });

    test('should serialize to and from JSON', () {
      final now = DateTime.now();
      final originalSaveData = SaveData(
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        currentTick: 100,
        worldCreatedAt: now,
        gridData: {'size': 64, 'tiles': []},
        globalState: {'currentTick': 100, 'simulationTime': 6.67},
        metadata: {'author': 'test', 'difficulty': 'easy'},
      );

      // Serialize to JSON
      final json = originalSaveData.toJson();

      // Deserialize from JSON
      final deserializedSaveData = SaveData.fromJson(json);

      expect(deserializedSaveData.saveId, equals(originalSaveData.saveId));
      expect(deserializedSaveData.saveName, equals(originalSaveData.saveName));
      expect(deserializedSaveData.version, equals(originalSaveData.version));
      expect(
        deserializedSaveData.currentTick,
        equals(originalSaveData.currentTick),
      );
      expect(
        deserializedSaveData.globalState,
        equals(originalSaveData.globalState),
      );
      expect(deserializedSaveData.metadata, equals(originalSaveData.metadata));
    });
  });

  group('SaveDataValidator', () {
    test('should validate valid save data', () {
      final now = DateTime.now();
      final validSaveData = SaveData(
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        worldCreatedAt: now,
        gridData: {
          'size': 64,
          'tiles': List.generate(
            64,
            (x) => List.generate(
              64,
              (y) => {'floor': 'grass', 'wall': 'none', 'isExplored': true},
            ),
          ),
        },
      );

      final result = SaveDataValidator.validate(validSaveData);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.needsMigration, isFalse);
    });

    test('should detect invalid save data', () {
      final now = DateTime.now();
      final invalidSaveData = SaveData(
        saveId: '', // Empty save ID
        saveName: '', // Empty save name
        createdAt: now,
        lastModified: now.subtract(
          const Duration(days: 1),
        ), // Last modified before created
        currentTick: -1, // Negative tick
        worldCreatedAt: now,
        gridData: {
          'size': 32, // Wrong grid size
          'tiles': [],
        },
      );

      final result = SaveDataValidator.validate(invalidSaveData);

      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.errors, contains('Save ID cannot be empty'));
      expect(result.errors, contains('Save name cannot be empty'));
      expect(result.errors, contains('Current tick cannot be negative'));
      expect(
        result.errors,
        contains('Last modified date cannot be before creation date'),
      );
      expect(result.errors, contains('Invalid grid size: expected 64, got 32'));
    });

    test('should detect missing grid data fields', () {
      final now = DateTime.now();
      final saveDataMissingGridFields = SaveData(
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        worldCreatedAt: now,
        gridData: {}, // Missing size and tiles
      );

      final result = SaveDataValidator.validate(saveDataMissingGridFields);

      expect(result.isValid, isFalse);
      expect(result.errors, contains('Grid data missing size field'));
    });

    test('should validate global state', () {
      final now = DateTime.now();
      final saveDataWithInvalidGlobalState = SaveData(
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        worldCreatedAt: now,
        gridData: {
          'size': 64,
          'tiles': List.generate(
            64,
            (x) => List.generate(
              64,
              (y) => {'floor': 'grass', 'wall': 'none', 'isExplored': true},
            ),
          ),
        },
        globalState: {
          'currentTick': 'invalid', // Should be int
          'simulationTime': -1, // Should be non-negative
        },
      );

      final result = SaveDataValidator.validate(saveDataWithInvalidGlobalState);

      // The validation should still pass overall, but have warnings
      expect(result.isValid, isTrue);
      expect(
        result.warnings,
        contains('Global state currentTick should be a non-negative integer'),
      );
      expect(
        result.warnings,
        contains('Global state simulationTime should be a non-negative number'),
      );
    });
  });

  group('SaveDataMigrator', () {
    test('should not migrate current version save data', () {
      final now = DateTime.now();
      final currentVersionSaveData = SaveData(
        version: SaveDataValidator.currentVersion,
        saveId: 'test-save-1',
        saveName: 'Test Save',
        createdAt: now,
        lastModified: now,
        worldCreatedAt: now,
        gridData: {'size': 64, 'tiles': []},
      );

      final migrated = SaveDataMigrator.migrate(currentVersionSaveData);

      expect(migrated, equals(currentVersionSaveData));
    });
  });

  group('World Serialization', () {
    test('should create SaveData from World', () {
      final world = World();

      // Add some global state
      world.setGlobalState('testKey', 'testValue');
      world.setGlobalState('currentTick', 50);

      final saveData = world.toSaveData(
        saveId: 'world-save-1',
        saveName: 'World Save Test',
        metadata: {'source': 'test'},
      );

      expect(saveData.saveId, equals('world-save-1'));
      expect(saveData.saveName, equals('World Save Test'));
      expect(saveData.currentTick, equals(world.currentTick));
      expect(saveData.worldCreatedAt, equals(world.createdAt));
      expect(saveData.globalState['testKey'], equals('testValue'));
      expect(saveData.globalState['currentTick'], equals(50));
      expect(saveData.metadata['source'], equals('test'));
    });

    test('should create World from SaveData', () {
      final now = DateTime.now();

      // Create a grid with some custom tiles
      final grid = Grid();
      grid.setTileAt(0, 0, const Tile.indoor(floor: FloorType.wood, roomId: 1));
      grid.setTileAt(
        1,
        1,
        const Tile.wall(wallType: WallType.interior, roomId: 1),
      );

      final saveData = SaveData(
        saveId: 'test-world-save',
        saveName: 'Test World',
        createdAt: now,
        lastModified: now,
        currentTick: 150,
        worldCreatedAt: now.subtract(const Duration(hours: 1)),
        gridData: grid.toJson(),
        globalState: {
          'currentTick': 150,
          'simulationTime': 10.0,
          'customValue': 'test',
        },
      );

      final world = World.fromSaveData(saveData);

      expect(world.currentTick, equals(150));
      expect(world.getGlobalState<int>('currentTick'), equals(150));
      expect(world.getGlobalState<double>('simulationTime'), equals(10.0));
      expect(world.getGlobalState<String>('customValue'), equals('test'));

      // Check that grid was loaded correctly
      final loadedTile00 = world.grid.getTileAt(0, 0);
      expect(loadedTile00.floor, equals(FloorType.wood));
      expect(loadedTile00.roomId, equals(1));

      final loadedTile11 = world.grid.getTileAt(1, 1);
      expect(loadedTile11.wall, equals(WallType.interior));
      expect(loadedTile11.roomId, equals(1));
    });

    test('should round-trip World through SaveData', () {
      final originalWorld = World();

      // Set up some state
      originalWorld.setGlobalState('testValue', 42);
      originalWorld.setGlobalState('testString', 'hello world');

      // Modify the grid
      originalWorld.grid.setTileAt(
        5,
        5,
        const Tile.indoor(floor: FloorType.stone, roomId: 2),
      );
      originalWorld.grid.setTileAt(
        10,
        10,
        const Tile.wall(wallType: WallType.exterior),
      );

      // Convert to SaveData
      final saveData = originalWorld.toSaveData(
        saveId: 'round-trip-test',
        saveName: 'Round Trip Test',
      );

      // Convert back to World
      final restoredWorld = World.fromSaveData(saveData);

      // Verify state was preserved
      expect(restoredWorld.getGlobalState<int>('testValue'), equals(42));
      expect(
        restoredWorld.getGlobalState<String>('testString'),
        equals('hello world'),
      );

      // Verify grid was preserved
      final tile55 = restoredWorld.grid.getTileAt(5, 5);
      expect(tile55.floor, equals(FloorType.stone));
      expect(tile55.roomId, equals(2));

      final tile1010 = restoredWorld.grid.getTileAt(10, 10);
      expect(tile1010.wall, equals(WallType.exterior));
    });
  });
}
