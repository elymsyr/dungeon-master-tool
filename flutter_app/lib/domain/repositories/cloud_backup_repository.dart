import '../entities/cloud_backup_meta.dart';

/// Cloud backup persistence interface.
/// Supabase Storage + Postgres metadata tablosu uzerinden calisir.
/// Worlds, templates ve packages icin ortak kullanilir.
abstract class CloudBackupRepository {
  /// Kullanicinin tum cloud backup'larini listele.
  Future<List<CloudBackupMeta>> listBackups();

  /// Belirli tip icin backup listele (world, template, package).
  Future<List<CloudBackupMeta>> listBackupsByType(String type);

  /// Item verisini cloud'a yedekle.
  /// [type]: `world`, `template`, `package`
  Future<CloudBackupMeta> uploadBackup(
    String itemName,
    String itemId,
    String type,
    Map<String, dynamic> data, {
    String? notes,
  });

  /// Cloud backup'i indir ve veri olarak don.
  Future<Map<String, dynamic>> downloadBackup(String backupId);

  /// Cloud backup'i sil (Storage + metadata).
  Future<void> deleteBackup(String backupId);

  /// Item ID + type kombinasyonuna gore cloud backup'i sil.
  /// Backup yoksa no-op doner.
  Future<void> deleteBackupByItem(String itemId, String type);

  /// Kullanicinin toplam cloud storage kullanimini getir (bytes).
  Future<int> getTotalStorageUsed();

  /// Kullanicinin en yeni backup'inin `created_at` degeri (herhangi bir
  /// tipte). Multi-device badge icin; baska bir cihazdan yapilan upload'lari
  /// tespit etmek icin yerel "last seen" markeriyle karsilastirilir.
  Future<DateTime?> fetchLatestRemoteCreatedAt();
}
