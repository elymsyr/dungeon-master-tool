import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/cloud_backup_meta.dart';
import '../../domain/exceptions/cloud_backup_exceptions.dart';
import '../../domain/repositories/cloud_backup_repository.dart';
import '../datasources/remote/cloud_backup_remote_ds.dart';

/// Per-item JSON boyut limiti (compression oncesi).
const cloudBackupItemSizeLimit = 5 * 1024 * 1024; // 5 MB

/// Per-user toplam cloud storage limiti (compressed).
const cloudBackupUserQuotaLimit = 20 * 1024 * 1024; // 20 MB

/// Cloud backup repository implementasyonu.
///
/// Veriyi JSON encode + gzip compress ederek Supabase Storage'a yukler;
/// metadata'yi Postgres `cloud_backups` tablosunda tutar.
/// Worlds, templates ve packages icin ortak kullanilir.
class CloudBackupRepositoryImpl implements CloudBackupRepository {
  final CloudBackupRemoteDataSource _remoteDs;

  CloudBackupRepositoryImpl(this._remoteDs);

  @override
  Future<List<CloudBackupMeta>> listBackups() => _remoteDs.fetchAll();

  @override
  Future<List<CloudBackupMeta>> listBackupsByType(String type) =>
      _remoteDs.fetchAllByType(type);

  @override
  Future<int> getTotalStorageUsed() => _remoteDs.getTotalStorageUsed();

  @override
  Future<CloudBackupMeta> uploadBackup(
    String itemName,
    String itemId,
    String type,
    Map<String, dynamic> data, {
    String? notes,
  }) async {
    // Backup envelope: versiyonlu wrapper
    final envelope = {
      'version': 1,
      'type': type,
      'schema_version': 5,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    // JSON encode
    final jsonBytes = utf8.encode(jsonEncode(envelope));

    // Per-item boyut limiti (pre-compression)
    if (jsonBytes.length > cloudBackupItemSizeLimit) {
      throw CloudBackupSizeLimitException(
        itemName: itemName,
        itemType: type,
        actualBytes: jsonBytes.length,
        limitBytes: cloudBackupItemSizeLimit,
      );
    }

    // Gzip compress
    final gzipBytes = gzip.encode(jsonBytes);
    final compressedBytes = Uint8List.fromList(gzipBytes);

    // Per-user toplam limit kontrolu
    final currentUsage = await _remoteDs.getTotalStorageUsed();
    if (currentUsage + compressedBytes.length > cloudBackupUserQuotaLimit) {
      throw CloudBackupQuotaExceededException(
        itemName: itemName,
        currentUsageBytes: currentUsage,
        quotaBytes: cloudBackupUserQuotaLimit,
      );
    }

    // Entity sayisini hesapla (sadece world ve package icin)
    final entityCount = switch (type) {
      'world' || 'package' =>
        (data['entities'] as Map<String, dynamic>?)?.length ?? 0,
      _ => 0,
    };

    return _remoteDs.upload(
      itemName: itemName,
      itemId: itemId,
      type: type,
      gzipBytes: compressedBytes,
      entityCount: entityCount,
      schemaVersion: 5,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> downloadBackup(String backupId) async {
    final meta = await _remoteDs.fetchById(backupId);
    if (meta == null) {
      throw StateError('Backup not found: $backupId');
    }

    final gzipBytes = await _remoteDs.download(meta.storagePath);
    final jsonBytes = gzip.decode(gzipBytes);
    final jsonStr = utf8.decode(jsonBytes);
    final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

    // Envelope'dan veriyi cikar (v1 format: 'data' veya 'campaign_data')
    final data = (envelope['data'] ?? envelope['campaign_data'])
        as Map<String, dynamic>?;
    if (data == null) {
      throw const FormatException('Invalid backup format: missing data');
    }

    return data;
  }

  @override
  Future<void> deleteBackup(String backupId) async {
    final meta = await _remoteDs.fetchById(backupId);
    if (meta == null) return;
    await _remoteDs.delete(backupId, meta.storagePath);
  }

  @override
  Future<void> deleteBackupByItem(String itemId, String type) async {
    final meta = await _remoteDs.fetchByItem(itemId, type);
    if (meta == null) return;
    await _remoteDs.delete(meta.id, meta.storagePath);
  }
}
