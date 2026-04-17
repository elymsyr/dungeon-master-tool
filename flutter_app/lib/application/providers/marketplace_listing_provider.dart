import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/cached_provider.dart';
import '../../core/utils/id_gen.dart';
import '../../data/datasources/local/marketplace_links_local_ds.dart';
import '../../data/datasources/remote/marketplace_listings_remote_ds.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_source.dart';
import '../../domain/entities/payload_hash.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'character_provider.dart';
import 'package_provider.dart';
import 'template_provider.dart';

final marketplaceListingsRemoteDsProvider =
    Provider<MarketplaceListingsRemoteDataSource>(
        (_) => MarketplaceListingsRemoteDataSource());

final marketplaceLinksLocalDsProvider =
    Provider<MarketplaceLinksLocalDataSource>(
        (_) => MarketplaceLinksLocalDataSource());

/// Owner-side: all listings the user has published from this local item,
/// newest first. Populates the "My Snapshots" panel.
final ownedSnapshotsProvider = FutureProvider.family<List<MarketplaceListing>,
    ({String itemType, String localId})>((ref, key) async {
  if (!SupabaseConfig.isConfigured) return const [];
  if (ref.watch(authProvider) == null) return const [];
  final store = ref.read(marketplaceLinksLocalDsProvider);
  final ids = await store.getOwnedListingIds(key.itemType, key.localId);
  if (ids.isEmpty) return const [];
  // Stored oldest-first; UI wants newest-first.
  final reversed = ids.reversed.toList();
  return ref
      .read(marketplaceListingsRemoteDsProvider)
      .fetchListingsByIds(reversed);
});

/// Current marketplace listings owned by [userId]. Used by the profile
/// screen's "Items" tab — anyone can view a user's public listings, the
/// owner additionally sees delete controls.
final userMarketplaceListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>(
        (ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'userListings:$userId',
    ttl: const Duration(minutes: 5),
    fetch: () => ref
        .read(marketplaceListingsRemoteDsProvider)
        .listCurrentByOwner(userId),
  );
});

/// Reader-side: the marketplace_source metadata of a downloaded local copy,
/// if any. Used by settings panels to render the "imported from marketplace"
/// badge.
final marketplaceSourceProvider =
    FutureProvider.family<MarketplaceSource?, ({String itemType, String localId})>(
        (ref, key) async {
  return ref
      .read(marketplaceLinksLocalDsProvider)
      .getSource(key.itemType, key.localId);
});

class MarketplaceListingNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  MarketplaceListingNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Publish a fresh immutable snapshot of [localId]. Each publish is a
  /// standalone listing; the id is appended to the local "owned listings"
  /// index so the owner can find it later in the "My Snapshots" panel.
  Future<MarketplaceListing?> publishSnapshot({
    required String itemType,
    required String localId,
    required String title,
    String? description,
    String? language,
    List<String> tags = const [],
    String? changelog,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = await _loadPayload(itemType, localId);
      final hash = computePayloadContentHash(payload);
      final coverB64 = await _readLocalCoverBase64(itemType, localId);

      final remote = _ref.read(marketplaceListingsRemoteDsProvider);
      final listing = await remote.publishSnapshot(
        itemType: itemType,
        title: title,
        description: description,
        language: language,
        tags: tags,
        changelog: changelog,
        contentHash: hash,
        payload: payload,
        coverImageB64: coverB64,
      );

      await _ref.read(marketplaceLinksLocalDsProvider).addOwnedListingId(
            itemType: itemType,
            localId: localId,
            listingId: listing.id,
          );
      _ref.invalidate(
        ownedSnapshotsProvider((itemType: itemType, localId: localId)),
      );

      state = const AsyncValue.data(null);
      return listing;
    } catch (e, st) {
      debugPrint('publishSnapshot error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Owner deletes a single listing. Removes the DB row and the storage
  /// blob. When [itemType]/[localId] are provided, the local owned-ids
  /// entry is also cleaned up and the corresponding provider is invalidated;
  /// callers that delete from a context without that link (profile screen)
  /// can omit them.
  Future<void> deleteListing({
    required MarketplaceListing listing,
    String? itemType,
    String? localId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketplaceListingsRemoteDsProvider).deleteListing(
            listingId: listing.id,
            payloadPath: listing.payloadPath,
          );
      if (itemType != null && localId != null) {
        await _ref.read(marketplaceLinksLocalDsProvider).removeOwnedListingId(
              itemType: itemType,
              localId: localId,
              listingId: listing.id,
            );
        _ref.invalidate(
          ownedSnapshotsProvider((itemType: itemType, localId: localId)),
        );
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint('deleteListing error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reader: download a listing as a brand new local item. Returns the new
  /// local id (campaign name / template schemaId / package name).
  Future<String> downloadAsNewCopy(MarketplaceListing listing) async {
    state = const AsyncValue.loading();
    try {
      final remote = _ref.read(marketplaceListingsRemoteDsProvider);
      final payload = await remote.downloadPayload(
        listingId: listing.id,
        payloadPath: listing.payloadPath,
      );
      final newLocalId = await _importPayload(
        listing.itemType,
        listing.title,
        payload,
      );

      await _ref.read(marketplaceLinksLocalDsProvider).setSource(
            itemType: listing.itemType,
            localId: newLocalId,
            source: MarketplaceSource(
              listingId: listing.id,
              syncedHash: listing.contentHash,
              syncedAt: DateTime.now().toUtc(),
              ownerUsername: listing.ownerUsername,
            ),
          );
      _ref.invalidate(marketplaceSourceProvider(
        (itemType: listing.itemType, localId: newLocalId),
      ));
      switch (listing.itemType) {
        case 'world':
          _ref.invalidate(campaignInfoListProvider);
        case 'template':
          _ref.invalidate(customTemplatesProvider);
          _ref.invalidate(allTemplatesProvider);
        case 'package':
          _ref.invalidate(packageListProvider);
        case 'character':
          _ref.invalidate(characterListProvider);
      }

      state = const AsyncValue.data(null);
      return newLocalId;
    } catch (e, st) {
      debugPrint('downloadAsNewCopy error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ── Payload (de)serialization helpers ─────────────────────────────────

  /// Resolves the local cover/banner image path for a publishable item,
  /// downsizes it to a marketplace-card thumbnail (~640 px wide), re-encodes
  /// as PNG and returns base64. Returns null when the item has no cover,
  /// the file is missing, or decoding fails.
  Future<String?> _readLocalCoverBase64(
    String itemType,
    String localId,
  ) async {
    final path = await _resolveCoverPath(itemType, localId);
    if (path == null || path.isEmpty) {
      debugPrint('marketplace cover: $itemType/$localId — no local path');
      return null;
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('marketplace cover: file missing at $path');
        return null;
      }
      final rawBytes = await file.readAsBytes();
      if (rawBytes.lengthInBytes > _coverRawMaxBytes) {
        debugPrint('marketplace cover: raw too large (${rawBytes.lengthInBytes} B)');
        return null;
      }
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: _coverTargetWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (byteData == null) return null;
      final thumb = byteData.buffer.asUint8List();
      if (thumb.lengthInBytes > _coverEncodedMaxBytes) {
        debugPrint(
            'marketplace cover: encoded too large (${thumb.lengthInBytes} B, cap $_coverEncodedMaxBytes)');
        return null;
      }
      return base64Encode(thumb);
    } catch (e) {
      debugPrint('cover read/resize failed: $e');
      return null;
    }
  }

  Future<String?> _resolveCoverPath(String itemType, String localId) async {
    switch (itemType) {
      case 'world':
        final data = await _ref.read(campaignRepositoryProvider).load(localId);
        return _coverFromCampaignData(data);
      case 'template':
        final tpl = await _ref.read(templateLocalDsProvider).loadById(localId);
        return tpl?.metadata['cover_image_path'] as String?;
      case 'package':
        final data = await _ref.read(packageRepositoryProvider).load(localId);
        return _coverFromCampaignData(data);
      case 'character':
        final list = await _ref.read(characterRepositoryProvider).loadAll();
        final c = list.where((x) => x.id == localId).firstOrNull;
        return c?.entity.imagePath;
    }
    return null;
  }

  /// Campaign/package payload'larında cover path farklı kanonlarla
  /// saklanabiliyor: top-level `metadata` (settings dialog yazımı),
  /// ya da `world_schema.metadata` (`_saveToDb` kanonu). Hangisinde
  /// dolu değer varsa onu döndür.
  String? _coverFromCampaignData(Map<String, dynamic> data) {
    final topMeta = data['metadata'];
    if (topMeta is Map) {
      final p = topMeta['cover_image_path'];
      if (p is String && p.isNotEmpty) return p;
    }
    final schema = data['world_schema'];
    if (schema is Map) {
      final schemaMeta = schema['metadata'];
      if (schemaMeta is Map) {
        final p = schemaMeta['cover_image_path'];
        if (p is String && p.isNotEmpty) return p;
      }
    }
    return null;
  }

  static const int _coverRawMaxBytes = 20 * 1024 * 1024;
  static const int _coverEncodedMaxBytes = 2 * 1024 * 1024;
  static const int _coverTargetWidth = 480;

  Future<Map<String, dynamic>> _loadPayload(
    String itemType,
    String localId,
  ) async {
    switch (itemType) {
      case 'world':
        return _ref.read(campaignRepositoryProvider).load(localId);
      case 'template':
        final tpl = await _ref.read(templateLocalDsProvider).loadById(localId);
        if (tpl == null) throw StateError('Template not found: $localId');
        return {'world_schema': tpl.toJson()};
      case 'package':
        return _ref.read(packageRepositoryProvider).load(localId);
      case 'character':
        final list = await _ref.read(characterRepositoryProvider).loadAll();
        final c = list.where((x) => x.id == localId).firstOrNull;
        if (c == null) throw StateError('Character not found: $localId');
        return {'character': c.toJson()};
    }
    throw ArgumentError('Unknown itemType: $itemType');
  }

  /// Imports a downloaded payload as a *new* local item. Returns the local
  /// id under which it was saved (campaign name / template schemaId /
  /// package name). Conflicting names get a " (imported)" suffix.
  Future<String> _importPayload(
    String itemType,
    String title,
    Map<String, dynamic> payload,
  ) async {
    switch (itemType) {
      case 'world':
        final name = await _uniqueCampaignName(title);
        await _ref.read(campaignRepositoryProvider).save(name, payload);
        return name;
      case 'package':
        final name = await _uniquePackageName(title);
        await _ref.read(packageRepositoryProvider).save(name, payload);
        return name;
      case 'template':
        final raw = payload['world_schema'];
        if (raw is! Map<String, dynamic>) {
          throw StateError('Invalid template payload: world_schema missing');
        }
        final schema = WorldSchema.fromJson(raw);
        await _ref.read(templateLocalDsProvider).save(schema);
        return schema.schemaId;
      case 'character':
        final raw = payload['character'];
        if (raw is! Map<String, dynamic>) {
          throw StateError('Invalid character payload: character missing');
        }
        final imported = Character.fromJson(raw);
        final now = DateTime.now().toUtc().toIso8601String();
        final fresh = imported.copyWith(
          id: newId(),
          worldName: '',
          entity: imported.entity.copyWith(id: newId()),
          createdAt: now,
          updatedAt: now,
        );
        await _ref.read(characterRepositoryProvider).save(fresh);
        await _ref.read(characterListProvider.notifier).refresh();
        return fresh.id;
    }
    throw ArgumentError('Unknown itemType: $itemType');
  }

  Future<String> _uniqueCampaignName(String desired) async {
    final repo = _ref.read(campaignRepositoryProvider);
    final existing = await repo.getAvailable();
    return _suffixIfTaken(desired, existing.toSet());
  }

  Future<String> _uniquePackageName(String desired) async {
    final repo = _ref.read(packageRepositoryProvider);
    final existing = await repo.getAvailable();
    return _suffixIfTaken(desired, existing.toSet());
  }

  String _suffixIfTaken(String desired, Set<String> taken) {
    if (!taken.contains(desired)) return desired;
    var n = 1;
    while (taken.contains('$desired (imported${n == 1 ? '' : ' $n'})')) {
      n++;
    }
    return '$desired (imported${n == 1 ? '' : ' $n'})';
  }
}

final marketplaceListingNotifierProvider =
    StateNotifierProvider<MarketplaceListingNotifier, AsyncValue<void>>(
  (ref) => MarketplaceListingNotifier(ref),
);
