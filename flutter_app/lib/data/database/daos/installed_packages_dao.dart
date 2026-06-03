import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/installed_packages_table.dart';

part 'installed_packages_dao.g.dart';

@DriftAccessor(tables: [InstalledPackages])
class InstalledPackagesDao extends DatabaseAccessor<AppDatabase>
    with _$InstalledPackagesDaoMixin {
  InstalledPackagesDao(super.db);

  Future<InstalledPackage?> get(String worldId, String packageId) =>
      (select(installedPackages)
            ..where((t) =>
                t.worldId.equals(worldId) & t.packageId.equals(packageId)))
          .getSingleOrNull();

  Future<List<InstalledPackage>> getByWorld(String worldId) =>
      (select(installedPackages)..where((t) => t.worldId.equals(worldId)))
          .get();

  Stream<List<InstalledPackage>> watchByWorld(String worldId) =>
      (select(installedPackages)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Future<void> upsert(InstalledPackagesCompanion row) =>
      into(installedPackages).insertOnConflictUpdate(row);

  Future<int> deleteOne(String worldId, String packageId) =>
      (delete(installedPackages)
            ..where((t) =>
                t.worldId.equals(worldId) & t.packageId.equals(packageId)))
          .go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(installedPackages)..where((t) => t.worldId.equals(worldId)))
          .go();

  /// Number of worlds (across ALL worlds) that still link [packageId]. Used to
  /// decide whether a materialized package row is safe to purge on world leave.
  Future<int> countWorldsForPackage(String packageId) async {
    final c = installedPackages.worldId.count();
    final row = await (selectOnly(installedPackages)
          ..addColumns([c])
          ..where(installedPackages.packageId.equals(packageId)))
        .getSingleOrNull();
    return row?.read(c) ?? 0;
  }
}
