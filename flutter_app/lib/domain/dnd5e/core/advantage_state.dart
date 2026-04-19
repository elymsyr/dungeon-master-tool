/// Effective roll adjustment per SRD 5.2.1. Tier 0.
///
/// Combination rule: any number of advantage sources + zero disadvantage
/// sources → advantage; vice versa. At least one of each → normal
/// (cancellation, regardless of how many of each).
enum AdvantageState {
  normal,
  advantage,
  disadvantage;

  /// Combines two sources. Implements SRD cancellation rule.
  AdvantageState combine(AdvantageState other) {
    if (this == other) return this;
    if (this == normal) return other;
    if (other == normal) return this;
    return normal;
  }

  static AdvantageState fromFlags({
    required bool anyAdvantage,
    required bool anyDisadvantage,
  }) {
    if (anyAdvantage && anyDisadvantage) return normal;
    if (anyAdvantage) return advantage;
    if (anyDisadvantage) return disadvantage;
    return normal;
  }
}
