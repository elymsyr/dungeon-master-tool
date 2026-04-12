import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/marketplace_listing.dart';

/// `marketplace_listings` tablosu + `shared-payloads` Storage bucket.
///
/// Listing rows are immutable once inserted (DB trigger enforces this); a
/// new "version" is just a new row in the same lineage. The bucket reuses
/// the existing `shared-payloads` bucket from migration 004 — its RLS
/// policies key on the leading folder being the owner's `auth.uid()`,
/// which is satisfied by our path layout `{owner_id}/listings/{listing_id}.json.gz`.
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

  /// Publish a fresh immutable snapshot. If [lineageId] is provided the new
  /// listing joins that lineage and supersedes its previous current snapshot.
  /// If null, a brand-new lineage UUID is generated server-side and returned
  /// in the resulting [MarketplaceListing.lineageId].
  ///
  /// The caller is expected to have computed [contentHash] over [payload]
  /// using [computePayloadContentHash] and short-circuit when the hash
  /// matches the lineage's current snapshot (no-op publish).
  Future<MarketplaceListing> publishSnapshot({
    String? lineageId,
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
        'p_lineage_id': lineageId,
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

    // RPC returns only ids; fetch the freshly inserted row to get the full
    // model (created_at, lineage_id, etc).
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

  /// Owner deletes a snapshot. Removes the DB row (RPC promotes the next
  /// older snapshot to current if needed) and the Storage blob.
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

  /// Lightweight drift check: returns the *current* snapshot for each given
  /// lineage id. Lineages with no surviving rows (owner deleted all of
  /// them) are simply absent from the result map — the caller treats those
  /// as "removed".
  ///
  /// Map key is the lineage id.
  Future<Map<String, MarketplaceListing>> currentVersionsForLineages(
    List<String> lineageIds,
  ) async {
    if (lineageIds.isEmpty) return const {};
    final rows = await _client.rpc(
      'lineage_current_versions',
      params: {'p_lineage_ids': lineageIds},
    ) as List<dynamic>;
    final result = <String, MarketplaceListing>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      // RPC return shape — flatten field names match the table.
      final listing = MarketplaceListing(
        id: row['listing_id'] as String,
        ownerId: row['owner_id'] as String,
        itemType: row['item_type'] as String,
        lineageId: row['lineage_id'] as String,
        isCurrent: true,
        title: row['title'] as String,
        description: row['description'] as String?,
        language: row['language'] as String?,
        tags: _readTags(row['tags']),
        changelog: row['changelog'] as String?,
        contentHash: row['content_hash'] as String,
        payloadPath: row['payload_path'] as String,
        sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
      result[listing.lineageId] = listing;
    }
    return result;
  }

  /// Marketplace browse: all `is_current=true` listings, with optional
  /// filters and a join on `profiles.username` for the author column.
  Future<List<MarketplaceListing>> listAllCurrent({
    String? itemType,
    String? language,
    String? tag,
    int limit = 100,
  }) async {
    var query = _client
        .from(_table)
        .select('*, profiles!marketplace_listings_owner_id_fkey(username)')
        .eq('is_current', true);
    if (itemType != null) query = query.eq('item_type', itemType);
    if (language != null && language.isNotEmpty) query = query.eq('language', language);
    if (tag != null && tag.isNotEmpty) query = query.contains('tags', [tag]);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(_rowToListing).toList();
  }

  /// Owner view: all snapshots in a single lineage, ordered newest first.
  /// Powers the "My snapshots" panel.
  Future<List<MarketplaceListing>> listLineageHistory(String lineageId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('lineage_id', lineageId)
        .order('created_at', ascending: false);
    return rows.map(_rowToListing).toList();
  }

  /// All current listings owned by [ownerId] (profile screen).
  Future<List<MarketplaceListing>> listCurrentByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .eq('is_current', true)
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
      lineageId: row['lineage_id'] as String,
      isCurrent: (row['is_current'] as bool?) ?? true,
      supersededBy: row['superseded_by'] as String?,
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
