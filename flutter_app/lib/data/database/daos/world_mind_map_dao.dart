import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_mind_map_edges_table.dart';
import '../tables/world_mind_map_nodes_table.dart';

part 'world_mind_map_dao.g.dart';

@DriftAccessor(tables: [WorldMindMapNodes, WorldMindMapEdges])
class WorldMindMapDao extends DatabaseAccessor<AppDatabase>
    with _$WorldMindMapDaoMixin {
  WorldMindMapDao(super.db);

  // ── Nodes ────────────────────────────────────────────────────────────────

  Stream<List<WorldMindMapNode>> watchNodes(String worldId, String mapId) =>
      (select(worldMindMapNodes)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .watch()
          .distinct();

  Future<List<WorldMindMapNode>> getNodes(String worldId, String mapId) =>
      (select(worldMindMapNodes)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .get();

  Future<void> upsertNode(WorldMindMapNodesCompanion row) =>
      into(worldMindMapNodes).insertOnConflictUpdate(row);

  Future<void> upsertNodes(List<WorldMindMapNodesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldMindMapNodes, rows);
    });
  }

  Future<int> deleteNode(String id) =>
      (delete(worldMindMapNodes)..where((t) => t.id.equals(id))).go();

  // ── Edges ────────────────────────────────────────────────────────────────

  Stream<List<WorldMindMapEdge>> watchEdges(String worldId, String mapId) =>
      (select(worldMindMapEdges)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .watch()
          .distinct();

  Future<List<WorldMindMapEdge>> getEdges(String worldId, String mapId) =>
      (select(worldMindMapEdges)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .get();

  Future<void> upsertEdge(WorldMindMapEdgesCompanion row) =>
      into(worldMindMapEdges).insertOnConflictUpdate(row);

  Future<void> upsertEdges(List<WorldMindMapEdgesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldMindMapEdges, rows);
    });
  }

  Future<int> deleteEdge(String id) =>
      (delete(worldMindMapEdges)..where((t) => t.id.equals(id))).go();

  Future<void> replaceMap(
    String worldId,
    String mapId, {
    required List<WorldMindMapNodesCompanion> nodes,
    required List<WorldMindMapEdgesCompanion> edges,
  }) async {
    await transaction(() async {
      await (delete(worldMindMapEdges)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .go();
      await (delete(worldMindMapNodes)
            ..where(
                (t) => t.worldId.equals(worldId) & t.mapId.equals(mapId)))
          .go();
      await batch((b) {
        b.insertAll(worldMindMapNodes, nodes);
        b.insertAll(worldMindMapEdges, edges);
      });
    });
  }
}
