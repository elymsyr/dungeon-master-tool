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
import '../tables/world_schemas_table.dart';

part 'campaign_dao.g.dart';

@DriftAccessor(tables: [
  Campaigns,
  WorldSchemas,
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
  Future<Campaign?> getByName(String worldName) =>
      (select(campaigns)..where((t) => t.worldName.equals(worldName)))
          .getSingleOrNull();

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

      // Schema
      await (delete(worldSchemas)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();

      // Kampanya
      await (delete(campaigns)..where((t) => t.id.equals(campaignId))).go();
    });
  }

  /// Kampanya adlarının listesi.
  Future<List<String>> getAvailableNames() =>
      select(campaigns).map((c) => c.worldName).get();
}
