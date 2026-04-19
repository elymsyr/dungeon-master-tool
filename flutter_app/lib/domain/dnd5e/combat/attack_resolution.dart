import '../core/ability.dart';
import '../core/advantage_state.dart';

/// d20 attack-roll result. [natural] is the raw die face (1..20); [total]
/// includes bonuses. [isCrit] / [isFumble] use SRD rules (nat 20 / nat 1).
class AttackRoll {
  final int natural;
  final int total;
  final AdvantageState advantage;

  const AttackRoll._(this.natural, this.total, this.advantage);

  factory AttackRoll({
    required int natural,
    required int total,
    AdvantageState advantage = AdvantageState.normal,
  }) {
    if (natural < 1 || natural > 20) {
      throw ArgumentError('AttackRoll.natural must be in [1, 20]');
    }
    return AttackRoll._(natural, total, advantage);
  }

  bool get isCrit => natural == 20;
  bool get isFumble => natural == 1;
}

/// Aggregated damage roll — engine sums per-type entries for vulnerability /
/// resistance / immunity resolution in [Doc 13](../../docs/engineering/13-damage-resolver-spec.md).
class DamageRoll {
  final Map<String, int> byTypeId; // damageTypeId -> amount (pre-resistance)

  DamageRoll(Map<String, int> byTypeId) : byTypeId = Map.unmodifiable(byTypeId);

  int get total => byTypeId.values.fold(0, (a, b) => a + b);
}

/// Saving-throw outcome.
class SaveRoll {
  final Ability ability;
  final int dc;
  final int total;
  final bool succeeded;

  const SaveRoll({
    required this.ability,
    required this.dc,
    required this.total,
    required this.succeeded,
  });
}
