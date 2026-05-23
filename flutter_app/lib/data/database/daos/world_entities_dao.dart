import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_entities_table.dart';

part 'world_entities_dao.g.dart';

@DriftAccessor(tables: [WorldEntities])
class WorldEntitiesDao extends DatabaseAccessor<AppDatabase>
    with _$WorldEntitiesDaoMixin {
  WorldEntitiesDao(super.db);

  Future<WorldEntity?> getById(String id) =>
      (select(worldEntities)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<WorldEntity>> getByWorld(String worldId) =>
      (select(worldEntities)..where((t) => t.worldId.equals(worldId))).get();

  Stream<List<WorldEntity>> watchByWorld(String worldId) =>
      (select(worldEntities)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Stream<List<WorldEntity>> watchByCategory(
      String worldId, String categorySlug) =>
      (select(worldEntities)
            ..where((t) =>
                t.worldId.equals(worldId) &
                t.categorySlug.equals(categorySlug)))
          .watch()
          .distinct();

  Future<void> upsert(WorldEntitiesCompanion row) =>
      into(worldEntities).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldEntitiesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldEntities, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(worldEntities)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(worldEntities)..where((t) => t.id.isIn(ids))).go();
  }

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldEntities)..where((t) => t.worldId.equals(worldId))).go();
}
