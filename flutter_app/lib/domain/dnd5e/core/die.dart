/// Canonical D&D dice. Tier 0.
enum Die {
  d4(4),
  d6(6),
  d8(8),
  d10(10),
  d12(12),
  d20(20),
  d100(100);

  final int sides;
  const Die(this.sides);

  /// Textual SRD notation ("d4", "d20", ...).
  String get notation => 'd$sides';

  /// Average rounded down — matches SRD "Monsters with Damage" fixed-damage
  /// convention (floor of ((sides+1)/2)).
  int get averageFloor => (sides + 1) ~/ 2;

  static Die fromSides(int sides) {
    for (final d in Die.values) {
      if (d.sides == sides) return d;
    }
    throw ArgumentError('No canonical Die with $sides sides');
  }
}
