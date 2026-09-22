import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
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
      into(encounters).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<int> deleteEncounter(String id) async {
    final worldId = (await getEncounter(id))?.worldId ?? '';
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
      await recordTombstones('world_combatants', cIds, worldId: worldId);
      await recordTombstone('world_encounters', id, worldId: worldId);
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
      into(combatants).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertCombatants(List<CombatantsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(combatants, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteCombatant(String id) async {
    final worldId = await _worldOfCombatant(id);
    return transaction(() async {
      await (delete(combatConditions)
            ..where((t) => t.combatantId.equals(id)))
          .go();
      await recordTombstone('world_combatants', id, worldId: worldId);
      return (delete(combatants)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Combatant'ın dünyası — yerelde encounter üzerinden, bulutta kolon.
  Future<String> _worldOfCombatant(String combatantId) async {
    final row = await (select(combatants)
          ..where((t) => t.id.equals(combatantId)))
        .getSingleOrNull();
    if (row == null) return '';
    return (await getEncounter(row.encounterId))?.worldId ?? '';
  }

  /// Durum etkileri bulutta combatant'ın `conditions_json` kolonu (§4.4) —
  /// ayrı satır değil. Push taraması yalnızca combatant'ın `updated_at`'ine
  /// bakar, o yüzden koşul değişimi ebeveyni damgalamak zorunda.
  Future<void> _touchCombatant(String combatantId) async {
    await (update(combatants)..where((t) => t.id.equals(combatantId)))
        .write(CombatantsCompanion(updatedAt: Value(DateTime.now())));
  }

  // ── Combat conditions ────────────────────────────────────────────────────

  Stream<List<CombatCondition>> watchConditions(String combatantId) =>
      (select(combatConditions)
            ..where((t) => t.combatantId.equals(combatantId)))
          .watch()
          .distinct();

  Future<int> insertCondition(CombatConditionsCompanion row) async {
    final res = await into(combatConditions).insert(row);
    if (row.combatantId.present) await _touchCombatant(row.combatantId.value);
    return res;
  }

  Future<int> deleteCondition(int id) async {
    final row = await (select(combatConditions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final res =
        await (delete(combatConditions)..where((t) => t.id.equals(id))).go();
    if (row != null) await _touchCombatant(row.combatantId);
    return res;
  }
}
