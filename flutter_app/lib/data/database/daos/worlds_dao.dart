import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/worlds_table.dart';

part 'worlds_dao.g.dart';

@DriftAccessor(tables: [Worlds])
class WorldsDao extends DatabaseAccessor<AppDatabase> with _$WorldsDaoMixin {
  WorldsDao(super.db);

  Future<List<World>> getAll() => select(worlds).get();

  Stream<List<World>> watchAll() =>
      (select(worlds)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .distinct();

  Future<World?> getById(String id) =>
      (select(worlds)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<World?> getByName(String name) async {
    final rows = await (select(worlds)..where((t) => t.worldName.equals(name)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Stream<World?> watchById(String id) =>
      (select(worlds)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .distinct();

  Future<void> upsert(WorldsCompanion row) =>
      into(worlds).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worlds, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(worlds)..where((t) => t.id.equals(id))).go();

  Future<void> updateCloudPush(
    String id, {
    required DateTime pushedAt,
    required String pushedHash,
  }) async {
    await (update(worlds)..where((t) => t.id.equals(id))).write(
      WorldsCompanion(
        lastCloudPushAt: Value(pushedAt),
        lastPushedHash: Value(pushedHash),
      ),
    );
  }

  /// LAN sync: uygulanan item'ın zaman damgasını peer'ınkine sabitler.
  /// Repository `save()` her yazımda `DateTime.now()` basar; restamp olmazsa
  /// çekilen içerik anında "biz daha yeniyiz" görünüp geri push edilirdi.
  Future<void> setUpdatedAt(String id, DateTime updatedAt) async {
    await (update(worlds)..where((t) => t.id.equals(id)))
        .write(WorldsCompanion(updatedAt: Value(updatedAt)));
  }

  /// LAN sync: yeniden adlandırma zamanını kaydet.
  Future<void> setRenamedAt(String id, DateTime renamedAt) async {
    await (update(worlds)..where((t) => t.id.equals(id)))
        .write(WorldsCompanion(renamedAt: Value(renamedAt)));
  }
}
