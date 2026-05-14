/// Ability-score generation method picked in the character creation wizard.
///
/// Each method maps to a different validator + UI affordance:
///   - standardArray — pre-set 15/14/13/12/10/8 distributed across abilities.
///   - pointBuy      — 27 points, scores 8-15, costs per SRD table.
///   - random        — 4d6 drop-lowest, six rolls.
///   - manual        — free entry, clamped 3-20 by validator.
enum AbilityScoreMethod {
  standardArray,
  pointBuy,
  random,
  manual,
}

extension AbilityScoreMethodX on AbilityScoreMethod {
  String get label => switch (this) {
        AbilityScoreMethod.standardArray => 'Standard Array',
        AbilityScoreMethod.pointBuy => 'Point Buy',
        AbilityScoreMethod.random => 'Random (4d6 drop low)',
        AbilityScoreMethod.manual => 'Manual',
      };
}

/// Six SRD ability score keys in canonical order.
const kAbilityKeys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

/// Standard Array values, in descending order. SRD §1.
const kStandardArray = [15, 14, 13, 12, 10, 8];

/// Point Buy budget per SRD.
const kPointBuyBudget = 27;

/// Point Buy cost table: score → points spent. Scores outside 8-15 unbuyable.
const kPointBuyCosts = {
  8: 0,
  9: 1,
  10: 2,
  11: 3,
  12: 4,
  13: 5,
  14: 7,
  15: 9,
};
