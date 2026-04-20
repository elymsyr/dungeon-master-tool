import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/campaigns_table.dart';
import '../tables/combat_conditions_table.dart';
import '../tables/combatants_table.dart';
import '../tables/encounters_table.dart';
import '../tables/entities_table.dart';
import '../tables/map_pins_table.dart';
import '../tables/mind_map_edges_table.dart';
import '../tables/mind_map_nodes_table.dart';
import '../tables/sessions_table.dart';
import '../tables/timeline_pins_table.dart';

part 'campaign_dao.g.dart';

@DriftAccessor(tables: [
  Campaigns,
  Entities,
  Sessions,
  Encounters,
  Combatants,
  CombatConditions,
  MapPins,
  TimelinePins,
  MindMapNodes,
  MindMapEdges,
])
class CampaignDao extends DatabaseAccessor<AppDatabase>
    with _$CampaignDaoMixin {
  CampaignDao(super.db);

  /// Tüm kampanya isimlerini getir.
  Future<List<Campaign>> getAll() => select(campaigns).get();

  /// Kampanya adına göre getir.
  ///
  /// Defensive against duplicate rows: the `Campaigns` table has no
  /// uniqueness constraint on `worldName`, and an earlier bug let
  /// `_migrateToDb` / `create` insert two rows with the same name. Using
  /// `getSingleOrNull` here previously crashed with "Bad state: Too many
  /// elements" the moment a user opened such a campaign. Now we fetch
  /// every match, return the most recently updated one, and (if more
  /// than one exists) sweep the older duplicates out so the next load
  /// doesn't have to deal with them.
  Future<Campaign?> getByName(String worldName) async {
    final rows = await (select(campaigns)
          ..where((t) => t.worldName.equals(worldName))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (rows.isEmpty) return null;
    if (rows.length > 1) {
      // Keep the freshest row, drop the rest. Cascade-delete the related
      // tables for each removed id so we don't leave orphaned entities /
      // sessions / encounters lying around.
      for (final stale in rows.skip(1)) {
        await deleteCampaign(stale.id);
      }
    }
    return rows.first;
  }

  /// Kampanya ID'ye göre getir.
  Future<Campaign?> getById(String id) =>
      (select(campaigns)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Yeni kampanya oluştur.
  Future<void> createCampaign(CampaignsCompanion campaign) =>
      into(campaigns).insert(campaign);

  /// Kampanya güncelle.
  Future<bool> updateCampaign(CampaignsCompanion campaign) =>
      (update(campaigns)..where((t) => t.id.equals(campaign.id.value)))
          .write(campaign)
          .then((rows) => rows > 0);

  /// Kampanyayı ve tüm ilişkili verileri sil (cascade).
  Future<void> deleteCampaign(String campaignId) async {
    await transaction(() async {
      // Önce child tablolardan sil (FK sırası)
      // Combat conditions → combatants → encounters → sessions
      final encounterIds = await (select(encounters)
            ..where((t) => t.campaignId.equals(campaignId)))
          .map((e) => e.id)
          .get();

      if (encounterIds.isNotEmpty) {
        final combatantIds = await (select(combatants)
              ..where((t) => t.encounterId.isIn(encounterIds)))
            .map((c) => c.id)
            .get();

        if (combatantIds.isNotEmpty) {
          await (delete(combatConditions)
                ..where((t) => t.combatantId.isIn(combatantIds)))
              .go();
        }
        await (delete(combatants)
              ..where((t) => t.encounterId.isIn(encounterIds)))
            .go();
      }

      await (delete(encounters)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      await (delete(sessions)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();

      // Mind map
      await (delete(mindMapEdges)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      await (delete(mindMapNodes)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();

      // Map
      await (delete(timelinePins)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      await (delete(mapPins)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();

      // Entities
      await (delete(entities)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();

      // Kampanya
      await (delete(campaigns)..where((t) => t.id.equals(campaignId))).go();
    });
  }

  /// Kampanya adlarının listesi.
  Future<List<String>> getAvailableNames() =>
      select(campaigns).map((c) => c.worldName).get();

  /// Returns (id, worldName, schemaName) tuples for the hub campaign list.
  /// Post-v9 the `world_schemas` join is gone; every campaign uses the
  /// single hardcoded D&D 5e schema so templateName is constant.
  Future<List<({String id, String worldName, String templateName})>>
      getCampaignInfoList() async {
    final rows = await (select(campaigns)
          ..orderBy([(t) => OrderingTerm.asc(t.worldName)]))
        .get();
    return rows
        .map((c) => (
              id: c.id,
              worldName: c.worldName,
              templateName: 'D&D 5e',
            ))
        .toList();
  }
}
