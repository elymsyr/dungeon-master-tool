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

/// Thrown when the user re-publishes a snapshot whose content hash matches
/// the lineage's existing current snapshot. UI surfaces this as a benign
/// "no changes since last snapshot" notice instead of an error.
class NoChangesSinceLastSnapshotException implements Exception {
  const NoChangesSinceLastSnapshotException();
  @override
  String toString() => 'NoChangesSinceLastSnapshotException';
}

/// Owner-side: history of all snapshots in a single lineage. Powers the
/// "My snapshots" panel inside an item's settings.
final lineageHistoryProvider =
    FutureProvider.family<List<MarketplaceListing>, String>(
        (ref, lineageId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  if (ref.watch(authProvider) == null) return const [];
  return ref
      .read(marketplaceListingsRemoteDsProvider)
      .listLineageHistory(lineageId);
});

/// Owner-side: convenience family that resolves a local item's currently
/// associated lineage id (if any). Returns null when the item has never
/// been published.
final ownerLineageIdProvider =
    FutureProvider.family<String?, ({String itemType, String localId})>(
        (ref, key) async {
  return ref
      .read(marketplaceLinksLocalDsProvider)
      .getOwnerLineageId(key.itemType, key.localId);
});

/// Reader-side: the marketplace_source metadata of a downloaded local copy,
/// if any. Used by settings panels to render the "imported from marketplace"
/// badge and the drift banner.
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

  /// Publish a fresh immutable snapshot of [localId]. If the item has been
  /// published before, the new snapshot joins the same lineage and
  /// supersedes the previous current. Pass [freshLineage]: true to start a
  /// brand new independent listing instead.
  ///
  /// Throws [NoChangesSinceLastSnapshotException] when the local content
  /// hash matches the lineage's current snapshot — UI surfaces this as a
  /// benign info, not an error.
  Future<MarketplaceListing?> publishSnapshot({
    required String itemType,
    required String localId,
    required String title,
    String? description,
    String? language,
    List<String> tags = const [],
    String? changelog,
    bool freshLineage = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final payload = await _loadPayload(itemType, localId);
      final hash = computePayloadContentHash(payload);

      final store = _ref.read(marketplaceLinksLocalDsProvider);
      String? lineageId;
      if (!freshLineage) {
        lineageId = await store.getOwnerLineageId(itemType, localId);
      }

      final remote = _ref.read(marketplaceListingsRemoteDsProvider);

      // No-op detection: same content as the lineage's current snapshot.
      if (lineageId != null) {
        final current = await remote.currentVersionsForLineages([lineageId]);
        if (current[lineageId]?.contentHash == hash) {
          state = const AsyncValue.data(null);
          throw const NoChangesSinceLastSnapshotException();
        }
      }

      final listing = await remote.publishSnapshot(
        lineageId: lineageId,
        itemType: itemType,
        title: title,
        description: description,
        language: language,
        tags: tags,
        changelog: changelog,
        contentHash: hash,
        payload: payload,
      );

      // Persist the lineage id locally so subsequent publishes reuse it.
      await store.setOwnerLineageId(
        itemType: itemType,
        localId: localId,
        lineageId: listing.lineageId,
      );
      _ref.invalidate(ownerLineageIdProvider((itemType: itemType, localId: localId)));
      _ref.invalidate(lineageHistoryProvider(listing.lineageId));

      state = const AsyncValue.data(null);
      return listing;
    } on NoChangesSinceLastSnapshotException {
      state = const AsyncValue.data(null);
      rethrow;
    } catch (e, st) {
      debugPrint('publishSnapshot error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Owner deletes a single snapshot. The DB RPC promotes the next-newest
  /// snapshot in the lineage to current automatically; this method also
  /// invalidates the relevant providers.
  Future<void> deleteListing(MarketplaceListing listing) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketplaceListingsRemoteDsProvider).deleteListing(
            listingId: listing.id,
            payloadPath: listing.payloadPath,
          );
      _ref.invalidate(lineageHistoryProvider(listing.lineageId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint('deleteListing error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reader: download a listing as a brand new local item. Existing local
  /// copies (if any) are untouched. Returns the new local id (campaign
  /// name / template schemaId / package name).
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
              lineageId: listing.lineageId,
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

  /// Reader: replace an existing local copy with the listing's payload.
  /// Destructive — caller must have shown a confirmation dialog. Updates
  /// the marketplace_source metadata so the drift banner clears.
  Future<void> replaceLocalCopy({
    required String itemType,
    required String localId,
    required MarketplaceListing listing,
  }) async {
    state = const AsyncValue.loading();
    try {
      final remote = _ref.read(marketplaceListingsRemoteDsProvider);
      final payload = await remote.downloadPayload(
        listingId: listing.id,
        payloadPath: listing.payloadPath,
      );
      await _saveBackPayload(itemType, localId, payload);

      await _ref.read(marketplaceLinksLocalDsProvider).setSource(
            itemType: itemType,
            localId: localId,
            source: MarketplaceSource(
              listingId: listing.id,
              lineageId: listing.lineageId,
              syncedHash: listing.contentHash,
              syncedAt: DateTime.now().toUtc(),
              ownerUsername: listing.ownerUsername,
            ),
          );
      _ref.invalidate(marketplaceSourceProvider(
        (itemType: itemType, localId: localId),
      ));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint('replaceLocalCopy error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reader: dismiss a specific listing version (silences the drift banner
  /// until a *newer* snapshot in the same lineage is published).
  Future<void> dismissListingVersion({
    required String itemType,
    required String localId,
    required String dismissedListingId,
  }) async {
    final store = _ref.read(marketplaceLinksLocalDsProvider);
    final source = await store.getSource(itemType, localId);
    if (source == null) return;
    await store.setSource(
      itemType: itemType,
      localId: localId,
      source: source.copyWith(dismissedListingId: dismissedListingId),
    );
    _ref.invalidate(marketplaceSourceProvider((itemType: itemType, localId: localId)));
  }

  /// Reader: mute (or unmute) all future drift notifications for this item.
  Future<void> setMuted({
    required String itemType,
    required String localId,
    required bool muted,
  }) async {
    final store = _ref.read(marketplaceLinksLocalDsProvider);
    final source = await store.getSource(itemType, localId);
    if (source == null) return;
    await store.setSource(
      itemType: itemType,
      localId: localId,
      source: source.copyWith(muted: muted),
    );
    _ref.invalidate(marketplaceSourceProvider((itemType: itemType, localId: localId)));
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

  Future<void> _saveBackPayload(
    String itemType,
    String localId,
    Map<String, dynamic> payload,
  ) async {
    switch (itemType) {
      case 'world':
        await _ref.read(campaignRepositoryProvider).save(localId, payload);
        return;
      case 'package':
        await _ref.read(packageRepositoryProvider).save(localId, payload);
        return;
      case 'template':
        final raw = payload['world_schema'];
        if (raw is! Map<String, dynamic>) {
          throw StateError('Invalid template payload: world_schema missing');
        }
        // Force the incoming schema's id to match localId so the existing
        // file on disk is overwritten rather than producing a duplicate.
        final overriden = Map<String, dynamic>.from(raw)..['schemaId'] = localId;
        final schema = WorldSchema.fromJson(overriden);
        await _ref.read(templateLocalDsProvider).save(schema);
        return;
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
