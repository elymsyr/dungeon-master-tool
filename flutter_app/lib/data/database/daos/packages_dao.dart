import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
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

  Future<Package?> getByName(String name) async {
    final rows =
        await (select(packages)..where((t) => t.name.equals(name))).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Package>> getAll() => select(packages).get();

  Stream<List<Package>> watchAll() =>
      (select(packages)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .distinct();

  Future<void> upsertPackage(PackagesCompanion row) => into(packages)
      .insertOnConflictUpdate(row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  /// Paket yerelden silinirken bekleyen tombstone'ları da düşürür: paket
  /// satırı gidince `pushPackage` bir daha koşamaz, kayıtlar sonsuza kadar
  /// birikirdi. Bulut satırının silinmesi "Online kapat" yolundan geçiyor.
  Future<int> deletePackage(String id) async {
    await customStatement(
        'DELETE FROM sync_tombstones WHERE world_id = ?', [id]);
    return (delete(packages)..where((t) => t.id.equals(id))).go();
  }

  /// Faz 4b push damgası — "bu ana kadarki her satır bulutta".
  Future<void> setCloudPushAt(String id, DateTime pushedAt) async {
    await (update(packages)..where((t) => t.id.equals(id)))
        .write(PackagesCompanion(lastCloudPushAt: Value(pushedAt)));
  }

  /// Faz 4b — paketin bulut aynası açık/kapalı. Dünyadaki eşiyle aynı kural:
  /// kapatılan paket yeniden açıldığında damga sıfırdan başlar ki kapalıyken
  /// yapılan düzenlemeler de bir kez daha gitsin.
  Future<void> setOnline(String id, bool online) async {
    await (update(packages)..where((t) => t.id.equals(id))).write(
      PackagesCompanion(
        isOnline: Value(online),
        lastCloudPushAt: online ? const Value.absent() : const Value(null),
      ),
    );
  }

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

  /// LAN sync: uygulanan item'ın zaman damgasını peer'ınkine sabitler.
  /// Repository `save()` her yazımda `DateTime.now()` basar; restamp olmazsa
  /// çekilen içerik anında "biz daha yeniyiz" görünüp geri push edilirdi.
  Future<void> setUpdatedAt(String id, DateTime updatedAt) async {
    await (update(packages)..where((t) => t.id.equals(id)))
        .write(PackagesCompanion(updatedAt: Value(updatedAt)));
  }

  /// LAN sync: yeniden adlandırma zamanını kaydet.
  Future<void> setRenamedAt(String id, DateTime renamedAt) async {
    await (update(packages)..where((t) => t.id.equals(id)))
        .write(PackagesCompanion(renamedAt: Value(renamedAt)));
  }

  // ── Package schemas ──────────────────────────────────────────────────────

  Future<List<PackageSchema>> getSchemas(String packageId) =>
      (select(packageSchemas)..where((t) => t.packageId.equals(packageId)))
          .get();

  /// First schema name per package, projecting ONLY id+name — avoids pulling
  /// the big categories/encounter JSON blobs just to show a template name
  /// in the package list (DB-2).
  Future<Map<String, String>> firstSchemaNameByPackage() async {
    final rows = await (selectOnly(packageSchemas)
          ..addColumns([packageSchemas.packageId, packageSchemas.name]))
        .get();
    final out = <String, String>{};
    for (final r in rows) {
      final pid = r.read(packageSchemas.packageId);
      if (pid == null) continue;
      out.putIfAbsent(pid, () => r.read(packageSchemas.name) ?? '');
    }
    return out;
  }

  Future<void> upsertSchema(PackageSchemasCompanion row) =>
      into(packageSchemas).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<int> deleteSchemasByPackage(String packageId) async {
    final ids = (await getSchemas(packageId)).map((e) => e.id);
    await recordTombstones('user_package_schemas', ids, worldId: packageId);
    return (delete(packageSchemas)..where((t) => t.packageId.equals(packageId)))
        .go();
  }

  // ── Package entities ─────────────────────────────────────────────────────

  Future<List<PackageEntity>> getEntities(String packageId) =>
      (select(packageEntities)..where((t) => t.packageId.equals(packageId)))
          .get();

  /// Count entities for one package without materialising rows — used by the
  /// SRD bootstrap gate (CS-1) instead of `getEntities(id).isNotEmpty`.
  Future<int> countEntities(String packageId) async {
    final countExp = packageEntities.id.count();
    final row = await (selectOnly(packageEntities)
          ..addColumns([countExp])
          ..where(packageEntities.packageId.equals(packageId)))
        .getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  /// Entity count per package in one grouped query — avoids materialising
  /// every row just to call `.length` (DB-2). Packages with zero entities are
  /// simply absent from the map.
  Future<Map<String, int>> countEntitiesByPackage() async {
    final countExp = packageEntities.id.count();
    final rows = await (selectOnly(packageEntities)
          ..addColumns([packageEntities.packageId, countExp])
          ..groupBy([packageEntities.packageId]))
        .get();
    return {
      for (final r in rows)
        r.read(packageEntities.packageId)!: r.read(countExp) ?? 0,
    };
  }

  Stream<List<PackageEntity>> watchEntities(String packageId) =>
      (select(packageEntities)..where((t) => t.packageId.equals(packageId)))
          .watch()
          .distinct();

  Future<void> upsertEntity(PackageEntitiesCompanion row) =>
      into(packageEntities).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertEntities(List<PackageEntitiesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(packageEntities, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteEntity(String id) async {
    final row = await (select(packageEntities)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row != null) {
      await recordTombstone('user_package_entities', id,
          worldId: row.packageId);
    }
    return (delete(packageEntities)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteEntitiesByPackage(String packageId) async {
    final ids = (await getEntities(packageId)).map((e) => e.id);
    await recordTombstones('user_package_entities', ids, worldId: packageId);
    return (delete(packageEntities)..where((t) => t.packageId.equals(packageId)))
        .go();
  }
}
