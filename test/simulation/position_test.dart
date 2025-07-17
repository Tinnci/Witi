import 'package:flutter_test/flutter_test.dart';
import 'package:sims_like_game/simulation/position.dart';

void main() {
  group('Position', () {
    test('should create position with correct coordinates', () {
      const position = Position(5, 10);
      expect(position.x, equals(5));
      expect(position.y, equals(10));
    });

    test('should convert to screen coordinates correctly', () {
      const position = Position(4, 2);
      final (screenX, screenY) = position.toScreen();
      
      // Expected: (4-2) * 32 = 64, (4+2) * 16 = 96
      expect(screenX, equals(64.0));
      expect(screenY, equals(96.0));
    });

    test('should convert from screen coordinates correctly', () {
      const position = Position(4, 2);
      final (screenX, screenY) = position.toScreen();
      final converted = Position.fromScreen(screenX, screenY);
      
      expect(converted.x, equals(position.x));
      expect(converted.y, equals(position.y));
    });

    test('should calculate Manhattan distance correctly', () {
      const pos1 = Position(0, 0);
      const pos2 = Position(3, 4);
      
      expect(pos1.distanceTo(pos2), equals(7));
      expect(pos2.distanceTo(pos1), equals(7));
    });

    test('should calculate Euclidean distance correctly', () {
      const pos1 = Position(0, 0);
      const pos2 = Position(3, 4);
      
      expect(pos1.euclideanDistanceTo(pos2), equals(5.0));
      expect(pos2.euclideanDistanceTo(pos1), equals(5.0));
    });

    test('should return correct adjacent positions', () {
      const center = Position(5, 5);
      final adjacent = center.adjacentPositions;
      
      expect(adjacent, hasLength(4));
      expect(adjacent, contains(const Position(5, 4))); // North
      expect(adjacent, contains(const Position(6, 5))); // East
      expect(adjacent, contains(const Position(5, 6))); // South
      expect(adjacent, contains(const Position(4, 5))); // West
    });

    test('should return correct all adjacent positions including diagonals', () {
      const center = Position(5, 5);
      final allAdjacent = center.allAdjacentPositions;
      
      expect(allAdjacent, hasLength(8));
      expect(allAdjacent, contains(const Position(5, 4))); // North
      expect(allAdjacent, contains(const Position(6, 4))); // Northeast
      expect(allAdjacent, contains(const Position(6, 5))); // East
      expect(allAdjacent, contains(const Position(6, 6))); // Southeast
      expect(allAdjacent, contains(const Position(5, 6))); // South
      expect(allAdjacent, contains(const Position(4, 6))); // Southwest
      expect(allAdjacent, contains(const Position(4, 5))); // West
      expect(allAdjacent, contains(const Position(4, 4))); // Northwest
    });

    test('should correctly identify adjacent positions', () {
      const center = Position(5, 5);
      const adjacent = Position(5, 4);
      const diagonal = Position(6, 4);
      const distant = Position(8, 8);
      
      expect(center.isAdjacentTo(adjacent), isTrue);
      expect(center.isAdjacentTo(diagonal), isTrue);
      expect(center.isAdjacentTo(distant), isFalse);
      expect(center.isAdjacentTo(center), isFalse); // Same position
    });

    test('should move in directions correctly', () {
      const start = Position(5, 5);
      
      expect(start.move(Direction.north), equals(const Position(5, 4)));
      expect(start.move(Direction.northeast), equals(const Position(6, 4)));
      expect(start.move(Direction.east), equals(const Position(6, 5)));
      expect(start.move(Direction.southeast), equals(const Position(6, 6)));
      expect(start.move(Direction.south), equals(const Position(5, 6)));
      expect(start.move(Direction.southwest), equals(const Position(4, 6)));
      expect(start.move(Direction.west), equals(const Position(4, 5)));
      expect(start.move(Direction.northwest), equals(const Position(4, 4)));
    });

    test('should move with distance correctly', () {
      const start = Position(5, 5);
      
      expect(start.move(Direction.north, 3), equals(const Position(5, 2)));
      expect(start.move(Direction.east, 2), equals(const Position(7, 5)));
    });

    test('should determine direction to another position', () {
      const center = Position(5, 5);
      
      expect(center.directionTo(const Position(5, 4)), equals(Direction.north));
      expect(center.directionTo(const Position(6, 4)), equals(Direction.northeast));
      expect(center.directionTo(const Position(6, 5)), equals(Direction.east));
      expect(center.directionTo(const Position(6, 6)), equals(Direction.southeast));
      expect(center.directionTo(const Position(5, 6)), equals(Direction.south));
      expect(center.directionTo(const Position(4, 6)), equals(Direction.southwest));
      expect(center.directionTo(const Position(4, 5)), equals(Direction.west));
      expect(center.directionTo(const Position(4, 4)), equals(Direction.northwest));
      expect(center.directionTo(center), isNull); // Same position
    });

    test('should create copy with modified coordinates', () {
      const original = Position(5, 5);
      final modified = original.copyWith(x: 10);
      
      expect(modified.x, equals(10));
      expect(modified.y, equals(5));
      expect(original.x, equals(5)); // Original unchanged
    });

    test('should implement equality correctly', () {
      const pos1 = Position(5, 5);
      const pos2 = Position(5, 5);
      const pos3 = Position(5, 6);
      
      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
      expect(pos1.hashCode, equals(pos2.hashCode));
    });

    test('should serialize to and from JSON', () {
      const original = Position(10, 20);
      final json = original.toJson();
      final restored = Position.fromJson(json);
      
      expect(restored, equals(original));
      expect(json, equals({'x': 10, 'y': 20}));
    });
  });

  group('Direction', () {
    test('should return correct opposite directions', () {
      expect(Direction.north.opposite, equals(Direction.south));
      expect(Direction.northeast.opposite, equals(Direction.southwest));
      expect(Direction.east.opposite, equals(Direction.west));
      expect(Direction.southeast.opposite, equals(Direction.northwest));
      expect(Direction.south.opposite, equals(Direction.north));
      expect(Direction.southwest.opposite, equals(Direction.northeast));
      expect(Direction.west.opposite, equals(Direction.east));
      expect(Direction.northwest.opposite, equals(Direction.southeast));
    });

    test('should rotate clockwise correctly', () {
      expect(Direction.north.clockwise, equals(Direction.northeast));
      expect(Direction.northeast.clockwise, equals(Direction.east));
      expect(Direction.east.clockwise, equals(Direction.southeast));
      expect(Direction.southeast.clockwise, equals(Direction.south));
      expect(Direction.south.clockwise, equals(Direction.southwest));
      expect(Direction.southwest.clockwise, equals(Direction.west));
      expect(Direction.west.clockwise, equals(Direction.northwest));
      expect(Direction.northwest.clockwise, equals(Direction.north));
    });

    test('should rotate counter-clockwise correctly', () {
      expect(Direction.north.counterClockwise, equals(Direction.northwest));
      expect(Direction.northwest.counterClockwise, equals(Direction.west));
      expect(Direction.west.counterClockwise, equals(Direction.southwest));
      expect(Direction.southwest.counterClockwise, equals(Direction.south));
      expect(Direction.south.counterClockwise, equals(Direction.southeast));
      expect(Direction.southeast.counterClockwise, equals(Direction.east));
      expect(Direction.east.counterClockwise, equals(Direction.northeast));
      expect(Direction.northeast.counterClockwise, equals(Direction.north));
    });

    test('should identify cardinal directions correctly', () {
      expect(Direction.north.isCardinal, isTrue);
      expect(Direction.east.isCardinal, isTrue);
      expect(Direction.south.isCardinal, isTrue);
      expect(Direction.west.isCardinal, isTrue);
      
      expect(Direction.northeast.isCardinal, isFalse);
      expect(Direction.southeast.isCardinal, isFalse);
      expect(Direction.southwest.isCardinal, isFalse);
      expect(Direction.northwest.isCardinal, isFalse);
    });

    test('should identify diagonal directions correctly', () {
      expect(Direction.northeast.isDiagonal, isTrue);
      expect(Direction.southeast.isDiagonal, isTrue);
      expect(Direction.southwest.isDiagonal, isTrue);
      expect(Direction.northwest.isDiagonal, isTrue);
      
      expect(Direction.north.isDiagonal, isFalse);
      expect(Direction.east.isDiagonal, isFalse);
      expect(Direction.south.isDiagonal, isFalse);
      expect(Direction.west.isDiagonal, isFalse);
    });
  });
}