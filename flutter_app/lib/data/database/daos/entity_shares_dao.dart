import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/entity_shares_table.dart';

part 'entity_shares_dao.g.dart';

@DriftAccessor(tables: [EntityShares])
class EntitySharesDao extends DatabaseAccessor<AppDatabase>
    with _$EntitySharesDaoMixin {
  EntitySharesDao(super.db);

  Future<List<EntityShare>> getByWorld(String worldId) =>
      (select(entityShares)..where((t) => t.worldId.equals(worldId))).get();

  Stream<List<EntityShare>> watchByWorld(String worldId) =>
      (select(entityShares)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Stream<List<EntityShare>> watchForUser(String worldId, String userId) =>
      (select(entityShares)
            ..where((t) =>
                t.worldId.equals(worldId) &
                (t.sharedWith.equals(userId) | t.sharedWith.isNull())))
          .watch()
          .distinct();

  Future<void> upsert(EntitySharesCompanion row) =>
      into(entityShares).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<EntitySharesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(entityShares, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(entityShares)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(entityShares)..where((t) => t.worldId.equals(worldId))).go();
}
