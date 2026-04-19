import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/combat/encounter.dart';

/// Pure helpers that build a new [Encounter] from an existing one with one
/// targeted change applied. Kept separate from the domain class so the domain
/// stays thin (identity + invariants) while the application layer owns the
/// "swap one combatant out" / "replace the whole list" mutation patterns.
class EncounterMutator {
  const EncounterMutator();

  /// Returns a new [Encounter] where the combatant matching [updated.id] is
  /// replaced. Throws [StateError] if no such combatant exists in [e].
  Encounter replaceCombatant(Encounter e, Combatant updated) {
    final list = <Combatant>[];
    var found = false;
    for (final c in e.combatants) {
      if (c.id == updated.id) {
        list.add(updated);
        found = true;
      } else {
        list.add(c);
      }
    }
    if (!found) {
      throw StateError(
          'EncounterMutator.replaceCombatant: no combatant with id "${updated.id}"');
    }
    return Encounter(
      id: e.id,
      name: e.name,
      combatants: list,
      order: e.order,
      round: e.round,
    );
  }

  /// Bulk-replace the entire combatant list while preserving id/name/order/
  /// round. Throws [ArgumentError] via [Encounter] if invariants break (e.g.
  /// the new list drops an id referenced by [Encounter.order]).
  Encounter replaceAll(Encounter e, List<Combatant> updated) {
    return Encounter(
      id: e.id,
      name: e.name,
      combatants: updated,
      order: e.order,
      round: e.round,
    );
  }
}
