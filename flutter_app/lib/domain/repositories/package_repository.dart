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

  /// Paketi sil.
  Future<void> delete(String packageName);

  /// Yeni paket oluştur, template ile.
  Future<String> create(String packageName, {WorldSchema? template});
}
