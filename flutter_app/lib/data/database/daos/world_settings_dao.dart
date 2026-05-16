import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_settings_table.dart';

part 'world_settings_dao.g.dart';

@DriftAccessor(tables: [WorldSettings])
class WorldSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$WorldSettingsDaoMixin {
  WorldSettingsDao(super.db);

  Future<WorldSetting?> get(String worldId) =>
      (select(worldSettings)..where((t) => t.worldId.equals(worldId)))
          .getSingleOrNull();

  Stream<WorldSetting?> watch(String worldId) =>
      (select(worldSettings)..where((t) => t.worldId.equals(worldId)))
          .watchSingleOrNull()
          .distinct();

  Future<void> upsert(WorldSettingsCompanion row) =>
      into(worldSettings).insertOnConflictUpdate(row);

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldSettings)..where((t) => t.worldId.equals(worldId))).go();
}
