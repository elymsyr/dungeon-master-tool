/// Exhaustion track 0..6. Tier 0.
///
/// Per SRD 5.2.1 (2024 edition):
/// - Each level applies a -2 penalty to D20 Tests (attacks, saves, ability
///   checks). Penalty scales by level × 2.
/// - Level 6 = death.
class Exhaustion {
  final int level;

  const Exhaustion._(this.level);

  factory Exhaustion(int level) {
    if (level < 0 || level > 6) {
      throw ArgumentError('Exhaustion level $level outside [0, 6]');
    }
    return Exhaustion._(level);
  }

  static const none = Exhaustion._(0);
  static const dead = Exhaustion._(6);

  bool get isDead => level >= 6;

  /// D20 Test penalty per SRD 5.2.1: -2 × level.
  int get d20Penalty => level * 2;

  Exhaustion gain([int delta = 1]) =>
      Exhaustion._((level + delta).clamp(0, 6));

  Exhaustion reduce([int delta = 1]) =>
      Exhaustion._((level - delta).clamp(0, 6));

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exhaustion && other.level == level;

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() => 'Exhaustion($level)';
}
