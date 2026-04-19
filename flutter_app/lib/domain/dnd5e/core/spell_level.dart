/// Spell level 0..9. Level 0 = cantrip. Tier 0.
class SpellLevel {
  final int value;

  const SpellLevel._(this.value);

  factory SpellLevel(int v) {
    if (v < 0 || v > 9) {
      throw ArgumentError('SpellLevel $v out of [0, 9]');
    }
    return SpellLevel._(v);
  }

  static const cantrip = SpellLevel._(0);

  bool get isCantrip => value == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpellLevel && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value == 0 ? 'Cantrip' : 'Level $value';
}
