import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/combat_conditions_table.dart';
import '../tables/combatants_table.dart';
import '../tables/encounters_table.dart';

part 'combat_dao.g.dart';

/// Encounters + combatants + per-combatant conditions. Local-only.
@DriftAccessor(tables: [Encounters, Combatants, CombatConditions])
class CombatDao extends DatabaseAccessor<AppDatabase> with _$CombatDaoMixin {
  CombatDao(super.db);

  // ── Encounters ───────────────────────────────────────────────────────────

  Future<Encounter?> getEncounter(String id) =>
      (select(encounters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Encounter>> watchEncounters(String sessionId) =>
      (select(encounters)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch()
          .distinct();

  Future<void> upsertEncounter(EncountersCompanion row) =>
      into(encounters).insertOnConflictUpdate(row);

  Future<int> deleteEncounter(String id) async {
    return transaction(() async {
      // FK off — cascade manually via combatants → conditions.
      final cIds = (await (select(combatants)
                ..where((t) => t.encounterId.equals(id)))
              .get())
          .map((c) => c.id)
          .toList();
      if (cIds.isNotEmpty) {
        await (delete(combatConditions)
              ..where((t) => t.combatantId.isIn(cIds)))
            .go();
      }
      await (delete(combatants)..where((t) => t.encounterId.equals(id))).go();
      return (delete(encounters)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Combatants ───────────────────────────────────────────────────────────

  Future<List<Combatant>> getCombatants(String encounterId) =>
      (select(combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<Combatant>> watchCombatants(String encounterId) =>
      (select(combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch()
          .distinct();

  Future<void> upsertCombatant(CombatantsCompanion row) =>
      into(combatants).insertOnConflictUpdate(row);

  Future<void> upsertCombatants(List<CombatantsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(combatants, rows);
    });
  }

  Future<int> deleteCombatant(String id) async {
    return transaction(() async {
      await (delete(combatConditions)
            ..where((t) => t.combatantId.equals(id)))
          .go();
      return (delete(combatants)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Combat conditions ────────────────────────────────────────────────────

  Stream<List<CombatCondition>> watchConditions(String combatantId) =>
      (select(combatConditions)
            ..where((t) => t.combatantId.equals(combatantId)))
          .watch()
          .distinct();

  Future<int> insertCondition(CombatConditionsCompanion row) =>
      into(combatConditions).insert(row);

  Future<int> deleteCondition(int id) =>
      (delete(combatConditions)..where((t) => t.id.equals(id))).go();
}
