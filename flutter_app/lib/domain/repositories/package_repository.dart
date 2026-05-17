import '../entities/package_info.dart';
import '../entities/schema/world_schema.dart';

/// Package persistence interface.
abstract class PackageRepository {
  /// Mevcut paket isimlerini getir.
  Future<List<String>> getAvailable();

  /// Paket bilgi listesini getir (ad + template adı + entity sayısı).
  Future<List<PackageInfo>> getPackageInfoList();

  /// Paket verisini yükle.
  Future<Map<String, dynamic>> load(String packageName);

  /// Paket verisini kaydet.
  Future<void> save(String packageName, Map<String, dynamic> data);

  /// Row-level package entity upsert. Tek satır package_entities yazımı.
  /// Built-in pack adı verilirse no-op.
  Future<void> saveEntity(
    String packageName,
    String entityId,
    Map<String, dynamic> row,
  );

  /// Row-level package entity delete. Built-in pack adı verilirse no-op.
  Future<void> deleteEntity(String packageName, String entityId);

  /// Paket state_json içinde verilen key'leri merge eder. Read-merge-write
  /// Drift transaction; diğer key'ler korunur. Built-in pack için no-op.
  Future<void> saveStatePatch(String packageName, Map<String, dynamic> patch);

  /// Paketi sil.
  Future<void> delete(String packageName);

  /// Yeni paket oluştur, template ile.
  Future<String> create(String packageName, {WorldSchema? template});

  /// Mevcut bir paketi yeni bir adla klonla (entity'ler + schema dahil).
  /// Built-in pack'i kopyalayıp kullanıcı tarafından düzenlenebilir hale
  /// getirmek için kullanılır.
  Future<String> copy({
    required String sourceName,
    required String destinationName,
  });

  /// PR-D4: restore a soft-deleted package from `trash_items` by its trash
  /// row id. Returns false on conflict / corrupt payload.
  Future<bool> restoreFromTrash(String trashId);

  /// PR-D4: hard-delete a trash row.
  Future<void> permanentlyDelete(String trashId);
}
