import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_sessions_table.dart';

part 'world_sessions_dao.g.dart';

@DriftAccessor(tables: [WorldSessions])
class WorldSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$WorldSessionsDaoMixin {
  WorldSessionsDao(super.db);

  Future<WorldSession?> getById(String id) =>
      (select(worldSessions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<WorldSession>> watchByWorld(String worldId) =>
      (select(worldSessions)
            ..where((t) => t.worldId.equals(worldId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch()
          .distinct();

  Future<List<WorldSession>> getByWorld(String worldId) =>
      (select(worldSessions)
            ..where((t) => t.worldId.equals(worldId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> upsert(WorldSessionsCompanion row) =>
      into(worldSessions).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldSessionsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldSessions, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(worldSessions)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldSessions)..where((t) => t.worldId.equals(worldId))).go();
}
