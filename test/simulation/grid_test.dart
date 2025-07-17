import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/grid.dart';
import 'package:sims_like_game/simulation/position.dart';
import 'package:sims_like_game/simulation/tile.dart';

void main() {
  group('Grid', () {
    late Grid grid;

    setUp(() {
      grid = Grid();
    });

    test('should create grid with correct size', () {
      expect(Grid.size, equals(64));
      expect(Grid.maxCoordinate, equals(63));
      expect(Grid.minCoordinate, equals(0));
    });

    test('should initialize with grass tiles', () {
      final tile = grid.getTileAt(0, 0);
      expect(tile.floor, equals(FloorType.grass));
      expect(tile.wall, equals(WallType.none));
    });

    test('should validate positions correctly', () {
      expect(Grid.isValidPosition(const Position(0, 0)), isTrue);
      expect(Grid.isValidPosition(const Position(63, 63)), isTrue);
      expect(Grid.isValidPosition(const Position(32, 32)), isTrue);
      
      expect(Grid.isValidPosition(const Position(-1, 0)), isFalse);
      expect(Grid.isValidPosition(const Position(0, -1)), isFalse);
      expect(Grid.isValidPosition(const Position(64, 0)), isFalse);
      expect(Grid.isValidPosition(const Position(0, 64)), isFalse);
    });

    test('should validate coordinates correctly', () {
      expect(Grid.isValidCoordinate(0, 0), isTrue);
      expect(Grid.isValidCoordinate(63, 63), isTrue);
      expect(Grid.isValidCoordinate(32, 32), isTrue);
      
      expect(Grid.isValidCoordinate(-1, 0), isFalse);
      expect(Grid.isValidCoordinate(0, -1), isFalse);
      expect(Grid.isValidCoordinate(64, 0), isFalse);
      expect(Grid.isValidCoordinate(0, 64), isFalse);
    });

    test('should get and set tiles by position', () {
      const position = Position(10, 20);
      const newTile = Tile.indoor();
      
      grid.setTile(position, newTile);
      final retrievedTile = grid.getTile(position);
      
      expect(retrievedTile, equals(newTile));
    });

    test('should get and set tiles by coordinates', () {
      const newTile = Tile.indoor();
      
      grid.setTileAt(15, 25, newTile);
      final retrievedTile = grid.getTileAt(15, 25);
      
      expect(retrievedTile, equals(newTile));
    });

    test('should throw error for out of bounds access', () {
      expect(
        () => grid.getTile(const Position(-1, 0)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => grid.getTileAt(64, 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => grid.setTile(const Position(0, 64), const Tile.grass()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should safely get tiles returning null for out of bounds', () {
      expect(grid.getTileSafe(const Position(-1, 0)), isNull);
      expect(grid.getTileSafeAt(64, 0), isNull);
      expect(grid.getTileSafe(const Position(32, 32)), isNotNull);
    });

    test('should check walkability correctly', () {
      const walkablePos = Position(10, 10);
      const wallPos = Position(11, 11);
      
      // Default grass tile should be walkable
      expect(grid.isWalkable(walkablePos), isTrue);
      
      // Add a wall tile
      grid.setTile(wallPos, const Tile.wall(wallType: WallType.interior));
      expect(grid.isWalkable(wallPos), isFalse);
      
      // Out of bounds should not be walkable
      expect(grid.isWalkable(const Position(-1, 0)), isFalse);
    });

    test('should get walkable adjacent positions', () {
      const center = Position(32, 32);
      
      // All adjacent should be walkable initially (grass tiles)
      final walkableAdjacent = grid.getWalkableAdjacent(center);
      expect(walkableAdjacent, hasLength(4));
      
      // Block one adjacent tile
      grid.setTile(const Position(32, 31), const Tile.wall(wallType: WallType.interior));
      final walkableAfterBlocking = grid.getWalkableAdjacent(center);
      expect(walkableAfterBlocking, hasLength(3));
    });

    test('should get positions in rectangular area', () {
      const topLeft = Position(10, 10);
      const bottomRight = Position(12, 12);
      
      final positions = grid.getPositionsInArea(topLeft, bottomRight);
      
      expect(positions, hasLength(9)); // 3x3 area
      expect(positions, contains(const Position(10, 10)));
      expect(positions, contains(const Position(12, 12)));
      expect(positions, contains(const Position(11, 11)));
    });

    test('should get positions in circular area', () {
      const center = Position(32, 32);
      const radius = 2;
      
      final positions = grid.getPositionsInRadius(center, radius);
      
      expect(positions, contains(center));
      expect(positions, contains(const Position(30, 32))); // Distance 2
      expect(positions, contains(const Position(31, 31))); // Distance ~1.4
      expect(positions, isNot(contains(const Position(29, 32)))); // Distance 3
    });

    test('should fill area with specified tile', () {
      const topLeft = Position(5, 5);
      const bottomRight = Position(7, 7);
      const fillTile = Tile.indoor();
      
      grid.fillArea(topLeft, bottomRight, fillTile);
      
      // Check that all tiles in area are now indoor tiles
      for (int x = 5; x <= 7; x++) {
        for (int y = 5; y <= 7; y++) {
          final tile = grid.getTileAt(x, y);
          expect(tile.floor, equals(FloorType.wood));
        }
      }
    });

    test('should create room with walls and floor', () {
      const topLeft = Position(10, 10);
      const bottomRight = Position(14, 14);
      const roomId = 1;
      
      grid.createRoom(topLeft, bottomRight, roomId: roomId);
      
      // Check corners (should be walls)
      final cornerTile = grid.getTileAt(10, 10);
      expect(cornerTile.wall, equals(WallType.interior));
      expect(cornerTile.roomId, equals(roomId));
      
      // Check center (should be floor)
      final centerTile = grid.getTileAt(12, 12);
      expect(centerTile.wall, equals(WallType.none));
      expect(centerTile.floor, equals(FloorType.wood));
      expect(centerTile.roomId, equals(roomId));
    });

    test('should get all tiles with positions', () {
      final allTiles = grid.getAllTiles();
      
      expect(allTiles, hasLength(Grid.size * Grid.size));
      expect(allTiles.first.$1, equals(const Position(0, 0)));
      expect(allTiles.last.$1, equals(const Position(63, 63)));
    });

    test('should get tiles by floor type', () {
      // Add some indoor tiles
      grid.setTileAt(10, 10, const Tile.indoor());
      grid.setTileAt(11, 11, const Tile.indoor());
      
      final woodTiles = grid.getTilesByFloorType(FloorType.wood);
      expect(woodTiles, hasLength(2));
      
      final grassTiles = grid.getTilesByFloorType(FloorType.grass);
      expect(grassTiles, hasLength(Grid.size * Grid.size - 2));
    });

    test('should get tiles by room', () {
      const roomId = 5;
      
      // Create a small room
      grid.createRoom(const Position(20, 20), const Position(22, 22), roomId: roomId);
      
      final roomTiles = grid.getTilesByRoom(roomId);
      expect(roomTiles, hasLength(9)); // 3x3 room
      
      for (final (position, tile) in roomTiles) {
        expect(tile.roomId, equals(roomId));
        expect(position.x, inInclusiveRange(20, 22));
        expect(position.y, inInclusiveRange(20, 22));
      }
    });

    test('should return correct bounds', () {
      final (topLeft, bottomRight) = grid.bounds;
      
      expect(topLeft, equals(const Position(0, 0)));
      expect(bottomRight, equals(const Position(63, 63)));
    });

    test('should return correct center', () {
      final center = grid.center;
      expect(center, equals(const Position(32, 32)));
    });

    test('should serialize to and from JSON', () {
      // Modify some tiles to make the test more meaningful
      grid.setTileAt(0, 0, const Tile.indoor());
      grid.setTileAt(1, 1, const Tile.wall(wallType: WallType.interior));
      
      final json = grid.toJson();
      final restoredGrid = Grid.fromJson(json);
      
      // Check that restored grid matches original
      expect(restoredGrid.getTileAt(0, 0).floor, equals(FloorType.wood));
      expect(restoredGrid.getTileAt(1, 1).wall, equals(WallType.interior));
      expect(restoredGrid.getTileAt(2, 2).floor, equals(FloorType.grass));
    });

    test('should handle grid creation from existing tiles', () {
      // Create a custom tile grid
      final customTiles = List.generate(
        Grid.size,
        (x) => List.generate(
          Grid.size,
          (y) => const Tile.indoor(),
        ),
      );
      
      final customGrid = Grid.fromTiles(customTiles);
      
      // All tiles should be indoor tiles
      final tile = customGrid.getTileAt(32, 32);
      expect(tile.floor, equals(FloorType.wood));
    });

    test('should throw error for invalid tile grid size', () {
      final invalidTiles = List.generate(
        10, // Wrong size
        (x) => List.generate(10, (y) => const Tile.grass()),
      );
      
      expect(
        () => Grid.fromTiles(invalidTiles),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}