/// Core need system for character simulation.
///
/// This module implements the need-based AI system where characters have
/// various needs (hunger, hygiene, social, etc.) that decay over time and
/// drive autonomous behavior decisions.
library;

/// Represents a single character need with decay mechanics and critical thresholds.
///
/// Each need has a value from 0.0 to 100.0, where 100.0 is fully satisfied
/// and 0.0 is completely depleted. Needs decay over time at a specified rate
/// and become critical when they drop below 20.0.
class Need {
  /// The type/category of this need (e.g., 'hunger', 'hygiene', 'social')
  final String type;

  /// Current satisfaction level (0.0 to 100.0)
  double value;

  /// Rate at which this need decays per second
  final double decayRate;

  /// Threshold below which this need is considered critical
  static const double criticalThreshold = 20.0;

  /// Maximum possible need value
  static const double maxValue = 100.0;

  /// Minimum possible need value
  static const double minValue = 0.0;

  /// Creates a new need with the specified type, initial value, and decay rate.
  ///
  /// [type] - The category of need (e.g., 'hunger', 'hygiene')
  /// [value] - Initial satisfaction level (0.0 to 100.0)
  /// [decayRate] - How much the need decreases per second
  Need({required this.type, required this.value, required this.decayRate})
    : assert(
        value >= minValue && value <= maxValue,
        'Need value must be between $minValue and $maxValue',
      ),
      assert(decayRate >= 0, 'Decay rate must be non-negative');

  /// Applies decay to this need based on elapsed time.
  ///
  /// [deltaTime] - Time elapsed in seconds since last decay
  void decay(double deltaTime) {
    assert(deltaTime >= 0, 'Delta time must be non-negative');

    value -= decayRate * deltaTime;
    value = value.clamp(minValue, maxValue);
  }

  /// Whether this need is in a critical state requiring immediate attention.
  bool get isCritical => value < criticalThreshold;

  /// How much this need is lacking from being fully satisfied.
  /// Returns a value from 0.0 (fully satisfied) to 100.0 (completely depleted).
  double get deficit => maxValue - value;

  /// Percentage of satisfaction (0.0 to 1.0).
  double get satisfactionPercentage => value / maxValue;

  /// Increases the need value by the specified amount.
  ///
  /// [amount] - How much to increase the need (positive value)
  void satisfy(double amount) {
    assert(amount >= 0, 'Satisfaction amount must be non-negative');

    value += amount;
    value = value.clamp(minValue, maxValue);
  }

  /// Sets the need to a specific value.
  ///
  /// [newValue] - The new value to set (0.0 to 100.0)
  void setValue(double newValue) {
    assert(
      newValue >= minValue && newValue <= maxValue,
      'Need value must be between $minValue and $maxValue',
    );

    value = newValue;
  }

  @override
  String toString() {
    return 'Need($type: ${value.toStringAsFixed(1)}/${maxValue.toInt()}, '
        'decay: ${decayRate.toStringAsFixed(2)}/s, '
        'critical: $isCritical)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Need &&
        other.type == type &&
        other.value == value &&
        other.decayRate == decayRate;
  }

  @override
  int get hashCode => Object.hash(type, value, decayRate);
}
