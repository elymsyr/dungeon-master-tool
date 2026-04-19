/// Proficiency level applied to a roll. Tier 0.
enum Proficiency {
  none,
  half,
  full,
  expertise;

  /// Multiplier applied to proficiency bonus per SRD 5.2.1:
  /// none → 0, half → 0.5 (rounded down by caller), full → 1, expertise → 2.
  double get multiplier => switch (this) {
        none => 0,
        half => 0.5,
        full => 1,
        expertise => 2,
      };

  int applyTo(int proficiencyBonus) => switch (this) {
        none => 0,
        half => (proficiencyBonus / 2).floor(),
        full => proficiencyBonus,
        expertise => proficiencyBonus * 2,
      };
}
