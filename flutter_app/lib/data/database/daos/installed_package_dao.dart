import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/installed_packages_table.dart';

part 'installed_package_dao.g.dart';

@DriftAccessor(tables: [InstalledPackages])
class InstalledPackageDao extends DatabaseAccessor<AppDatabase>
    with _$InstalledPackageDaoMixin {
  InstalledPackageDao(super.db);

  Future<List<InstalledPackage>> listForCampaign(String campaignId) =>
      (select(installedPackages)
            ..where((t) => t.campaignId.equals(campaignId)))
          .get();

  Future<InstalledPackage?> get(String campaignId, String packageId) =>
      (select(installedPackages)
            ..where((t) =>
                t.campaignId.equals(campaignId) &
                t.packageId.equals(packageId)))
          .getSingleOrNull();

  Future<void> upsert(InstalledPackagesCompanion row) async {
    await into(installedPackages).insertOnConflictUpdate(row);
  }

  Future<void> remove(String campaignId, String packageId) async {
    await (delete(installedPackages)
          ..where((t) =>
              t.campaignId.equals(campaignId) &
              t.packageId.equals(packageId)))
        .go();
  }

  Future<void> touchSync(String campaignId, String packageId) async {
    await (update(installedPackages)
          ..where((t) =>
              t.campaignId.equals(campaignId) &
              t.packageId.equals(packageId)))
        .write(InstalledPackagesCompanion(lastSyncedAt: Value(DateTime.now())));
  }
}
