import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/marketplace_source.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_listing_provider.dart';

/// Surfaced by the drift check when a downloaded local item is out of sync
/// with its source lineage. UI listens to [pendingMarketplaceUpdateProvider]
/// and renders a banner / dialog with the appropriate user actions.
@immutable
class MarketplaceUpdatePrompt {
  final String itemType;
  final String localId;
  final MarketplaceSource source;
  final MarketplaceListing newListing;

  const MarketplaceUpdatePrompt({
    required this.itemType,
    required this.localId,
    required this.source,
    required this.newListing,
  });
}

/// Surfaced when the owner has deleted *every* snapshot in the lineage. UI
/// renders a passive "no longer available" badge and the drift check is
/// permanently disabled for that item via [MarketplaceSource.removed].
@immutable
class MarketplaceRemovedNotice {
  final String itemType;
  final String localId;
  final MarketplaceSource source;
  const MarketplaceRemovedNotice({
    required this.itemType,
    required this.localId,
    required this.source,
  });
}

/// One-of result of a single drift check.
@immutable
class MarketplaceDriftCheckResult {
  final MarketplaceUpdatePrompt? prompt;
  final MarketplaceRemovedNotice? removedNotice;
  const MarketplaceDriftCheckResult({this.prompt, this.removedNotice});
  static const none = MarketplaceDriftCheckResult();

  bool get isEmpty => prompt == null && removedNotice == null;
}

/// Single-slot UI listener for the most recent drift prompt. Mirrors the
/// `pendingTemplateUpdateProvider` pattern from `template_sync_service`.
final pendingMarketplaceUpdateProvider =
    StateProvider<MarketplaceUpdatePrompt?>((ref) => null);

/// Hub badge: count of items currently flagged with an actionable update.
final marketplaceUpdateCountProvider = FutureProvider<int>((ref) async {
  if (!SupabaseConfig.isConfigured) return 0;
  if (ref.watch(authProvider) == null) return 0;
  final service = ref.read(marketplaceSyncServiceProvider);
  final results = await service.checkAll();
  return results.values.where((r) => r.prompt != null).length;
});

class MarketplaceSyncService {
  final Ref _ref;
  MarketplaceSyncService(this._ref);

  /// Single-item drift check. Use this from a settings dialog or right
  /// after loading an item. Returns [MarketplaceDriftCheckResult.none] when
  /// the item has no source link, is muted, or is already in sync.
  Future<MarketplaceDriftCheckResult> checkOne({
    required String itemType,
    required String localId,
  }) async {
    if (!SupabaseConfig.isConfigured) return MarketplaceDriftCheckResult.none;
    if (_ref.read(authProvider) == null) return MarketplaceDriftCheckResult.none;

    final store = _ref.read(marketplaceLinksLocalDsProvider);
    final source = await store.getSource(itemType, localId);
    if (source == null) return MarketplaceDriftCheckResult.none;
    if (source.muted) return MarketplaceDriftCheckResult.none;
    if (source.removed) return MarketplaceDriftCheckResult.none;

    final remote = _ref.read(marketplaceListingsRemoteDsProvider);
    Map<String, MarketplaceListing> currents;
    try {
      currents = await remote.currentVersionsForLineages([source.lineageId]);
    } catch (e) {
      debugPrint('marketplace drift check failed: $e');
      return MarketplaceDriftCheckResult.none;
    }

    final current = currents[source.lineageId];
    if (current == null) {
      // Owner has deleted every snapshot in the lineage. Persist the
      // removed flag so we don't keep hitting the network on every load.
      await store.setSource(
        itemType: itemType,
        localId: localId,
        source: source.copyWith(removed: true),
      );
      return MarketplaceDriftCheckResult(
        removedNotice: MarketplaceRemovedNotice(
          itemType: itemType,
          localId: localId,
          source: source,
        ),
      );
    }

    // Up-to-date already.
    if (current.id == source.listingId) return MarketplaceDriftCheckResult.none;
    if (current.contentHash == source.syncedHash) return MarketplaceDriftCheckResult.none;

    // The user previously dismissed *this exact* new version. Stay quiet
    // until an even newer snapshot lands.
    if (current.id == source.dismissedListingId) {
      return MarketplaceDriftCheckResult.none;
    }

    return MarketplaceDriftCheckResult(
      prompt: MarketplaceUpdatePrompt(
        itemType: itemType,
        localId: localId,
        source: source,
        newListing: current,
      ),
    );
  }

  /// Batch drift check used by the hub badge. One RPC call covers every
  /// downloaded item the user has — keyed by `(itemType, localId)`.
  Future<Map<({String itemType, String localId}), MarketplaceDriftCheckResult>>
      checkAll() async {
    final result =
        <({String itemType, String localId}), MarketplaceDriftCheckResult>{};
    if (!SupabaseConfig.isConfigured) return result;
    if (_ref.read(authProvider) == null) return result;

    final store = _ref.read(marketplaceLinksLocalDsProvider);
    final entries = await store.allReaderSources();
    if (entries.isEmpty) return result;

    // Skip muted/removed up front so we don't waste an RPC slot on them.
    final actionable = entries
        .where((e) => !e.source.muted && !e.source.removed)
        .toList();
    if (actionable.isEmpty) return result;

    final lineageIds = actionable.map((e) => e.source.lineageId).toSet().toList();
    Map<String, MarketplaceListing> currents;
    try {
      currents = await _ref
          .read(marketplaceListingsRemoteDsProvider)
          .currentVersionsForLineages(lineageIds);
    } catch (e) {
      debugPrint('marketplace batch drift check failed: $e');
      return result;
    }

    for (final entry in actionable) {
      final key = (itemType: entry.itemType, localId: entry.localId);
      final source = entry.source;
      final current = currents[source.lineageId];

      if (current == null) {
        await store.setSource(
          itemType: entry.itemType,
          localId: entry.localId,
          source: source.copyWith(removed: true),
        );
        result[key] = MarketplaceDriftCheckResult(
          removedNotice: MarketplaceRemovedNotice(
            itemType: entry.itemType,
            localId: entry.localId,
            source: source,
          ),
        );
        continue;
      }

      if (current.id == source.listingId ||
          current.contentHash == source.syncedHash ||
          current.id == source.dismissedListingId) {
        continue;
      }

      result[key] = MarketplaceDriftCheckResult(
        prompt: MarketplaceUpdatePrompt(
          itemType: entry.itemType,
          localId: entry.localId,
          source: source,
          newListing: current,
        ),
      );
    }
    return result;
  }
}

final marketplaceSyncServiceProvider = Provider<MarketplaceSyncService>((ref) {
  return MarketplaceSyncService(ref);
});
