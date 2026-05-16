import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_packages_table.dart';

part 'world_package_dao.g.dart';

@DriftAccessor(tables: [WorldPackages])
class WorldPackageDao extends DatabaseAccessor<AppDatabase>
    with _$WorldPackageDaoMixin {
  WorldPackageDao(super.db);

  Future<List<WorldPackage>> listForWorld(String worldId) =>
      (select(worldPackages)..where((t) => t.worldId.equals(worldId))).get();

  Stream<List<WorldPackage>> watchForWorld(String worldId) =>
      (select(worldPackages)..where((t) => t.worldId.equals(worldId))).watch();

  Future<WorldPackage?> get(String worldId, String packageId) =>
      (select(worldPackages)
            ..where((t) =>
                t.worldId.equals(worldId) & t.packageId.equals(packageId)))
          .getSingleOrNull();

  Future<void> upsert(WorldPackagesCompanion row) async {
    await into(worldPackages).insertOnConflictUpdate(row);
  }

  Future<void> remove(String worldId, String packageId) async {
    await (delete(worldPackages)
          ..where((t) =>
              t.worldId.equals(worldId) & t.packageId.equals(packageId)))
        .go();
  }

  Future<void> removeByPackageId(String packageId) async {
    await (delete(worldPackages)..where((t) => t.packageId.equals(packageId)))
        .go();
  }
}
