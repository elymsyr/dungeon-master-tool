/// Namespaced helpers for D&D 5e proficiency bonus lookup. Tier 0.
///
/// PB grows with total character level per SRD 5.2.1:
/// - Level 1-4:   +2
/// - Level 5-8:   +3
/// - Level 9-12:  +4
/// - Level 13-16: +5
/// - Level 17-20: +6
abstract final class ProficiencyBonus {
  static int forLevel(int totalLevel) {
    if (totalLevel < 1) {
      throw ArgumentError('Total level $totalLevel < 1');
    }
    if (totalLevel > 20) {
      throw ArgumentError('Total level $totalLevel > 20 (beyond SRD scope)');
    }
    return 2 + ((totalLevel - 1) ~/ 4);
  }

  /// CR-derived proficiency bonus for monsters per SRD 5.2.1 (Monsters by CR).
  /// CR 0-4 → +2, 5-8 → +3, 9-12 → +4, 13-16 → +5, 17-20 → +6,
  /// 21-24 → +7, 25-28 → +8, 29-30 → +9.
  static int forChallengeRating(double cr) {
    if (cr < 0) throw ArgumentError('CR $cr < 0');
    if (cr <= 4) return 2;
    if (cr <= 8) return 3;
    if (cr <= 12) return 4;
    if (cr <= 16) return 5;
    if (cr <= 20) return 6;
    if (cr <= 24) return 7;
    if (cr <= 28) return 8;
    if (cr <= 30) return 9;
    throw ArgumentError('CR $cr > 30 (beyond SRD scope)');
  }
}
