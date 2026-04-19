/// Current HP, max HP, temp HP. Tier 0 stateful machine.
///
/// Invariants:
/// - [max] ≥ 1
/// - [current] ∈ [0, max]
/// - [temp] ≥ 0
///
/// SRD damage/healing ordering:
/// - Damage consumes temp HP first (no typed-resistance applied to temp
///   unless a specific feature says so — caller's problem).
/// - Healing never increases temp HP and never exceeds [max].
class HitPoints {
  final int current;
  final int max;
  final int temp;

  const HitPoints._(this.current, this.max, this.temp);

  factory HitPoints({required int current, required int max, int temp = 0}) {
    if (max < 1) throw ArgumentError('HitPoints.max $max < 1');
    if (current < 0 || current > max) {
      throw ArgumentError('HitPoints.current $current outside [0, $max]');
    }
    if (temp < 0) throw ArgumentError('HitPoints.temp $temp < 0');
    return HitPoints._(current, max, temp);
  }

  /// Full HP with no temp.
  factory HitPoints.full(int max) => HitPoints(current: max, max: max);

  bool get isDying => current == 0;
  bool get isAtFull => current == max && temp == 0;

  /// Applies [damage] ≥ 0 to temp HP first, then current. Returns new state
  /// plus the overflow that went past 0 (not used for PCs — the death save
  /// flow triggers — but useful for monsters/massive-damage checks).
  ({HitPoints hp, int overflow}) takeDamage(int damage) {
    if (damage < 0) throw ArgumentError('damage $damage < 0');
    var remaining = damage;
    var newTemp = temp;
    if (newTemp > 0) {
      final absorbed = remaining < newTemp ? remaining : newTemp;
      newTemp -= absorbed;
      remaining -= absorbed;
    }
    final newCurrent = (current - remaining).clamp(0, max);
    final overflow = (current - remaining < 0) ? -(current - remaining) : 0;
    return (
      hp: HitPoints._(newCurrent, max, newTemp),
      overflow: overflow,
    );
  }

  /// Healing clamped to [max]. Temp HP unaffected.
  HitPoints heal(int amount) {
    if (amount < 0) throw ArgumentError('heal $amount < 0');
    return HitPoints._((current + amount).clamp(0, max), max, temp);
  }

  /// Temp HP does not stack — new value replaces existing when greater
  /// (SRD rule). Lower-or-equal new grants are ignored.
  HitPoints grantTemp(int amount) {
    if (amount < 0) throw ArgumentError('temp $amount < 0');
    return HitPoints._(current, max, amount > temp ? amount : temp);
  }

  HitPoints withMax(int newMax) {
    if (newMax < 1) throw ArgumentError('max $newMax < 1');
    return HitPoints._(current.clamp(0, newMax), newMax, temp);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HitPoints &&
          other.current == current &&
          other.max == max &&
          other.temp == temp;

  @override
  int get hashCode => Object.hash(current, max, temp);

  @override
  String toString() => 'HP($current/$max${temp > 0 ? ' +$temp' : ''})';
}
