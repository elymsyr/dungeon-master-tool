import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_packages_table.dart';

part 'world_packages_dao.g.dart';

@DriftAccessor(tables: [WorldPackages])
class WorldPackagesDao extends DatabaseAccessor<AppDatabase>
    with _$WorldPackagesDaoMixin {
  WorldPackagesDao(super.db);

  Future<WorldPackage?> getByPackage(String packageId) =>
      (select(worldPackages)..where((t) => t.packageId.equals(packageId)))
          .getSingleOrNull();

  Future<List<WorldPackage>> getByWorld(String worldId) =>
      (select(worldPackages)..where((t) => t.worldId.equals(worldId))).get();

  /// Every world↔package link row. Used by the hub Worlds-tab filter to build
  /// a worldId→packageNames map without an N+1 per-world query.
  Future<List<WorldPackage>> getAll() => select(worldPackages).get();

  Stream<List<WorldPackage>> watchByWorld(String worldId) =>
      (select(worldPackages)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Future<void> upsert(WorldPackagesCompanion row) =>
      into(worldPackages).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldPackagesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldPackages, rows);
    });
  }

  Future<int> deleteByPackage(String packageId) =>
      (delete(worldPackages)..where((t) => t.packageId.equals(packageId)))
          .go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldPackages)..where((t) => t.worldId.equals(worldId))).go();
}
