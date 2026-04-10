import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/package_entities_table.dart';
import '../tables/package_schemas_table.dart';
import '../tables/packages_table.dart';

part 'package_dao.g.dart';

@DriftAccessor(tables: [Packages, PackageSchemas, PackageEntities])
class PackageDao extends DatabaseAccessor<AppDatabase>
    with _$PackageDaoMixin {
  PackageDao(super.db);

  /// Tüm paketleri getir.
  Future<List<Package>> getAll() => select(packages).get();

  /// Paket adına göre getir.
  Future<Package?> getByName(String name) async {
    final rows = await (select(packages)
          ..where((t) => t.name.equals(name))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (rows.isEmpty) return null;
    if (rows.length > 1) {
      for (final stale in rows.skip(1)) {
        await deletePackage(stale.id);
      }
    }
    return rows.first;
  }

  /// Paket ID'ye göre getir.
  Future<Package?> getById(String id) =>
      (select(packages)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Yeni paket oluştur.
  Future<void> createPackage(PackagesCompanion pkg) =>
      into(packages).insert(pkg);

  /// Paket güncelle.
  Future<bool> updatePackage(PackagesCompanion pkg) =>
      (update(packages)..where((t) => t.id.equals(pkg.id.value)))
          .write(pkg)
          .then((rows) => rows > 0);

  /// Paketi ve tüm ilişkili verileri sil (cascade).
  Future<void> deletePackage(String packageId) async {
    await transaction(() async {
      await (delete(packageEntities)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (delete(packageSchemas)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (delete(packages)..where((t) => t.id.equals(packageId))).go();
    });
  }

  /// Paket adlarının listesi.
  Future<List<String>> getAvailableNames() =>
      select(packages).map((p) => p.name).get();

  /// (name, templateName, entityCount) bilgileri — hub listesi için.
  Future<List<({String name, String templateName, int entityCount})>>
      getPackageInfoList() async {
    final query = select(packages).join([
      leftOuterJoin(
          packageSchemas, packageSchemas.packageId.equalsExp(packages.id)),
    ]);
    query.orderBy([OrderingTerm.asc(packages.name)]);
    final rows = await query.get();

    final results = <({String name, String templateName, int entityCount})>[];
    for (final row in rows) {
      final pkg = row.readTable(packages);
      final schema = row.readTableOrNull(packageSchemas);
      final count = await countEntities(pkg.id);
      results.add((
        name: pkg.name,
        templateName: schema?.name ?? 'Unknown',
        entityCount: count,
      ));
    }
    return results;
  }

  /// Paketteki entity sayısı.
  Future<int> countEntities(String packageId) async {
    final count = packageEntities.id.count();
    final query = selectOnly(packageEntities)
      ..addColumns([count])
      ..where(packageEntities.packageId.equals(packageId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Paketteki tüm entity'leri getir.
  Future<List<PackageEntity>> getAllEntities(String packageId) =>
      (select(packageEntities)
            ..where((t) => t.packageId.equals(packageId)))
          .get();

  /// Birden fazla entity'yi batch olarak ekle.
  Future<void> insertAllEntities(
      List<PackageEntitiesCompanion> entityList) async {
    await batch((b) {
      b.insertAll(packageEntities, entityList);
    });
  }
}
