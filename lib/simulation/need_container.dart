import 'need.dart';

/// Container that manages multiple needs for a character.
/// 
/// This class handles the collection of all needs for a character, processes
/// their decay over time, and provides methods for AI decision making such as
/// finding the most urgent need and calculating deficits.
class NeedContainer {
  /// Map of need type to Need instance
  final Map<String, Need> _needs = <String, Need>{};
  
  /// Creates an empty need container.
  NeedContainer();
  
  /// Creates a need container with the specified needs.
  /// 
  /// [needs] - List of needs to initialize the container with
  NeedContainer.withNeeds(List<Need> needs) {
    for (Need need in needs) {
      addNeed(need);
    }
  }
  
  /// Adds a need to this container.
  /// 
  /// [need] - The need to add
  /// Throws [ArgumentError] if a need with the same type already exists
  void addNeed(Need need) {
    if (_needs.containsKey(need.type)) {
      throw ArgumentError('Need of type "${need.type}" already exists');
    }
    _needs[need.type] = need;
  }
  
  /// Removes a need from this container.
  /// 
  /// [needType] - The type of need to remove
  /// Returns true if the need was removed, false if it didn't exist
  bool removeNeed(String needType) {
    return _needs.remove(needType) != null;
  }
  
  /// Gets a need by its type.
  /// 
  /// [needType] - The type of need to retrieve
  /// Returns the need or null if it doesn't exist
  Need? getNeed(String needType) {
    return _needs[needType];
  }
  
  /// Gets all needs in this container.
  /// 
  /// Returns an unmodifiable view of all needs
  Iterable<Need> get allNeeds => _needs.values;
  
  /// Gets all need types in this container.
  /// 
  /// Returns an unmodifiable view of all need types
  Iterable<String> get needTypes => _needs.keys;
  
  /// Whether this container has any needs.
  bool get isEmpty => _needs.isEmpty;
  
  /// Number of needs in this container.
  int get length => _needs.length;
  
  /// Processes decay for all needs based on elapsed time.
  /// 
  /// This should be called every simulation tick to update need values.
  /// [deltaTime] - Time elapsed in seconds since last tick
  void tick(double deltaTime) {
    assert(deltaTime >= 0, 'Delta time must be non-negative');
    
    for (Need need in _needs.values) {
      need.decay(deltaTime);
    }
  }
  
  /// Finds the need with the highest deficit (most urgent).
  /// 
  /// Returns the need that is most lacking in satisfaction, or null if
  /// no needs exist. This is used by the AI system to prioritize actions.
  Need? getMostUrgent() {
    if (_needs.isEmpty) return null;
    
    Need? mostUrgent;
    double highestDeficit = 0.0;
    
    for (Need need in _needs.values) {
      if (need.deficit > highestDeficit) {
        highestDeficit = need.deficit;
        mostUrgent = need;
      }
    }
    
    return mostUrgent;
  }
  
  /// Calculates how much a specific need type is lacking.
  /// 
  /// [needType] - The type of need to check
  /// Returns the deficit (0.0 to 100.0) or 0.0 if the need doesn't exist
  double getDeficit(String needType) {
    Need? need = _needs[needType];
    return need?.deficit ?? 0.0;
  }
  
  /// Gets all needs that are in a critical state.
  /// 
  /// Returns a list of needs that require immediate attention
  List<Need> getCriticalNeeds() {
    return _needs.values.where((need) => need.isCritical).toList();
  }
  
  /// Whether any needs are in a critical state.
  bool get hasCriticalNeeds => _needs.values.any((need) => need.isCritical);
  
  /// Gets the average satisfaction level across all needs.
  /// 
  /// Returns a value from 0.0 to 1.0, or 1.0 if no needs exist
  double get averageSatisfaction {
    if (_needs.isEmpty) return 1.0;
    
    double total = 0.0;
    for (Need need in _needs.values) {
      total += need.satisfactionPercentage;
    }
    
    return total / _needs.length;
  }
  
  /// Gets the lowest satisfaction percentage among all needs.
  /// 
  /// Returns a value from 0.0 to 1.0, or 1.0 if no needs exist
  double get lowestSatisfaction {
    if (_needs.isEmpty) return 1.0;
    
    double lowest = 1.0;
    for (Need need in _needs.values) {
      if (need.satisfactionPercentage < lowest) {
        lowest = need.satisfactionPercentage;
      }
    }
    
    return lowest;
  }
  
  /// Satisfies a specific need by the given amount.
  /// 
  /// [needType] - The type of need to satisfy
  /// [amount] - How much to satisfy the need
  /// Returns true if the need was found and satisfied, false otherwise
  bool satisfyNeed(String needType, double amount) {
    Need? need = _needs[needType];
    if (need == null) return false;
    
    need.satisfy(amount);
    return true;
  }
  
  /// Sets a specific need to a new value.
  /// 
  /// [needType] - The type of need to set
  /// [value] - The new value (0.0 to 100.0)
  /// Returns true if the need was found and set, false otherwise
  bool setNeedValue(String needType, double value) {
    Need? need = _needs[needType];
    if (need == null) return false;
    
    need.setValue(value);
    return true;
  }
  
  @override
  String toString() {
    if (_needs.isEmpty) {
      return 'NeedContainer(empty)';
    }
    
    List<String> needStrings = _needs.values
        .map((need) => '${need.type}: ${need.value.toStringAsFixed(1)}')
        .toList();
    
    return 'NeedContainer(${needStrings.join(', ')})';
  }
}