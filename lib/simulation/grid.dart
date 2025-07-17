import 'position.dart';
import 'tile.dart';

/// Manages a 64x64 grid of tiles for the game world
///
/// This class provides bounds checking, tile access, and coordinate validation
/// for the fixed-size world grid. All coordinates are validated to ensure
/// they fall within the valid range.
class Grid {
  /// Fixed grid size (64x64 tiles)
  static const int size = 64;
  
  /// Maximum valid coordinate (inclusive)
  static const int maxCoordinate = size - 1;
  
  /// Minimum valid coordinate
  static const int minCoordinate = 0;

  /// Internal storage for tiles
  final List<List<Tile>> _tiles;

  /// Create a new grid with default grass tiles
  Grid() : _tiles = List.generate(
    size,
    (x) => List.generate(
      size,
      (y) => const Tile.grass(),
    ),
  );

  /// Create a grid from existing tile data
  Grid.fromTiles(List<List<Tile>> tiles) : _tiles = tiles {
    if (tiles.length != size || tiles.any((row) => row.length != size)) {
      throw ArgumentError('Grid must be exactly ${size}x$size tiles');
    }
  }

  /// Check if a position is within the valid grid bounds
  static bool isValidPosition(Position position) {
    return position.x >= minCoordinate &&
           position.x <= maxCoordinate &&
           position.y >= minCoordinate &&
           position.y <= maxCoordinate;
  }

  /// Check if coordinates are within the valid grid bounds
  static bool isValidCoordinate(int x, int y) {
    return x >= minCoordinate &&
           x <= maxCoordinate &&
           y >= minCoordinate &&
           y <= maxCoordinate;
  }

  /// Get the tile at the specified position
  /// Throws ArgumentError if position is out of bounds
  Tile getTile(Position position) {
    if (!isValidPosition(position)) {
      throw ArgumentError('Position $position is out of bounds');
    }
    return _tiles[position.x][position.y];
  }

  /// Get the tile at the specified coordinates
  /// Throws ArgumentError if coordinates are out of bounds
  Tile getTileAt(int x, int y) {
    if (!isValidCoordinate(x, y)) {
      throw ArgumentError('Coordinates ($x, $y) are out of bounds');
    }
    return _tiles[x][y];
  }

  /// Set the tile at the specified position
  /// Throws ArgumentError if position is out of bounds
  void setTile(Position position, Tile tile) {
    if (!isValidPosition(position)) {
      throw ArgumentError('Position $position is out of bounds');
    }
    _tiles[position.x][position.y] = tile;
  }

  /// Set the tile at the specified coordinates
  /// Throws ArgumentError if coordinates are out of bounds
  void setTileAt(int x, int y, Tile tile) {
    if (!isValidCoordinate(x, y)) {
      throw ArgumentError('Coordinates ($x, $y) are out of bounds');
    }
    _tiles[x][y] = tile;
  }

  /// Safely get a tile, returning null if position is out of bounds
  Tile? getTileSafe(Position position) {
    if (!isValidPosition(position)) {
      return null;
    }
    return _tiles[position.x][position.y];
  }

  /// Safely get a tile by coordinates, returning null if out of bounds
  Tile? getTileSafeAt(int x, int y) {
    if (!isValidCoordinate(x, y)) {
      return null;
    }
    return _tiles[x][y];
  }

  /// Check if a position is walkable (within bounds and tile allows movement)
  bool isWalkable(Position position) {
    final tile = getTileSafe(position);
    return tile?.isWalkable ?? false;
  }

  /// Check if coordinates are walkable
  bool isWalkableAt(int x, int y) {
    final tile = getTileSafeAt(x, y);
    return tile?.isWalkable ?? false;
  }

  /// Get all walkable adjacent positions to the given position
  List<Position> getWalkableAdjacent(Position position) {
    return position.adjacentPositions
        .where((pos) => isWalkable(pos))
        .toList();
  }

  /// Get all positions within a rectangular area
  List<Position> getPositionsInArea(Position topLeft, Position bottomRight) {
    final positions = <Position>[];
    
    final minX = topLeft.x.clamp(minCoordinate, maxCoordinate);
    final maxX = bottomRight.x.clamp(minCoordinate, maxCoordinate);
    final minY = topLeft.y.clamp(minCoordinate, maxCoordinate);
    final maxY = bottomRight.y.clamp(minCoordinate, maxCoordinate);
    
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        positions.add(Position(x, y));
      }
    }
    
    return positions;
  }

  /// Get all positions within a circular area
  List<Position> getPositionsInRadius(Position center, int radius) {
    final positions = <Position>[];
    
    final minX = (center.x - radius).clamp(minCoordinate, maxCoordinate);
    final maxX = (center.x + radius).clamp(minCoordinate, maxCoordinate);
    final minY = (center.y - radius).clamp(minCoordinate, maxCoordinate);
    final maxY = (center.y + radius).clamp(minCoordinate, maxCoordinate);
    
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final position = Position(x, y);
        if (center.distanceTo(position) <= radius) {
          positions.add(position);
        }
      }
    }
    
    return positions;
  }

  /// Fill a rectangular area with the specified tile
  void fillArea(Position topLeft, Position bottomRight, Tile tile) {
    final positions = getPositionsInArea(topLeft, bottomRight);
    for (final position in positions) {
      setTile(position, tile);
    }
  }

  /// Create a room by filling an area with indoor tiles
  void createRoom(Position topLeft, Position bottomRight, {
    required int roomId,
    FloorType floorType = FloorType.wood,
    WallType wallType = WallType.interior,
  }) {
    final positions = getPositionsInArea(topLeft, bottomRight);
    
    for (final position in positions) {
      // Determine if this position should be a wall or floor
      final isEdge = position.x == topLeft.x || 
                     position.x == bottomRight.x ||
                     position.y == topLeft.y || 
                     position.y == bottomRight.y;
      
      if (isEdge) {
        // Create wall tile
        setTile(position, Tile.wall(
          wallType: wallType,
          floor: floorType,
          roomId: roomId,
        ));
      } else {
        // Create floor tile
        setTile(position, Tile.indoor(
          floor: floorType,
          roomId: roomId,
        ));
      }
    }
  }

  /// Get all tiles in the grid as a flat list with their positions
  List<(Position, Tile)> getAllTiles() {
    final tiles = <(Position, Tile)>[];
    
    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        tiles.add((Position(x, y), _tiles[x][y]));
      }
    }
    
    return tiles;
  }

  /// Get all tiles of a specific floor type
  List<(Position, Tile)> getTilesByFloorType(FloorType floorType) {
    return getAllTiles()
        .where((entry) => entry.$2.floor == floorType)
        .toList();
  }

  /// Get all tiles in a specific room
  List<(Position, Tile)> getTilesByRoom(int roomId) {
    return getAllTiles()
        .where((entry) => entry.$2.roomId == roomId)
        .toList();
  }

  /// Get the bounds of the grid as a rectangle
  (Position topLeft, Position bottomRight) get bounds => (
    const Position(minCoordinate, minCoordinate),
    const Position(maxCoordinate, maxCoordinate),
  );

  /// Get the center position of the grid
  Position get center => const Position(size ~/ 2, size ~/ 2);

  /// Convert the grid to a JSON-serializable format
  Map<String, dynamic> toJson() {
    final tilesJson = <List<Map<String, dynamic>>>[];
    
    for (int x = 0; x < size; x++) {
      final row = <Map<String, dynamic>>[];
      for (int y = 0; y < size; y++) {
        row.add(_tiles[x][y].toJson());
      }
      tilesJson.add(row);
    }
    
    return {
      'size': size,
      'tiles': tilesJson,
    };
  }

  /// Create a grid from JSON data
  factory Grid.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int;
    if (size != Grid.size) {
      throw ArgumentError('Invalid grid size: $size, expected ${Grid.size}');
    }
    
    final tilesJson = json['tiles'] as List<dynamic>;
    final tiles = <List<Tile>>[];
    
    for (final rowJson in tilesJson) {
      final row = <Tile>[];
      for (final tileJson in rowJson as List<dynamic>) {
        row.add(Tile.fromJson(tileJson as Map<String, dynamic>));
      }
      tiles.add(row);
    }
    
    return Grid.fromTiles(tiles);
  }

  @override
  String toString() => 'Grid(${size}x$size)';
}