import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/local/marketplace_links_local_ds.dart';
import '../../data/datasources/remote/marketplace_listings_remote_ds.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../providers/marketplace_listing_provider.dart';

/// Bir entity (world / package / character) silindiğinde o entity'den
/// publish edilmiş tüm marketplace snapshot'larını siler — `marketplace_listings`
/// satırları + `shared-payloads` bucket blob'ları.
///
/// Best-effort: hata fırlatmaz, local silmeyi bloklamaz. Offline / oturum
/// kapalıysa remote fetch başarısız olur → local index korunur ki kullanıcı
/// listing'leri sonradan elle silebilsin.
class MarketplaceCleanupService {
  MarketplaceCleanupService({required this.local, required this.remote});

  final MarketplaceLinksLocalDataSource local;
  final MarketplaceListingsRemoteDataSource remote;

  /// [itemType] ∈ {'world','package','character'}.
  /// [localId]: world→ad, package→ad, character→id.
  Future<void> cleanupItem({
    required String itemType,
    required String localId,
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    final ids = await local.getOwnedListingIds(itemType, localId); // offline-safe
    if (ids.isEmpty) return;
    final List<MarketplaceListing> rows;
    try {
      rows = await remote.fetchListingsByIds(ids); // auth + network gerekir
    } catch (e) {
      debugPrint('marketplace cleanup fetch error: $e');
      return; // local index'i koru — kullanıcı sonradan elle silebilir
    }
    final fetched = {for (final r in rows) r.id};
    for (final l in rows) {
      try {
        await remote.deleteListing(listingId: l.id, payloadPath: l.payloadPath);
        await local.removeOwnedListingId(
          itemType: itemType,
          localId: localId,
          listingId: l.id,
        );
      } catch (e) {
        debugPrint('marketplace cleanup delete ${l.id}: $e');
      }
    }
    // Sunucuda zaten yok olan satırlar → bayat local id'leri de düşür.
    for (final id in ids) {
      if (fetched.contains(id)) continue;
      try {
        await local.removeOwnedListingId(
          itemType: itemType,
          localId: localId,
          listingId: id,
        );
      } catch (_) {/* ignore */}
    }
  }
}

/// Supabase konfigüre değilse null döner — çağıranlar no-op yapar.
final marketplaceCleanupServiceProvider =
    Provider<MarketplaceCleanupService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return MarketplaceCleanupService(
    local: ref.watch(marketplaceLinksLocalDsProvider),
    remote: ref.watch(marketplaceListingsRemoteDsProvider),
  );
});
