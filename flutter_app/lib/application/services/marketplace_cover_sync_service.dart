import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/local/marketplace_links_local_ds.dart';
import '../../data/datasources/remote/marketplace_listings_remote_ds.dart';
import '../providers/marketplace_listing_provider.dart';
import 'asset_ref_resolver.dart';
import 'marketplace_cover_encoder.dart';

/// Bir entity (world / package / character) kapağı/portresi DEĞİŞTİĞİNDE o
/// entity'den publish edilmiş marketplace listing'lerinin banner'ını (inline
/// `cover_image_b64`) yeni görselle tazeler.
///
/// İçerik kopyası (`content_hash` / `payload_path`) dokunulmaz kalır — sadece
/// banner güncellenir. Best-effort: hata fırlatmaz, local save'i bloklamaz.
class MarketplaceCoverSyncService {
  MarketplaceCoverSyncService({
    required this.local,
    required this.remote,
    required this.resolver,
  });

  final MarketplaceLinksLocalDataSource local;
  final MarketplaceListingsRemoteDataSource remote;
  final AssetRefResolver resolver;

  /// [itemType] ∈ {'world','package','character'}.
  /// [localId]: world/package → ad, character → id.
  /// Yeni ref DB'ye commit edildikten SONRA çağrılmalı.
  Future<void> syncCover({
    required String itemType,
    required String localId,
    required String? oldRef,
    required String? newRef,
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    final oldR = oldRef?.trim() ?? '';
    final newR = newRef?.trim() ?? '';
    if (oldR == newR) return; // kapak değişmedi
    final ids = await local.getOwnedListingIds(itemType, localId); // offline-safe
    if (ids.isEmpty) return; // publish edilmemiş

    String? b64;
    if (newR.isNotEmpty) {
      b64 = await encodeCoverThumbnailB64(resolver, newR);
      if (b64 == null) {
        // Resolve/encode başarısız (muhtemelen offline) — listing'lerin mevcut
        // banner'ını koru, null push edip silme.
        debugPrint('cover sync: encode failed $itemType/$localId — skip');
        return;
      }
    }
    // newR boş → b64 null kalır → kapak bilerek kaldırılmış (fallback icon).
    for (final id in ids) {
      try {
        await remote.updateListingCover(listingId: id, coverImageB64: b64);
      } catch (e) {
        debugPrint('cover sync update $id: $e');
      }
    }
  }
}

/// Supabase konfigüre değilse null döner — çağıranlar no-op yapar.
final marketplaceCoverSyncServiceProvider =
    Provider<MarketplaceCoverSyncService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return MarketplaceCoverSyncService(
    local: ref.watch(marketplaceLinksLocalDsProvider),
    remote: ref.watch(marketplaceListingsRemoteDsProvider),
    resolver: ref.watch(assetRefResolverProvider),
  );
});
