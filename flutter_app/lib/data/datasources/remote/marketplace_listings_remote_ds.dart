import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/marketplace_listing.dart';

/// `marketplace_listings` tablosu + `shared-payloads` Storage bucket.
///
/// Each publish is an independent immutable row — no lineage / supersede
/// relationship. The bucket reuses the existing `shared-payloads` bucket
/// from migration 004 — its RLS policies key on the leading folder being
/// the owner's `auth.uid()`, which is satisfied by our path layout
/// `{owner_id}/listings/{listing_id}.json.gz`.
class MarketplaceListingsRemoteDataSource {
  static const _table = 'marketplace_listings';
  static const _bucket = 'shared-payloads';
  static const _uuid = Uuid();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Publish a fresh immutable snapshot. Each call produces a standalone
  /// listing; the caller has no obligation to deduplicate against prior
  /// publishes.
  Future<MarketplaceListing> publishSnapshot({
    required String itemType,
    required String title,
    String? description,
    String? language,
    List<String> tags = const [],
    String? changelog,
    required String contentHash,
    required Map<String, dynamic> payload,
  }) async {
    final uid = _userId;
    final listingId = _uuid.v4();
    final path = '$uid/listings/$listingId.json.gz';

    final jsonStr = jsonEncode(payload);
    final gz = Uint8List.fromList(gzip.encode(utf8.encode(jsonStr)));

    await _client.storage.from(_bucket).uploadBinary(
          path,
          gz,
          fileOptions: const FileOptions(
            contentType: 'application/gzip',
            upsert: true,
          ),
        );

    try {
      await _client.rpc('publish_listing_snapshot', params: {
        'p_listing_id': listingId,
        'p_item_type': itemType,
        'p_title': title,
        'p_description': description,
        'p_language': language,
        'p_tags': tags,
        'p_changelog': changelog,
        'p_content_hash': contentHash,
        'p_payload_path': path,
        'p_size_bytes': gz.length,
      });
    } catch (e) {
      // Roll back the orphaned blob if the DB insert failed.
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }

    final row = await _client.from(_table).select().eq('id', listingId).single();
    return _rowToListing(row);
  }

  /// Download a listing's gzip payload, decompress and decode JSON. Also
  /// fires `increment_listing_downloads` (best-effort, errors swallowed).
  Future<Map<String, dynamic>> downloadPayload({
    required String listingId,
    required String payloadPath,
  }) async {
    final bytes = await _client.storage.from(_bucket).download(payloadPath);
    final jsonStr = utf8.decode(gzip.decode(bytes));
    final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
    try {
      await _client.rpc('increment_listing_downloads', params: {'p_id': listingId});
    } catch (e) {
      debugPrint('listing download_count increment failed: $e');
    }
    return payload;
  }

  /// Owner deletes a single listing. Removes the DB row and the Storage blob.
  Future<void> deleteListing({
    required String listingId,
    required String payloadPath,
  }) async {
    try {
      await _client.rpc('delete_listing', params: {'p_id': listingId});
    } finally {
      try {
        await _client.storage.from(_bucket).remove([payloadPath]);
      } catch (e) {
        debugPrint('listing payload delete failed: $e');
      }
    }
  }

  /// Marketplace browse: all listings with optional filters and a join on
  /// `profiles.username` for the author column.
  Future<List<MarketplaceListing>> listAllCurrent({
    String? itemType,
    String? language,
    String? tag,
    int limit = 100,
  }) async {
    var query = _client
        .from(_table)
        .select('*, profiles!marketplace_listings_owner_id_fkey(username)');
    if (itemType != null) query = query.eq('item_type', itemType);
    if (language != null && language.isNotEmpty) query = query.eq('language', language);
    if (tag != null && tag.isNotEmpty) query = query.contains('tags', [tag]);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(_rowToListing).toList();
  }

  /// Fetch a set of listings by id. Preserves the input order so the
  /// "My Snapshots" panel can display newest-first from the stored id list.
  Future<List<MarketplaceListing>> fetchListingsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from(_table)
        .select('*, profiles!marketplace_listings_owner_id_fkey(username)')
        .inFilter('id', ids);
    final byId = {
      for (final r in rows.map(_rowToListing)) r.id: r,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// All listings owned by [ownerId] (profile screen).
  Future<List<MarketplaceListing>> listCurrentByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return rows.map(_rowToListing).toList();
  }

  /// Single listing fetch (preview dialog open from a deep link, etc).
  Future<MarketplaceListing?> fetchListing(String listingId) async {
    final row = await _client
        .from(_table)
        .select('*, profiles!marketplace_listings_owner_id_fkey(username)')
        .eq('id', listingId)
        .maybeSingle();
    if (row == null) return null;
    return _rowToListing(row);
  }

  MarketplaceListing _rowToListing(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return MarketplaceListing(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      itemType: row['item_type'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      language: row['language'] as String?,
      tags: _readTags(row['tags']),
      changelog: row['changelog'] as String?,
      contentHash: row['content_hash'] as String,
      payloadPath: row['payload_path'] as String,
      sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
      downloadCount: (row['download_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      ownerUsername: profile?['username'] as String?,
    );
  }

  List<String> _readTags(Object? raw) {
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }
}
