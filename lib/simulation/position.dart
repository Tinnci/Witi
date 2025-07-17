import 'dart:math' as math;

/// Represents a position in the 2D grid with isometric coordinate conversion utilities
///
/// This class handles both grid coordinates (x, y) and screen coordinates for
/// isometric rendering. Grid coordinates are integers representing tile positions,
/// while screen coordinates are used for rendering and visual positioning.
class Position {
  /// Grid X coordinate (tile position)
  final int x;

  /// Grid Y coordinate (tile position)
  final int y;

  const Position(this.x, this.y);

  /// Create position from screen coordinates (for mouse/touch input)
  factory Position.fromScreen(double screenX, double screenY) {
    // Convert isometric screen coordinates back to grid coordinates
    // Using inverse of the isometric projection matrix
    final gridX = ((screenX / _tileWidth) + (screenY / _tileHeight)).round();
    final gridY = ((screenY / _tileHeight) - (screenX / _tileWidth)).round();
    
    return Position(gridX, gridY);
  }

  /// Tile width in pixels for isometric projection
  static const double _tileWidth = 64.0;
  
  /// Tile height in pixels for isometric projection  
  static const double _tileHeight = 32.0;

  /// Convert grid coordinates to isometric screen coordinates
  /// Returns the center point of the tile in screen space
  (double x, double y) toScreen() {
    final screenX = (x - y) * (_tileWidth / 2);
    final screenY = (x + y) * (_tileHeight / 2);
    return (screenX, screenY);
  }

  /// Get the screen coordinates as a record for easier destructuring
  (double x, double y) get screenCoordinates => toScreen();

  /// Calculate Manhattan distance to another position
  int distanceTo(Position other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  /// Calculate Euclidean distance to another position
  double euclideanDistanceTo(Position other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Get all adjacent positions (4-directional)
  List<Position> get adjacentPositions => [
    Position(x, y - 1), // North
    Position(x + 1, y), // East
    Position(x, y + 1), // South
    Position(x - 1, y), // West
  ];

  /// Get all adjacent positions including diagonals (8-directional)
  List<Position> get allAdjacentPositions => [
    Position(x, y - 1),     // North
    Position(x + 1, y - 1), // Northeast
    Position(x + 1, y),     // East
    Position(x + 1, y + 1), // Southeast
    Position(x, y + 1),     // South
    Position(x - 1, y + 1), // Southwest
    Position(x - 1, y),     // West
    Position(x - 1, y - 1), // Northwest
  ];

  /// Check if this position is adjacent to another position
  bool isAdjacentTo(Position other) {
    final dx = (x - other.x).abs();
    final dy = (y - other.y).abs();
    return (dx <= 1 && dy <= 1) && (dx + dy > 0);
  }

  /// Move in a direction by the specified distance
  Position move(Direction direction, [int distance = 1]) {
    return switch (direction) {
      Direction.north => Position(x, y - distance),
      Direction.northeast => Position(x + distance, y - distance),
      Direction.east => Position(x + distance, y),
      Direction.southeast => Position(x + distance, y + distance),
      Direction.south => Position(x, y + distance),
      Direction.southwest => Position(x - distance, y + distance),
      Direction.west => Position(x - distance, y),
      Direction.northwest => Position(x - distance, y - distance),
    };
  }

  /// Get the direction to another position
  Direction? directionTo(Position other) {
    final dx = other.x - x;
    final dy = other.y - y;
    
    if (dx == 0 && dy == 0) return null;
    
    // Normalize to -1, 0, or 1
    final ndx = dx.sign;
    final ndy = dy.sign;
    
    return switch ((ndx, ndy)) {
      (0, -1) => Direction.north,
      (1, -1) => Direction.northeast,
      (1, 0) => Direction.east,
      (1, 1) => Direction.southeast,
      (0, 1) => Direction.south,
      (-1, 1) => Direction.southwest,
      (-1, 0) => Direction.west,
      (-1, -1) => Direction.northwest,
      _ => null,
    };
  }

  /// Create a new position with modified coordinates
  Position copyWith({int? x, int? y}) {
    return Position(x ?? this.x, y ?? this.y);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'Position($x, $y)';

  /// Convert to a JSON-serializable map
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  /// Create from a JSON map
  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['x'] as int, json['y'] as int);
  }
}

/// Eight cardinal and intercardinal directions
enum Direction {
  north,
  northeast,
  east,
  southeast,
  south,
  southwest,
  west,
  northwest;

  /// Get the opposite direction
  Direction get opposite => switch (this) {
    Direction.north => Direction.south,
    Direction.northeast => Direction.southwest,
    Direction.east => Direction.west,
    Direction.southeast => Direction.northwest,
    Direction.south => Direction.north,
    Direction.southwest => Direction.northeast,
    Direction.west => Direction.east,
    Direction.northwest => Direction.southeast,
  };

  /// Get the direction rotated clockwise by 45 degrees
  Direction get clockwise => switch (this) {
    Direction.north => Direction.northeast,
    Direction.northeast => Direction.east,
    Direction.east => Direction.southeast,
    Direction.southeast => Direction.south,
    Direction.south => Direction.southwest,
    Direction.southwest => Direction.west,
    Direction.west => Direction.northwest,
    Direction.northwest => Direction.north,
  };

  /// Get the direction rotated counter-clockwise by 45 degrees
  Direction get counterClockwise => switch (this) {
    Direction.north => Direction.northwest,
    Direction.northwest => Direction.west,
    Direction.west => Direction.southwest,
    Direction.southwest => Direction.south,
    Direction.south => Direction.southeast,
    Direction.southeast => Direction.east,
    Direction.east => Direction.northeast,
    Direction.northeast => Direction.north,
  };

  /// Check if this is a cardinal direction (N, E, S, W)
  bool get isCardinal => switch (this) {
    Direction.north || Direction.east || Direction.south || Direction.west => true,
    _ => false,
  };

  /// Check if this is a diagonal direction (NE, SE, SW, NW)
  bool get isDiagonal => !isCardinal;
}