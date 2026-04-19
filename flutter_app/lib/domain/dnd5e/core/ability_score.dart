/// Single ability score in the legal D&D 5e range [1, 30]. Tier 0.
class AbilityScore {
  final int value;

  const AbilityScore._(this.value);

  factory AbilityScore(int v) {
    if (v < 1 || v > 30) {
      throw ArgumentError('AbilityScore $v out of [1, 30]');
    }
    return AbilityScore._(v);
  }

  /// D&D modifier = floor((value - 10) / 2). Uses mathematical floor so
  /// odd scores below 10 round the correct way (e.g. 9 → -1, not 0).
  int get modifier => ((value - 10) / 2).floor();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AbilityScore && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AbilityScore($value)';
}
