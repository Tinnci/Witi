/// Represents different types of floor tiles
enum FloorType {
  /// Grass or outdoor ground
  grass,
  
  /// Indoor wooden flooring
  wood,
  
  /// Stone or concrete flooring
  stone,
  
  /// Carpet flooring
  carpet,
  
  /// Tile flooring (kitchen/bathroom)
  ceramic,
  
  /// Water tile (pools, ponds)
  water,
  
  /// Sand or beach
  sand;

  /// Whether this floor type can be walked on
  bool get isWalkable => switch (this) {
    FloorType.water => false,
    _ => true,
  };

  /// Movement speed modifier for this floor type
  double get speedModifier => switch (this) {
    FloorType.water => 0.0, // Cannot walk on water
    FloorType.sand => 0.8,  // Slower movement on sand
    FloorType.grass => 0.9, // Slightly slower on grass
    _ => 1.0, // Normal speed on other surfaces
  };
}

/// Represents different types of wall tiles
enum WallType {
  /// No wall (empty space)
  none,
  
  /// Standard interior wall
  interior,
  
  /// Exterior wall
  exterior,
  
  /// Window in wall
  window,
  
  /// Door in wall
  door,
  
  /// Fence (low wall)
  fence;

  /// Whether this wall blocks movement
  bool get blocksMovement => switch (this) {
    WallType.none || WallType.door => false,
    _ => true,
  };

  /// Whether this wall blocks line of sight
  bool get blocksLineOfSight => switch (this) {
    WallType.none || WallType.window => false,
    _ => true,
  };

  /// Height of the wall for rendering purposes
  double get height => switch (this) {
    WallType.none => 0.0,
    WallType.fence => 0.5,
    WallType.window => 0.7,
    _ => 1.0,
  };
}

/// Represents a single tile in the world grid
class Tile {
  /// The floor type of this tile
  final FloorType floor;
  
  /// The wall type of this tile (if any)
  final WallType wall;
  
  /// Whether this tile has been explored/revealed
  final bool isExplored;
  
  /// Room ID this tile belongs to (null if outdoors)
  final int? roomId;

  const Tile({
    required this.floor,
    this.wall = WallType.none,
    this.isExplored = true,
    this.roomId,
  });

  /// Create a basic grass tile (default outdoor tile)
  const Tile.grass() : this(floor: FloorType.grass);

  /// Create a basic indoor floor tile
  const Tile.indoor({FloorType floor = FloorType.wood, int? roomId}) 
      : this(floor: floor, roomId: roomId);

  /// Create a wall tile
  const Tile.wall({
    required WallType wallType,
    FloorType floor = FloorType.wood,
    int? roomId,
  }) : this(floor: floor, wall: wallType, roomId: roomId);

  /// Whether this tile can be walked on
  bool get isWalkable => floor.isWalkable && !wall.blocksMovement;

  /// Whether this tile blocks line of sight
  bool get blocksLineOfSight => wall.blocksLineOfSight;

  /// Movement speed modifier for this tile
  double get speedModifier => isWalkable ? floor.speedModifier : 0.0;

  /// Whether this tile is indoors (has a room ID)
  bool get isIndoors => roomId != null;

  /// Whether this tile is outdoors
  bool get isOutdoors => roomId == null;

  /// Create a copy of this tile with modified properties
  Tile copyWith({
    FloorType? floor,
    WallType? wall,
    bool? isExplored,
    int? roomId,
  }) {
    return Tile(
      floor: floor ?? this.floor,
      wall: wall ?? this.wall,
      isExplored: isExplored ?? this.isExplored,
      roomId: roomId ?? this.roomId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile &&
          runtimeType == other.runtimeType &&
          floor == other.floor &&
          wall == other.wall &&
          isExplored == other.isExplored &&
          roomId == other.roomId;

  @override
  int get hashCode =>
      floor.hashCode ^ wall.hashCode ^ isExplored.hashCode ^ roomId.hashCode;

  @override
  String toString() => 'Tile(floor: $floor, wall: $wall, room: $roomId)';

  /// Convert to a JSON-serializable map
  Map<String, dynamic> toJson() => {
    'floor': floor.name,
    'wall': wall.name,
    'isExplored': isExplored,
    if (roomId != null) 'roomId': roomId,
  };

  /// Create from a JSON map
  factory Tile.fromJson(Map<String, dynamic> json) {
    return Tile(
      floor: FloorType.values.byName(json['floor'] as String),
      wall: WallType.values.byName(json['wall'] as String),
      isExplored: json['isExplored'] as bool? ?? true,
      roomId: json['roomId'] as int?,
    );
  }
}