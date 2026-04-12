import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/shared_item.dart';

/// `shared_items` tablosu + `shared-payloads` Storage bucket. Public yapılan
/// world/template/package'lar burada tutulur. Local Drift modellerine
/// `isPublic` kolonu eklemiyoruz; bu tablo tek source of truth.
class SharedItemsRemoteDataSource {
  static const _table = 'shared_items';
  static const _bucket = 'shared-payloads';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Kullanıcının bir item'ını public yapar; payload Storage'a yüklenir.
  /// `payload` json-encodable bir map; gzip'lenip yüklenir. [language] ve
  /// [tags] marketplace filtreleri için opsiyoneldir ama description'ı
  /// doldurmak şiddetle önerilir.
  Future<SharedItem> publish({
    required String itemType,
    required String localId,
    required String title,
    String? description,
    String? language,
    List<String> tags = const [],
    required Map<String, dynamic> payload,
  }) async {
    final uid = _userId;
    final jsonStr = jsonEncode(payload);
    final gz = Uint8List.fromList(gzip.encode(utf8.encode(jsonStr)));
    final path = '$uid/$itemType/$localId.json.gz';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          gz,
          fileOptions: const FileOptions(contentType: 'application/gzip', upsert: true),
        );

    final row = {
      'owner_id': uid,
      'item_type': itemType,
      'local_id': localId,
      'title': title,
      'description': description,
      'language': language,
      'tags': tags,
      'is_public': true,
      'payload_path': path,
      'size_bytes': gz.length,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final inserted = await _client
        .from(_table)
        .upsert(row, onConflict: 'owner_id,item_type,local_id')
        .select()
        .single();
    return _rowToShared(inserted);
  }

  /// Marketplace'ten indirilen item için payload'ı indir, gzip çöz, JSON
  /// map'i döner. Ayrıca `increment_shared_item_downloads` RPC'si ile
  /// download_count atomik olarak 1 artırılır.
  Future<Map<String, dynamic>> download({
    required String itemId,
    required String payloadPath,
  }) async {
    final bytes = await _client.storage.from(_bucket).download(payloadPath);
    final jsonStr = utf8.decode(gzip.decode(bytes));
    final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
    try {
      await _client.rpc('increment_shared_item_downloads', params: {'p_item_id': itemId});
    } catch (e) {
      debugPrint('download_count increment failed: $e');
    }
    return payload;
  }

  /// Item'ı private yap: DB row'u sil + Storage objesini sil.
  Future<void> unpublish({
    required String itemType,
    required String localId,
  }) async {
    final uid = _userId;
    final existing = await _client
        .from(_table)
        .select('payload_path')
        .eq('owner_id', uid)
        .eq('item_type', itemType)
        .eq('local_id', localId)
        .maybeSingle();
    if (existing != null && existing['payload_path'] != null) {
      try {
        await _client.storage.from(_bucket).remove([existing['payload_path'] as String]);
      } catch (e) {
        debugPrint('Shared payload delete failed: $e');
      }
    }
    await _client
        .from(_table)
        .delete()
        .eq('owner_id', uid)
        .eq('item_type', itemType)
        .eq('local_id', localId);
  }

  /// Bu item public mi?
  Future<SharedItem?> fetch({
    required String itemType,
    required String localId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from(_table)
        .select()
        .eq('owner_id', uid)
        .eq('item_type', itemType)
        .eq('local_id', localId)
        .maybeSingle();
    if (row == null) return null;
    return _rowToShared(row);
  }

  /// Bir kullanıcının tüm public item'ları (profile screen).
  Future<List<SharedItem>> listPublicByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .eq('is_public', true)
        .order('updated_at', ascending: false);
    return rows.map(_rowToShared).toList();
  }

  /// Marketplace için tüm public item'lar + owner username'leri.
  /// [itemType] = 'all' | 'world' | 'template' | 'package'.
  /// [language] ISO kodu (ör. 'tr') — null ise tüm diller.
  /// [tag] verilirse item.tags[] içinde geçmesi beklenir.
  Future<List<({SharedItem item, String? ownerUsername})>> listAllPublic({
    String? itemType,
    String? language,
    String? tag,
    int limit = 100,
  }) async {
    var query = _client
        .from(_table)
        .select('*, profiles!shared_items_owner_id_fkey(username)')
        .eq('is_public', true);
    if (itemType != null) query = query.eq('item_type', itemType);
    if (language != null && language.isNotEmpty) query = query.eq('language', language);
    if (tag != null && tag.isNotEmpty) query = query.contains('tags', [tag]);
    final rows = await query.order('updated_at', ascending: false).limit(limit);
    return rows.map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return (
        item: _rowToShared(r),
        ownerUsername: profile?['username'] as String?,
      );
    }).toList();
  }

  SharedItem _rowToShared(Map<String, dynamic> row) {
    final tagsRaw = row['tags'];
    return SharedItem(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      itemType: row['item_type'] as String,
      localId: row['local_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      isPublic: (row['is_public'] as bool?) ?? false,
      payloadPath: row['payload_path'] as String?,
      sizeBytes: (row['size_bytes'] as int?) ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse((row['updated_at'] ?? row['created_at']) as String),
      language: row['language'] as String?,
      tags: tagsRaw is List ? tagsRaw.whereType<String>().toList() : const [],
      downloadCount: (row['download_count'] as int?) ?? 0,
    );
  }
}
