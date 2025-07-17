import 'package:freezed_annotation/freezed_annotation.dart';
import 'grid.dart';
import 'world.dart';

part 'save_data.freezed.dart';
part 'save_data.g.dart';

/// Save data model for world persistence with versioning and validation
@freezed
class SaveData with _$SaveData {
  const factory SaveData({
    /// Save data format version for migration support
    @Default(1) int version,
    
    /// Unique identifier for this save file
    required String saveId,
    
    /// Human-readable save name
    required String saveName,
    
    /// When this save was created
    required DateTime createdAt,
    
    /// When this save was last modified
    required DateTime lastModified,
    
    /// Current simulation tick
    @Default(0) int currentTick,
    
    /// World creation timestamp
    required DateTime worldCreatedAt,
    
    /// Grid data
    required Map<String, dynamic> gridData,
    
    /// Sims data (empty list for now, will be populated when Sim class exists)
    @Default([]) List<Map<String, dynamic>> simsData,
    
    /// Interactive objects data (empty list for now)
    @Default([]) List<Map<String, dynamic>> objectsData,
    
    /// Global world state
    @Default({}) Map<String, dynamic> globalState,
    
    /// Additional metadata for save file management
    @Default({}) Map<String, dynamic> metadata,
  }) = _SaveData;

  factory SaveData.fromJson(Map<String, dynamic> json) => _$SaveDataFromJson(json);
}

/// Save data validation result
@freezed
class SaveDataValidationResult with _$SaveDataValidationResult {
  const factory SaveDataValidationResult({
    /// Whether the save data is valid
    required bool isValid,
    
    /// List of validation errors (empty if valid)
    @Default([]) List<String> errors,
    
    /// List of validation warnings (non-critical issues)
    @Default([]) List<String> warnings,
    
    /// Whether the save data needs migration
    @Default(false) bool needsMigration,
    
    /// Target version for migration
    int? targetVersion,
  }) = _SaveDataValidationResult;

  factory SaveDataValidationResult.fromJson(Map<String, dynamic> json) => 
      _$SaveDataValidationResultFromJson(json);
}

/// Save data validator for integrity checking
class SaveDataValidator {
  /// Current save data format version
  static const int currentVersion = 1;
  
  /// Minimum supported version for backward compatibility
  static const int minimumSupportedVersion = 1;
  
  /// Validate save data integrity and compatibility
  static SaveDataValidationResult validate(SaveData saveData) {
    final errors = <String>[];
    final warnings = <String>[];
    bool needsMigration = false;
    int? targetVersion;
    
    // Version validation
    if (saveData.version < minimumSupportedVersion) {
      errors.add('Save data version ${saveData.version} is too old and not supported');
    } else if (saveData.version > currentVersion) {
      errors.add('Save data version ${saveData.version} is newer than supported version $currentVersion');
    } else if (saveData.version < currentVersion) {
      needsMigration = true;
      targetVersion = currentVersion;
      warnings.add('Save data version ${saveData.version} needs migration to version $currentVersion');
    }
    
    // Basic field validation
    if (saveData.saveId.isEmpty) {
      errors.add('Save ID cannot be empty');
    }
    
    if (saveData.saveName.isEmpty) {
      errors.add('Save name cannot be empty');
    }
    
    if (saveData.currentTick < 0) {
      errors.add('Current tick cannot be negative');
    }
    
    if (saveData.createdAt.isAfter(DateTime.now())) {
      warnings.add('Save creation date is in the future');
    }
    
    if (saveData.lastModified.isBefore(saveData.createdAt)) {
      errors.add('Last modified date cannot be before creation date');
    }
    
    if (saveData.worldCreatedAt.isAfter(saveData.createdAt)) {
      errors.add('World creation date cannot be after save creation date');
    }
    
    // Grid data validation
    try {
      _validateGridData(saveData.gridData, errors, warnings);
    } catch (e) {
      errors.add('Grid data validation failed: $e');
    }
    
    // Global state validation
    _validateGlobalState(saveData.globalState, errors, warnings);
    
    return SaveDataValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      needsMigration: needsMigration,
      targetVersion: targetVersion,
    );
  }
  
  /// Validate grid data structure
  static void _validateGridData(
    Map<String, dynamic> gridData, 
    List<String> errors, 
    List<String> warnings,
  ) {
    if (!gridData.containsKey('size')) {
      errors.add('Grid data missing size field');
      return;
    }
    
    final size = gridData['size'];
    if (size is! int || size != Grid.size) {
      errors.add('Invalid grid size: expected ${Grid.size}, got $size');
      return;
    }
    
    if (!gridData.containsKey('tiles')) {
      errors.add('Grid data missing tiles field');
      return;
    }
    
    final tiles = gridData['tiles'];
    if (tiles is! List) {
      errors.add('Grid tiles must be a list');
      return;
    }
    
    if (tiles.length != Grid.size) {
      errors.add('Grid tiles array has wrong length: expected ${Grid.size}, got ${tiles.length}');
      return;
    }
    
    // Validate each row
    for (int x = 0; x < tiles.length; x++) {
      final row = tiles[x];
      if (row is! List) {
        errors.add('Grid row $x is not a list');
        continue;
      }
      
      if (row.length != Grid.size) {
        errors.add('Grid row $x has wrong length: expected ${Grid.size}, got ${row.length}');
        continue;
      }
      
      // Validate each tile in the row
      for (int y = 0; y < row.length; y++) {
        final tile = row[y];
        if (tile is! Map<String, dynamic>) {
          errors.add('Grid tile at ($x, $y) is not a valid tile object');
          continue;
        }
        
        _validateTileData(tile, x, y, errors, warnings);
      }
    }
  }
  
  /// Validate individual tile data
  static void _validateTileData(
    Map<String, dynamic> tileData,
    int x,
    int y,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!tileData.containsKey('floor')) {
      errors.add('Tile at ($x, $y) missing floor field');
      return;
    }
    
    if (!tileData.containsKey('wall')) {
      errors.add('Tile at ($x, $y) missing wall field');
      return;
    }
    
    final floor = tileData['floor'];
    final wall = tileData['wall'];
    
    if (floor is! String) {
      errors.add('Tile at ($x, $y) floor field must be a string');
    }
    
    if (wall is! String) {
      errors.add('Tile at ($x, $y) wall field must be a string');
    }
    
    // Validate isExplored field if present
    if (tileData.containsKey('isExplored')) {
      final isExplored = tileData['isExplored'];
      if (isExplored is! bool) {
        warnings.add('Tile at ($x, $y) isExplored field should be a boolean');
      }
    }
    
    // Validate roomId field if present
    if (tileData.containsKey('roomId')) {
      final roomId = tileData['roomId'];
      if (roomId is! int) {
        warnings.add('Tile at ($x, $y) roomId field should be an integer');
      }
    }
  }
  
  /// Validate global state data
  static void _validateGlobalState(
    Map<String, dynamic> globalState,
    List<String> errors,
    List<String> warnings,
  ) {
    // Check for expected global state fields
    if (globalState.containsKey('currentTick')) {
      final currentTick = globalState['currentTick'];
      if (currentTick is! int || currentTick < 0) {
        warnings.add('Global state currentTick should be a non-negative integer');
      }
    }
    
    if (globalState.containsKey('simulationTime')) {
      final simulationTime = globalState['simulationTime'];
      if (simulationTime is! num || simulationTime < 0) {
        warnings.add('Global state simulationTime should be a non-negative number');
      }
    }
    
    // Validate that all values are JSON-serializable
    for (final entry in globalState.entries) {
      if (!_isJsonSerializable(entry.value)) {
        errors.add('Global state key "${entry.key}" contains non-serializable value');
      }
    }
  }
  
  /// Check if a value is JSON-serializable
  static bool _isJsonSerializable(dynamic value) {
    if (value == null) return true;
    if (value is bool || value is int || value is double || value is String) return true;
    
    if (value is List) {
      return value.every(_isJsonSerializable);
    }
    
    if (value is Map) {
      return value.keys.every((k) => k is String) && 
             value.values.every(_isJsonSerializable);
    }
    
    return false;
  }
}

/// Save data migration utilities
class SaveDataMigrator {
  /// Migrate save data to the current version
  static SaveData migrate(SaveData saveData) {
    if (saveData.version == SaveDataValidator.currentVersion) {
      return saveData;
    }
    
    var migrated = saveData;
    
    // Add migration logic here as versions evolve
    // For now, we only have version 1, so no migrations needed
    
    return migrated.copyWith(
      version: SaveDataValidator.currentVersion,
      lastModified: DateTime.now(),
    );
  }
}