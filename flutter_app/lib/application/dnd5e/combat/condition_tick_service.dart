import '../../../domain/dnd5e/combat/combatant.dart';

/// Outcome of one tick over a single combatant. Records which conditions
/// expired so the caller can surface a UI notification or fire an
/// "OnConditionExpire" hook in the future.
class ConditionTickResult {
  final Combatant combatant;
  final Set<String> expiredConditionIds;

  ConditionTickResult({
    required this.combatant,
    required Set<String> expiredConditionIds,
  }) : expiredConditionIds = Set.unmodifiable(expiredConditionIds);
}

/// Pure round-based duration decay over a single [Combatant]. Decrements
/// every entry in `conditionDurationsRounds` by 1; entries hitting 0 are
/// removed from both the duration map and the active condition set.
///
/// Conditions without a tracked duration (entries in `conditionIds` that
/// have no key in the duration map) are open-ended — typically applied by
/// effects that end on the carrier's choice or via a save mechanic — and
/// are left untouched.
class ConditionTickService {
  const ConditionTickService();

  ConditionTickResult tick(Combatant c) {
    final durations = c.conditionDurationsRounds;
    if (durations.isEmpty) {
      return ConditionTickResult(combatant: c, expiredConditionIds: const {});
    }

    final newDurations = <String, int>{};
    final expired = <String>{};
    for (final entry in durations.entries) {
      final next = entry.value - 1;
      if (next <= 0) {
        expired.add(entry.key);
      } else {
        newDurations[entry.key] = next;
      }
    }

    final newConditions = <String>{};
    for (final id in c.conditionIds) {
      if (!expired.contains(id)) newConditions.add(id);
    }

    return ConditionTickResult(
      combatant: switch (c) {
        PlayerCombatant pc => pc.copyWith(
            conditionIds: newConditions,
            conditionDurationsRounds: newDurations,
          ),
        MonsterCombatant mc => mc.copyWith(
            conditionIds: newConditions,
            conditionDurationsRounds: newDurations,
          ),
      },
      expiredConditionIds: expired,
    );
  }

  List<ConditionTickResult> tickAll(Iterable<Combatant> cs) =>
      [for (final c in cs) tick(c)];
}
