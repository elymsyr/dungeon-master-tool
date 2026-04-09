import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/combat_conditions_table.dart';
import '../tables/combatants_table.dart';
import '../tables/encounters_table.dart';
import '../tables/sessions_table.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions, Encounters, Combatants, CombatConditions])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  // --- Sessions ---

  Future<List<Session>> getAllForCampaign(String campaignId) =>
      (select(sessions)..where((t) => t.campaignId.equals(campaignId))).get();

  Future<Session?> getById(String id) =>
      (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> createSession(SessionsCompanion session) =>
      into(sessions).insert(session);

  Future<bool> updateSession(SessionsCompanion session) =>
      (update(sessions)..where((t) => t.id.equals(session.id.value)))
          .write(session)
          .then((rows) => rows > 0);

  Future<int> deleteSession(String id) =>
      (delete(sessions)..where((t) => t.id.equals(id))).go();

  // --- Encounters ---

  Future<List<Encounter>> getEncountersForSession(String sessionId) =>
      (select(encounters)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<List<Encounter>> getEncountersForCampaign(String campaignId) =>
      (select(encounters)
            ..where((t) => t.campaignId.equals(campaignId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<Encounter>> watchEncountersForCampaign(String campaignId) =>
      (select(encounters)
            ..where((t) => t.campaignId.equals(campaignId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<void> createEncounter(EncountersCompanion encounter) =>
      into(encounters).insert(encounter);

  Future<bool> updateEncounter(EncountersCompanion encounter) =>
      (update(encounters)..where((t) => t.id.equals(encounter.id.value)))
          .write(encounter)
          .then((rows) => rows > 0);

  Future<int> deleteEncounter(String id) async {
    // Cascade: conditions → combatants → encounter
    final combatantIds = await (select(combatants)
          ..where((t) => t.encounterId.equals(id)))
        .map((c) => c.id)
        .get();

    if (combatantIds.isNotEmpty) {
      await (delete(combatConditions)
            ..where((t) => t.combatantId.isIn(combatantIds)))
          .go();
    }
    await (delete(combatants)..where((t) => t.encounterId.equals(id))).go();
    return (delete(encounters)..where((t) => t.id.equals(id))).go();
  }

  // --- Combatants ---

  Future<List<Combatant>> getCombatantsForEncounter(String encounterId) =>
      (select(combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<Combatant>> watchCombatantsForEncounter(String encounterId) =>
      (select(combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<void> createCombatant(CombatantsCompanion combatant) =>
      into(combatants).insert(combatant);

  Future<bool> updateCombatant(CombatantsCompanion combatant) =>
      (update(combatants)..where((t) => t.id.equals(combatant.id.value)))
          .write(combatant)
          .then((rows) => rows > 0);

  Future<int> deleteCombatant(String id) async {
    await (delete(combatConditions)..where((t) => t.combatantId.equals(id)))
        .go();
    return (delete(combatants)..where((t) => t.id.equals(id))).go();
  }

  /// Tüm combatant'ları batch güncelle (initiative sort sonrası).
  Future<void> updateCombatantsBatch(List<CombatantsCompanion> list) async {
    await batch((b) {
      for (final c in list) {
        b.replace(combatants, c);
      }
    });
  }

  // --- Combat Conditions ---

  Future<List<CombatCondition>> getConditionsForCombatant(
          String combatantId) =>
      (select(combatConditions)
            ..where((t) => t.combatantId.equals(combatantId)))
          .get();

  Future<void> addCondition(CombatConditionsCompanion condition) =>
      into(combatConditions).insert(condition);

  Future<int> removeCondition(int conditionId) =>
      (delete(combatConditions)..where((t) => t.id.equals(conditionId))).go();

  Future<int> removeConditionByName(String combatantId, String name) =>
      (delete(combatConditions)
            ..where(
                (t) => t.combatantId.equals(combatantId) & t.name.equals(name)))
          .go();

  /// Encounter'daki tüm combatant'ların condition sürelerini 1 düşür.
  /// Süresi 0'a düşenleri sil.
  Future<void> tickConditions(String encounterId) async {
    final combatantIds = await (select(combatants)
          ..where((t) => t.encounterId.equals(encounterId)))
        .map((c) => c.id)
        .get();

    if (combatantIds.isEmpty) return;

    await transaction(() async {
      // Süresi 1 olanları sil (0'a düşecekler)
      await (delete(combatConditions)
            ..where((t) =>
                t.combatantId.isIn(combatantIds) &
                t.duration.isNotNull() &
                t.duration.equals(1)))
          .go();

      // Geri kalanların süresini düşür
      await customUpdate(
        'UPDATE combat_conditions SET duration = duration - 1 '
        'WHERE combatant_id IN (${combatantIds.map((_) => '?').join(',')}) '
        'AND duration IS NOT NULL AND duration > 1',
        variables: combatantIds.map((id) => Variable.withString(id)).toList(),
        updates: {combatConditions},
      );
    });
  }
}
