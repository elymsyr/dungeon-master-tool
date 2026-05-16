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
  /// [payloadHash]: opsiyonel; SyncEngine ayni icerigi tekrar
  /// yuklememek icin kullanir. Repo bunu storage'a degil cloud_backups
  /// satirinin `payload_hash` kolonuna yazar.
  Future<CloudBackupMeta> uploadBackup(
    String itemName,
    String itemId,
    String type,
    Map<String, dynamic> data, {
    String? notes,
    String? payloadHash,
  });

  /// Item icin cloud'daki son payload_hash. Yoksa null.
  Future<String?> fetchPayloadHashByItem(String itemId, String type);

  /// Cloud backup'i indir ve veri olarak don.
  Future<Map<String, dynamic>> downloadBackup(String backupId);

  /// Cloud backup'i sil (Storage + metadata).
  Future<void> deleteBackup(String backupId);

  /// Item ID + type kombinasyonuna gore cloud backup'i sil.
  /// Backup yoksa no-op doner.
  Future<void> deleteBackupByItem(String itemId, String type);

  /// Storage'da karsiligi olmayan orphan meta row'unu sil. Catch-up
  /// donguleri 404 alinca tablonun bu satirini kaldirmak icin kullanir.
  Future<void> deleteOrphanedMeta(String backupId);

  /// Item ID + type kombinasyonuna gore tek backup metadata'sini getir.
  /// Yoksa null doner.
  Future<CloudBackupMeta?> fetchByItem(String itemId, String type);

  /// Kullanicinin toplam cloud storage kullanimini getir (bytes).
  Future<int> getTotalStorageUsed();

  /// Kullanicinin en yeni backup'inin `created_at` degeri (herhangi bir
  /// tipte). Multi-device badge icin; baska bir cihazdan yapilan upload'lari
  /// tespit etmek icin yerel "last seen" markeriyle karsilastirilir.
  Future<DateTime?> fetchLatestRemoteCreatedAt();
}
