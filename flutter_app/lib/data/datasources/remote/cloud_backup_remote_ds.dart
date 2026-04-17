import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/parse_utils.dart';
import '../../../domain/entities/cloud_backup_meta.dart';

const _uuid = Uuid();

/// Supabase Storage + Postgres uzerinden cloud backup CRUD islemleri.
///
/// Storage bucket: `campaign-backups` (private, RLS: `{user_id}/` prefix)
/// Postgres tablo: `cloud_backups` (metadata)
///
/// Storage path format: `{user_id}/{type}s/{item_id}.json.gz`
/// Ornek: `abc123/worlds/xyz.json.gz`, `abc123/templates/t1.json.gz`
class CloudBackupRemoteDataSource {
  static const _bucket = 'campaign-backups';
  static const _table = 'cloud_backups';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Item verisini gzip JSON olarak Storage'a yukle ve metadata row olustur.
  /// Ayni item_id + type icin mevcut backup varsa upsert yapar (gunceller).
  Future<CloudBackupMeta> upload({
    required String itemName,
    required String itemId,
    required String type,
    required Uint8List gzipBytes,
    required int entityCount,
    int schemaVersion = 5,
    String? appVersion,
    String? notes,
  }) async {
    final storagePath = '$_userId/${type}s/$itemId.json.gz';

    // Mevcut backup varsa sil (upsert pattern)
    final existing = await _client
        .from(_table)
        .select('id')
        .eq('user_id', _userId)
        .eq('item_id', itemId)
        .eq('type', type)
        .limit(1);
    if (existing.isNotEmpty) {
      final oldId = existing.first['id'] as String;
      // Storage'daki eski dosyayi sil (yeni ayni path'e yazilacak)
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (e) {
        debugPrint('cloud_backup_remote_ds: old backup storage delete failed for $storagePath: $e');
      }
      await _client.from(_table).delete().eq('id', oldId);
    }

    final backupId = _uuid.v4();

    // Storage'a yukle
    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          gzipBytes,
          fileOptions: const FileOptions(
            contentType: 'application/gzip',
            upsert: true,
          ),
        );

    // Metadata row insert
    final now = DateTime.now().toUtc();
    final row = {
      'id': backupId,
      'user_id': _userId,
      'item_name': itemName,
      'item_id': itemId,
      'type': type,
      'storage_path': storagePath,
      'size_bytes': gzipBytes.length,
      'entity_count': entityCount,
      'schema_version': schemaVersion,
      'app_version': appVersion,
      'created_at': now.toIso8601String(),
      'notes': notes,
    };

    await _client.from(_table).insert(row);

    return CloudBackupMeta(
      id: backupId,
      userId: _userId,
      itemName: itemName,
      itemId: itemId,
      type: type,
      storagePath: storagePath,
      sizeBytes: gzipBytes.length,
      entityCount: entityCount,
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      createdAt: now,
      notes: notes,
    );
  }

  /// Storage'dan gzip bytes indir.
  Future<Uint8List> download(String storagePath) async {
    return await _client.storage.from(_bucket).download(storagePath);
  }

  /// Kullanicinin tum backup metadata'larini getir (en yeniden eskiye).
  Future<List<CloudBackupMeta>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return rows.map(_rowToMeta).toList();
  }

  /// Belirli tip icin backup metadata'larini getir.
  Future<List<CloudBackupMeta>> fetchAllByType(String type) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('type', type)
        .order('created_at', ascending: false);

    return rows.map(_rowToMeta).toList();
  }

  /// Item ID + type kombinasyonuna gore backup metadata'sini getir.
  /// Upsert pattern ile ayni item_id+type icin tek backup olur.
  Future<CloudBackupMeta?> fetchByItem(String itemId, String type) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('item_id', itemId)
        .eq('type', type)
        .limit(1);

    if (rows.isEmpty) return null;
    return _rowToMeta(rows.first);
  }

  /// Tek bir backup metadata'sini getir.
  Future<CloudBackupMeta?> fetchById(String backupId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('id', backupId)
        .eq('user_id', _userId)
        .limit(1);

    if (rows.isEmpty) return null;
    return _rowToMeta(rows.first);
  }

  /// The `created_at` of the user's newest backup (any type). Used by the
  /// multi-device badge — when this is newer than the locally remembered
  /// "last seen" timestamp, it means another device uploaded while we were
  /// away and we should surface a "pull changes" hint.
  Future<DateTime?> fetchLatestCreatedAt() async {
    final rows = await _client
        .from(_table)
        .select('created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final raw = rows.first['created_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  /// Kullanicinin toplam cloud kullanimini getir (bytes).
  /// cloud_backups + community_assets (R2) toplami — get_user_total_storage_used
  /// RPC'si araciligiyla atomic SUM yapar.
  Future<int> getTotalStorageUsed() async {
    final result = await _client.rpc(
      'get_user_total_storage_used',
      params: {'p_user_id': _userId},
    );
    if (result == null) return 0;
    if (result is num) return result.toInt();
    return int.tryParse(result.toString()) ?? 0;
  }

  /// Storage dosyasini ve metadata row'unu sil.
  Future<void> delete(String backupId, String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
    await _client.from(_table).delete().eq('id', backupId);
  }

  CloudBackupMeta _rowToMeta(Map<String, dynamic> row) {
    return CloudBackupMeta(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      itemName: (row['item_name'] ?? row['campaign_name'] ?? '') as String,
      itemId: (row['item_id'] ?? row['campaign_id'] ?? '') as String,
      type: (row['type'] ?? 'world') as String,
      storagePath: row['storage_path'] as String,
      sizeBytes: row['size_bytes'] as int,
      entityCount: row['entity_count'] as int? ?? 0,
      schemaVersion: row['schema_version'] as int? ?? 5,
      appVersion: row['app_version'] as String?,
      createdAt: parseIsoOrNow(row['created_at']),
      notes: row['notes'] as String?,
    );
  }
}
