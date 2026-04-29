import 'ability_score_method.dart';

/// Pure validator for ability score assignments. No I/O, no UI, no Riverpod —
/// safe to unit test and reuse across the wizard + later editor inspection.
class AbilityScoreValidator {
  /// Validates [scores] against [method] rules. Returns null on success,
  /// else a human-readable reason. [scores] keys must include all six
  /// [kAbilityKeys]; missing keys treated as 10.
  static String? validate({
    required AbilityScoreMethod method,
    required Map<String, int> scores,
  }) {
    for (final k in kAbilityKeys) {
      if (!scores.containsKey(k)) return 'Missing ability "$k".';
    }
    return switch (method) {
      AbilityScoreMethod.standardArray => _validateStandardArray(scores),
      AbilityScoreMethod.pointBuy => _validatePointBuy(scores),
      AbilityScoreMethod.random => _validateRange(scores, 3, 18),
      AbilityScoreMethod.manual => _validateRange(scores, 3, 20),
    };
  }

  /// Computes Point Buy points spent. Returns -1 if any score outside
  /// the buyable 8-15 window (caller should treat as invalid).
  static int pointBuyCost(Map<String, int> scores) {
    var total = 0;
    for (final k in kAbilityKeys) {
      final v = scores[k] ?? 10;
      final cost = kPointBuyCosts[v];
      if (cost == null) return -1;
      total += cost;
    }
    return total;
  }

  static String? _validateStandardArray(Map<String, int> scores) {
    final remaining = [...kStandardArray];
    for (final k in kAbilityKeys) {
      final v = scores[k] ?? 10;
      if (!remaining.remove(v)) {
        return 'Standard Array values must be 15/14/13/12/10/8 distributed across all six abilities.';
      }
    }
    return null;
  }

  static String? _validatePointBuy(Map<String, int> scores) {
    for (final k in kAbilityKeys) {
      final v = scores[k] ?? 10;
      if (!kPointBuyCosts.containsKey(v)) {
        return 'Point Buy scores must be in 8-15 range. "$k" is $v.';
      }
    }
    final cost = pointBuyCost(scores);
    if (cost > kPointBuyBudget) {
      return 'Point Buy total cost $cost exceeds budget $kPointBuyBudget.';
    }
    return null;
  }

  static String? _validateRange(Map<String, int> scores, int min, int max) {
    for (final k in kAbilityKeys) {
      final v = scores[k] ?? 10;
      if (v < min || v > max) {
        return '"$k" score $v out of range $min-$max.';
      }
    }
    return null;
  }
}

/// Pure SRD ability modifier: floor((score - 10) / 2). Negative scores allowed.
int abilityModifier(int score) {
  return ((score - 10) / 2).floor();
}
