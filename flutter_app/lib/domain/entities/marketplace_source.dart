import 'package:flutter/foundation.dart';

/// Reader-side sync metadata persisted in a downloaded item's state JSON
/// (campaign / template / package). Tracks which marketplace listing the
/// local copy was imported from and the user's drift-notification
/// preferences.
///
/// Stored under the JSON key [kMarketplaceSourceKey] inside the item's
/// stateJson, mirroring the convention of `TemplateSyncService` for
/// template lineage tracking.
@immutable
class MarketplaceSource {
  const MarketplaceSource({
    required this.listingId,
    required this.lineageId,
    required this.syncedHash,
    required this.syncedAt,
    this.ownerUsername,
    this.dismissedListingId,
    this.muted = false,
    this.removed = false,
  });

  final String listingId;
  final String lineageId;
  final String syncedHash;
  final DateTime syncedAt;
  final String? ownerUsername;
  final String? dismissedListingId;
  final bool muted;
  final bool removed;

  MarketplaceSource copyWith({
    String? listingId,
    String? syncedHash,
    DateTime? syncedAt,
    String? ownerUsername,
    Object? dismissedListingId = _sentinel,
    bool? muted,
    bool? removed,
  }) {
    return MarketplaceSource(
      listingId: listingId ?? this.listingId,
      lineageId: lineageId,
      syncedHash: syncedHash ?? this.syncedHash,
      syncedAt: syncedAt ?? this.syncedAt,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      dismissedListingId: identical(dismissedListingId, _sentinel)
          ? this.dismissedListingId
          : dismissedListingId as String?,
      muted: muted ?? this.muted,
      removed: removed ?? this.removed,
    );
  }

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'lineage_id': lineageId,
        'synced_hash': syncedHash,
        'synced_at': syncedAt.toUtc().toIso8601String(),
        if (ownerUsername != null) 'owner_username': ownerUsername,
        if (dismissedListingId != null) 'dismissed_listing_id': dismissedListingId,
        'muted': muted,
        'removed': removed,
      };

  static MarketplaceSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final listingId = raw['listing_id'];
    final lineageId = raw['lineage_id'];
    final syncedHash = raw['synced_hash'];
    final syncedAt = raw['synced_at'];
    if (listingId is! String || lineageId is! String || syncedHash is! String) {
      return null;
    }
    return MarketplaceSource(
      listingId: listingId,
      lineageId: lineageId,
      syncedHash: syncedHash,
      syncedAt: syncedAt is String
          ? DateTime.tryParse(syncedAt)?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      ownerUsername: raw['owner_username'] as String?,
      dismissedListingId: raw['dismissed_listing_id'] as String?,
      muted: raw['muted'] == true,
      removed: raw['removed'] == true,
    );
  }
}

const Object _sentinel = Object();

/// Stable JSON key under which a [MarketplaceSource] is persisted inside an
/// item's stateJson. Single source of truth so reader/writer never drift.
const String kMarketplaceSourceKey = 'marketplace_source';
