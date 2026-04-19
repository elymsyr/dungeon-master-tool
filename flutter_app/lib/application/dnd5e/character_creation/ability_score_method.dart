import '../../../domain/dnd5e/core/ability.dart';

/// How the player generates their 6 base ability scores before background
/// bonuses are applied. Mirrors SRD §16.6.
enum AbilityScoreGenerationMethod {
  standardArray,
  random,
  pointBuy,
}

/// Canonical Standard Array multiset (SRD §16.6). Each value used exactly once.
const List<int> kStandardArray = <int>[15, 14, 13, 12, 10, 8];

/// Point-buy inclusive bounds on a single base score (pre-background-bonus).
const int kPointBuyMinScore = 8;
const int kPointBuyMaxScore = 15;

/// Point-buy cost table from SRD §16.6. Score → point cost.
const Map<int, int> kPointBuyCosts = <int, int>{
  8: 0,
  9: 1,
  10: 2,
  11: 3,
  12: 4,
  13: 5,
  14: 7,
  15: 9,
};

/// Total points available in Point Buy (SRD §16.6).
const int kPointBuyBudget = 27;

/// Pure validators for Step 3. Each returns `null` when valid or an
/// end-user-facing message on the first failure it encounters.
class AbilityScoreValidator {
  const AbilityScoreValidator();

  String? validateStandardArray(Map<Ability, int> baseScores) {
    final completeness = _requireSixScores(baseScores);
    if (completeness != null) return completeness;
    final remaining = List<int>.from(kStandardArray);
    for (final a in Ability.values) {
      final v = baseScores[a]!;
      if (!remaining.remove(v)) {
        return 'Standard Array must use [15, 14, 13, 12, 10, 8] each exactly once.';
      }
    }
    return null;
  }

  /// Loose check for the "roll 4d6-drop-low six times" path: all six slots
  /// filled, every score in [3, 18] (the physical range of 4d6-drop-low).
  String? validateRandom(Map<Ability, int> baseScores) {
    final completeness = _requireSixScores(baseScores);
    if (completeness != null) return completeness;
    for (final entry in baseScores.entries) {
      if (entry.value < 3 || entry.value > 18) {
        return '${entry.key.short} = ${entry.value} is outside 4d6-drop-low range [3, 18].';
      }
    }
    return null;
  }

  String? validatePointBuy(Map<Ability, int> baseScores) {
    final completeness = _requireSixScores(baseScores);
    if (completeness != null) return completeness;
    var total = 0;
    for (final entry in baseScores.entries) {
      final v = entry.value;
      if (v < kPointBuyMinScore || v > kPointBuyMaxScore) {
        return '${entry.key.short} = $v is outside Point Buy range '
            '[$kPointBuyMinScore, $kPointBuyMaxScore].';
      }
      total += kPointBuyCosts[v]!;
    }
    if (total > kPointBuyBudget) {
      return 'Point Buy spent $total / $kPointBuyBudget.';
    }
    return null;
  }

  /// Background bonuses must total +3 distributed as EITHER (+2/+1 on 2 of 3
  /// listed abilities) OR (+1/+1/+1 on all 3 listed) — 2024 SRD Origin Feat.
  /// Bonuses are only valid against [listedAbilities]. No single score > 20
  /// after applying the bonus.
  String? validateBackgroundBonuses({
    required Map<Ability, int> baseScores,
    required Map<Ability, int> bonuses,
    required Set<Ability> listedAbilities,
  }) {
    if (listedAbilities.length != 3) {
      return 'Background must list exactly 3 eligible abilities (got ${listedAbilities.length}).';
    }
    var total = 0;
    for (final entry in bonuses.entries) {
      if (!listedAbilities.contains(entry.key)) {
        return '${entry.key.short} is not one of the background\'s listed abilities.';
      }
      if (entry.value < 0) return 'Bonus for ${entry.key.short} cannot be negative.';
      total += entry.value;
    }
    if (total != 3) return 'Background bonuses must total +3 (got +$total).';
    final sortedValues = bonuses.values.toList()..sort();
    final isTwoOne = _setEquals(sortedValues, <int>[1, 2]);
    final isOneOneOne = _setEquals(sortedValues, <int>[1, 1, 1]);
    if (!isTwoOne && !isOneOneOne) {
      return 'Background bonus must be +2/+1 on two abilities or +1/+1/+1 on three.';
    }
    for (final a in Ability.values) {
      final post = (baseScores[a] ?? 0) + (bonuses[a] ?? 0);
      if (post > 20) {
        return '${a.short} would be $post after bonus (cap 20).';
      }
    }
    return null;
  }

  String? _requireSixScores(Map<Ability, int> scores) {
    for (final a in Ability.values) {
      if (scores[a] == null) return 'Missing base score for ${a.short}.';
    }
    return null;
  }

  bool _setEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
