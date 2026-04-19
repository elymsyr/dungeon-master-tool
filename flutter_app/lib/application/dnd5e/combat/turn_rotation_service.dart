import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/combat/encounter.dart';

/// Predicate over a [Combatant] used to decide whether a turn slot should be
/// skipped during rotation. Default behavior skips combatants at 0 HP — they
/// can't act this turn (PCs roll death saves out-of-band; monsters at 0 HP
/// are dead).
typedef TurnSkipPredicate = bool Function(Combatant c);

bool _skipAtZeroHp(Combatant c) => c.currentHp == 0;

/// Pure rotation helper layered on top of [Encounter.advanceTurn]. Walks
/// forward until the active combatant satisfies `!skip(c)`. If every
/// combatant would be skipped (TPK / total wipe), returns the encounter at
/// the next index without further advancement so the caller can decide what
/// "no one acts" means (end-of-encounter, idle round, …).
class TurnRotationService {
  final TurnSkipPredicate skip;

  const TurnRotationService({this.skip = _skipAtZeroHp});

  Encounter advance(Encounter e) {
    final n = e.combatants.length;
    var next = e.advanceTurn();
    for (var i = 0; i < n; i++) {
      final active = next.byId(next.order.currentId);
      if (active == null || !skip(active)) return next;
      next = next.advanceTurn();
    }
    // Full loop without finding an actor — return one-step-advanced state.
    return e.advanceTurn();
  }
}
