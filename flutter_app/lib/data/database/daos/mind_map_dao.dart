import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/mind_map_edges_table.dart';
import '../tables/mind_map_nodes_table.dart';

part 'mind_map_dao.g.dart';

@DriftAccessor(tables: [MindMapNodes, MindMapEdges])
class MindMapDao extends DatabaseAccessor<AppDatabase>
    with _$MindMapDaoMixin {
  MindMapDao(super.db);

  // --- Nodes ---

  Future<List<MindMapNode>> getNodesForMap(
          String campaignId, String mapId) =>
      (select(mindMapNodes)
            ..where((t) =>
                t.campaignId.equals(campaignId) & t.mapId.equals(mapId)))
          .get();

  Stream<List<MindMapNode>> watchNodesForMap(
          String campaignId, String mapId) =>
      (select(mindMapNodes)
            ..where((t) =>
                t.campaignId.equals(campaignId) & t.mapId.equals(mapId)))
          .watch();

  Future<void> createNode(MindMapNodesCompanion node) =>
      into(mindMapNodes).insert(node);

  Future<bool> updateNode(MindMapNodesCompanion node) =>
      (update(mindMapNodes)..where((t) => t.id.equals(node.id.value)))
          .write(node)
          .then((rows) => rows > 0);

  Future<int> deleteNode(String id) async {
    // Cascade: önce bu node'a bağlı edge'leri sil
    await (delete(mindMapEdges)
          ..where((t) => t.sourceId.equals(id) | t.targetId.equals(id)))
        .go();
    return (delete(mindMapNodes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> insertAllNodes(List<MindMapNodesCompanion> nodes) async {
    await batch((b) => b.insertAll(mindMapNodes, nodes));
  }

  // --- Edges ---

  Future<List<MindMapEdge>> getEdgesForMap(
          String campaignId, String mapId) =>
      (select(mindMapEdges)
            ..where((t) =>
                t.campaignId.equals(campaignId) & t.mapId.equals(mapId)))
          .get();

  Stream<List<MindMapEdge>> watchEdgesForMap(
          String campaignId, String mapId) =>
      (select(mindMapEdges)
            ..where((t) =>
                t.campaignId.equals(campaignId) & t.mapId.equals(mapId)))
          .watch();

  Future<void> createEdge(MindMapEdgesCompanion edge) =>
      into(mindMapEdges).insert(edge);

  Future<int> deleteEdge(String id) =>
      (delete(mindMapEdges)..where((t) => t.id.equals(id))).go();

  Future<void> insertAllEdges(List<MindMapEdgesCompanion> edges) async {
    await batch((b) => b.insertAll(mindMapEdges, edges));
  }

  /// Kampanyadaki tüm mind map ID'lerini getir.
  Future<List<String>> getMapIdsForCampaign(String campaignId) =>
      (selectOnly(mindMapNodes, distinct: true)
            ..addColumns([mindMapNodes.mapId])
            ..where(mindMapNodes.campaignId.equals(campaignId)))
          .map((row) => row.read(mindMapNodes.mapId)!)
          .get();
}
