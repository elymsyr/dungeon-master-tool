import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/local/marketplace_links_local_ds.dart';
import '../../data/datasources/remote/marketplace_listings_remote_ds.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_source.dart';
import '../../domain/entities/payload_hash.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
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
  return ref
      .read(marketplaceListingsRemoteDsProvider)
      .listCurrentByOwner(userId);
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
