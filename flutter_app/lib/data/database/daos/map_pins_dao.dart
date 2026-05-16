import 'package:drift/drift.dart';

import '../app_database.dart';
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

  Future<void> upsert(MapPinsCompanion row) =>
      into(mapPins).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<MapPinsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(mapPins, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(mapPins)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(mapPins)..where((t) => t.worldId.equals(worldId))).go();
}
