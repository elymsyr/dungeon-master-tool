import 'dart:math' as math;

/// Concentration save DC after taking damage: `max(10, floor(damage / 2))`,
/// capped at 30. Separate from [DamageResolver] so spell-side code and the
/// damage pipeline cannot drift on the formula.
class ConcentrationDc {
  static int forDamage(int damage) {
    if (damage < 0) {
      throw ArgumentError('ConcentrationDc.forDamage requires damage >= 0');
    }
    return math.min(30, math.max(10, damage ~/ 2));
  }
}
