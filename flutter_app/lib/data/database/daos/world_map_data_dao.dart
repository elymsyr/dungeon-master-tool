import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_map_data_table.dart';

part 'world_map_data_dao.g.dart';

@DriftAccessor(tables: [WorldMapData])
class WorldMapDataDao extends DatabaseAccessor<AppDatabase>
    with _$WorldMapDataDaoMixin {
  WorldMapDataDao(super.db);

  Future<WorldMapDataData?> get(String worldId) =>
      (select(worldMapData)..where((t) => t.worldId.equals(worldId)))
          .getSingleOrNull();

  Stream<WorldMapDataData?> watch(String worldId) =>
      (select(worldMapData)..where((t) => t.worldId.equals(worldId)))
          .watchSingleOrNull()
          .distinct();

  Future<void> upsert(WorldMapDataCompanion row) =>
      into(worldMapData).insertOnConflictUpdate(row);

  /// LAN sync birleştirmesi sonrası satır damgası — bkz.
  /// `WorldEntitiesDao.setUpdatedAt`.
  Future<void> setUpdatedAt(String worldId, DateTime updatedAt) async {
    await (update(worldMapData)..where((t) => t.worldId.equals(worldId)))
        .write(WorldMapDataCompanion(updatedAt: Value(updatedAt)));
  }

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldMapData)..where((t) => t.worldId.equals(worldId))).go();
}
