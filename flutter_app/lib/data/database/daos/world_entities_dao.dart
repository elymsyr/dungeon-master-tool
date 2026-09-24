import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
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

  /// Damga şart: companion `updated_at` taşımazsa ON CONFLICT onu eski
  /// haliyle bırakır ve düzenleme push taramasına hiç düşmez.
  Future<void> upsert(WorldEntitiesCompanion row) => into(worldEntities)
      .insertOnConflictUpdate(row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertAll(List<WorldEntitiesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldEntities, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteById(String id) async {
    final row = await getById(id);
    if (row != null) {
      await recordTombstone('world_entities', id, worldId: row.worldId);
    }
    return (delete(worldEntities)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final rows = await (select(worldEntities)..where((t) => t.id.isIn(ids)))
        .get();
    for (final r in rows) {
      await recordTombstone('world_entities', r.id, worldId: r.worldId);
    }
    return (delete(worldEntities)..where((t) => t.id.isIn(ids))).go();
  }

  /// Dünyanın bütün kartlarını düşürür — `save()`'in full-replace yolu ve
  /// dünya silme. Tombstone yazılır; delete+reinsert durumunda push satırın
  /// yerelde geri geldiğini görüp tombstone'u atar (bkz. [CloudPushService]).
  Future<int> deleteByWorld(String worldId) async {
    final ids = (await getByWorld(worldId)).map((e) => e.id);
    await recordTombstones('world_entities', ids, worldId: worldId);
    return (delete(worldEntities)..where((t) => t.worldId.equals(worldId)))
        .go();
  }

  /// `.dmtz` import: birleştirme sonrası satır damgasını kazanan tarafınkine
  /// sabitler. Bulk `save()` yolu satırları silip yeniden eklediği için
  /// hepsi `now()` olurdu; o zaman "hangi cihaz bu entity'yi düzenledi"
  /// bilgisi kaybolur ve bir sonraki birleştirmede bölüm karşılaştırması
  /// anlamsızlaşırdı.
  Future<void> setUpdatedAt(String id, DateTime updatedAt) async {
    await (update(worldEntities)..where((t) => t.id.equals(id)))
        .write(WorldEntitiesCompanion(updatedAt: Value(updatedAt)));
  }
}
