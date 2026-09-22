import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
import '../tables/map_pins_table.dart';

part 'map_pins_dao.g.dart';

@DriftAccessor(tables: [MapPins])
class MapPinsDao extends DatabaseAccessor<AppDatabase>
    with _$MapPinsDaoMixin {
  MapPinsDao(super.db);

  Future<MapPin?> getById(String id) =>
      (select(mapPins)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<MapPin>> watchByWorld(String worldId) =>
      (select(mapPins)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Future<void> upsert(MapPinsCompanion row) => into(mapPins)
      .insertOnConflictUpdate(row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertAll(List<MapPinsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(mapPins, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteById(String id) async {
    final row = await getById(id);
    if (row != null) {
      await recordTombstone('map_pins', id, worldId: row.worldId);
    }
    return (delete(mapPins)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByWorld(String worldId) async {
    final ids =
        (await (select(mapPins)..where((t) => t.worldId.equals(worldId))).get())
            .map((e) => e.id);
    await recordTombstones('map_pins', ids, worldId: worldId);
    return (delete(mapPins)..where((t) => t.worldId.equals(worldId))).go();
  }
}
