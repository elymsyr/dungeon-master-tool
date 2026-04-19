import 'dart:math' as math;

import '../../../domain/dnd5e/core/advantage_state.dart';

/// One d20 outcome carrying both dice (when rolled with advantage or
/// disadvantage) so the UI can show both faces. `chosen` is the face the
/// engine uses (max for advantage, min for disadvantage, the only roll for
/// normal).
class D20Outcome {
  final int chosen;
  final int other;
  final AdvantageState state;

  const D20Outcome({
    required this.chosen,
    required this.other,
    required this.state,
  });

  bool get isNaturalTwenty => chosen == 20;
  bool get isNaturalOne => chosen == 1;
}

/// Pure roller that turns an [AdvantageState] into a single d20 outcome.
/// Injected RNG keeps tests deterministic. Kept separate from [Dice] so the
/// attack/save pipelines can share the exact same roll semantics.
class D20Roller {
  final math.Random _rng;

  D20Roller([math.Random? rng]) : _rng = rng ?? math.Random();

  int _rawD20() => _rng.nextInt(20) + 1;

  D20Outcome roll(AdvantageState adv) {
    switch (adv) {
      case AdvantageState.normal:
        final a = _rawD20();
        return D20Outcome(chosen: a, other: a, state: adv);
      case AdvantageState.advantage:
        final a = _rawD20();
        final b = _rawD20();
        final chosen = a >= b ? a : b;
        final other = a >= b ? b : a;
        return D20Outcome(chosen: chosen, other: other, state: adv);
      case AdvantageState.disadvantage:
        final a = _rawD20();
        final b = _rawD20();
        final chosen = a <= b ? a : b;
        final other = a <= b ? b : a;
        return D20Outcome(chosen: chosen, other: other, state: adv);
    }
  }
}
