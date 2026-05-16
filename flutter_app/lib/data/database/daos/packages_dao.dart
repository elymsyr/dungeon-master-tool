import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/package_entities_table.dart';
import '../tables/package_schemas_table.dart';
import '../tables/packages_table.dart';

part 'packages_dao.g.dart';

/// Local package catalog (Packages, PackageSchemas, PackageEntities).
@DriftAccessor(tables: [Packages, PackageSchemas, PackageEntities])
class PackagesDao extends DatabaseAccessor<AppDatabase>
    with _$PackagesDaoMixin {
  PackagesDao(super.db);

  // ── Packages ─────────────────────────────────────────────────────────────

  Future<Package?> getById(String id) =>
      (select(packages)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Package>> getAll() => select(packages).get();

  Stream<List<Package>> watchAll() =>
      (select(packages)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .distinct();

  Future<void> upsertPackage(PackagesCompanion row) =>
      into(packages).insertOnConflictUpdate(row);

  Future<int> deletePackage(String id) =>
      (delete(packages)..where((t) => t.id.equals(id))).go();

  Future<void> updateCloudPush(
    String id, {
    required DateTime pushedAt,
    required String pushedHash,
  }) async {
    await (update(packages)..where((t) => t.id.equals(id))).write(
      PackagesCompanion(
        lastCloudPushAt: Value(pushedAt),
        lastPushedHash: Value(pushedHash),
      ),
    );
  }

  // ── Package schemas ──────────────────────────────────────────────────────

  Future<List<PackageSchema>> getSchemas(String packageId) =>
      (select(packageSchemas)..where((t) => t.packageId.equals(packageId)))
          .get();

  Future<void> upsertSchema(PackageSchemasCompanion row) =>
      into(packageSchemas).insertOnConflictUpdate(row);

  Future<int> deleteSchemasByPackage(String packageId) =>
      (delete(packageSchemas)..where((t) => t.packageId.equals(packageId)))
          .go();

  // ── Package entities ─────────────────────────────────────────────────────

  Future<List<PackageEntity>> getEntities(String packageId) =>
      (select(packageEntities)..where((t) => t.packageId.equals(packageId)))
          .get();

  Stream<List<PackageEntity>> watchEntities(String packageId) =>
      (select(packageEntities)..where((t) => t.packageId.equals(packageId)))
          .watch()
          .distinct();

  Future<void> upsertEntity(PackageEntitiesCompanion row) =>
      into(packageEntities).insertOnConflictUpdate(row);

  Future<void> upsertEntities(List<PackageEntitiesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(packageEntities, rows);
    });
  }

  Future<int> deleteEntity(String id) =>
      (delete(packageEntities)..where((t) => t.id.equals(id))).go();

  Future<int> deleteEntitiesByPackage(String packageId) =>
      (delete(packageEntities)..where((t) => t.packageId.equals(packageId)))
          .go();
}
