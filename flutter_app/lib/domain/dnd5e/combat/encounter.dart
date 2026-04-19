import 'combatant.dart';
import 'initiative.dart';

/// One combat encounter. Holds the full combatant list (players + monsters),
/// an [InitiativeOrder], and the current round counter.
class Encounter {
  final String id;
  final String name;
  final List<Combatant> combatants;
  final InitiativeOrder order;
  final int round;

  Encounter._(this.id, this.name, this.combatants, this.order, this.round);

  factory Encounter({
    required String id,
    required String name,
    required List<Combatant> combatants,
    required InitiativeOrder order,
    int round = 1,
  }) {
    if (id.isEmpty) throw ArgumentError('Encounter.id must not be empty');
    if (name.isEmpty) throw ArgumentError('Encounter.name must not be empty');
    if (round < 1) throw ArgumentError('Encounter.round must be >= 1');
    if (combatants.isEmpty) {
      throw ArgumentError('Encounter.combatants must not be empty');
    }
    final ids = combatants.map((c) => c.id).toSet();
    if (ids.length != combatants.length) {
      throw ArgumentError('Encounter.combatants contains duplicate ids');
    }
    for (final cid in order.combatantIds) {
      if (!ids.contains(cid)) {
        throw ArgumentError(
            'Encounter.order references unknown combatant id "$cid"');
      }
    }
    return Encounter._(
        id, name, List.unmodifiable(combatants), order, round);
  }

  Combatant? byId(String combatantId) {
    for (final c in combatants) {
      if (c.id == combatantId) return c;
    }
    return null;
  }

  /// Advance to next combatant; bumps [round] when wrapping back to first.
  Encounter advanceTurn() {
    final next = order.advance();
    final wrapped = next.currentIndex == 0;
    return Encounter._(
        id, name, combatants, next, wrapped ? round + 1 : round);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Encounter && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
