import 'package:flutter/foundation.dart';

/// Reader-side sync metadata persisted alongside a downloaded local item
/// (campaign / template / package). Identifies which marketplace listing the
/// local copy originated from, so the UI can render an "imported from @owner"
/// badge.
///
/// Version/drift tracking is intentionally absent — each publish is an
/// independent listing, so there is nothing to compare against.
@immutable
class MarketplaceSource {
  const MarketplaceSource({
    required this.listingId,
    required this.syncedHash,
    required this.syncedAt,
    this.ownerUsername,
  });

  final String listingId;
  final String syncedHash;
  final DateTime syncedAt;
  final String? ownerUsername;

  MarketplaceSource copyWith({
    String? listingId,
    String? syncedHash,
    DateTime? syncedAt,
    String? ownerUsername,
  }) {
    return MarketplaceSource(
      listingId: listingId ?? this.listingId,
      syncedHash: syncedHash ?? this.syncedHash,
      syncedAt: syncedAt ?? this.syncedAt,
      ownerUsername: ownerUsername ?? this.ownerUsername,
    );
  }

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'synced_hash': syncedHash,
        'synced_at': syncedAt.toUtc().toIso8601String(),
        if (ownerUsername != null) 'owner_username': ownerUsername,
      };

  static MarketplaceSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final listingId = raw['listing_id'];
    final syncedHash = raw['synced_hash'];
    final syncedAt = raw['synced_at'];
    if (listingId is! String || syncedHash is! String) {
      return null;
    }
    return MarketplaceSource(
      listingId: listingId,
      syncedHash: syncedHash,
      syncedAt: syncedAt is String
          ? DateTime.tryParse(syncedAt)?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      ownerUsername: raw['owner_username'] as String?,
    );
  }
}

/// Stable JSON key under which a [MarketplaceSource] is persisted inside an
/// item's stateJson. Single source of truth so reader/writer never drift.
const String kMarketplaceSourceKey = 'marketplace_source';
