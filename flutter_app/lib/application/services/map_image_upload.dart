import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import 'entity_media_cleanup_service.dart';
import 'image_upload_helper.dart';
import 'local_media_localizer.dart';
import 'pending_write_buffer.dart';

/// A `read` accessor compatible with both `Ref` (notifiers) and `WidgetRef`
/// (consumer widgets) — lets the map image helpers serve every call site.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Eager-uploads a freshly picked map image (mind map node / world map /
/// battle map background) to Cloudflare R2 when the host world is online +
/// signed-in.
///
/// Seçilen dosya **her koşulda önce** `{worldsDir}/{worldName}/media/` altına
/// kopyalanır ([LocalMediaLocalizer]); yükleme de o kopyadan yapılır. Bulut
/// yüklemesi başarılıysa dönen değer `dmt-asset://` ref'idir, atlandıysa
/// (çevrimdışı dünya, oturum yok, servis yok) ya da düştüyse (kota, boyut, ağ)
/// kopyanın yolu döner.
///
/// Neden her koşulda: seçicinin verdiği ham yol (`.../Downloads/map.png`) veri
/// kökünün dışında kalıyor. LAN eşlemesi yalnız veri kökü altını taşıyor
/// (`LanSyncSession._mediaFor`), dolayısıyla battle map / mindmap resimleri
/// karşı cihaza hiç gitmiyordu; üstelik kullanıcı kaynak dosyayı taşırsa resim
/// tamamen kayboluyordu. Yükleme başarılı olsa bile kopya duruyor: R2 nesnesi
/// temizlenir ya da içerik önbelleği boşalırsa resim yine de açılabilsin.
///
/// `quotaExceeded` is true when the upload fell back to local because the
/// user's storage quota is full; `tooLarge` is true when it was rejected for
/// exceeding the per-kind size limit. Offline worlds bundle map media at Make
/// Online instead (see `MediaBundler.bundleSettingsMedia` / `bundleMapMedia`).
Future<({String ref, bool quotaExceeded, bool tooLarge, int? actualBytes})>
    uploadMapImage(
  ProviderReader read, {
  required String path,
  required MediaKind kind,
  bool transientFallback = false,
}) async {
  if (!AssetRef(path).isLocal) {
    return (ref: path, quotaExceeded: false, tooLarge: false, actualBytes: null);
  }
  final worldId =
      read(activeCampaignProvider.notifier).data?['world_id'] as String?;
  final assetSvc = read(assetServiceProvider);
  final canUpload = read(authProvider) != null &&
      assetSvc != null &&
      worldId != null &&
      read(onlineWorldIdsProvider).contains(worldId);

  // Önce kopyala — yükleme yapılsın ya da yapılmasın, ham yol asla saklanmaz.
  final localPath = await localizeMapImage(read, path);

  if (!canUpload) {
    return (
      ref: localPath,
      quotaExceeded: false,
      tooLarge: false,
      actualBytes: null,
    );
  }

  // Kaynak olarak kopyayı ver: baytlar aynı, ama kullanıcı orijinali eşzamanlı
  // silse bile yükleme elimizdeki dosyadan yapılıyor.
  final result = await uploadEntityImageRef(assetSvc,
      localPath: localPath,
      scopeId: worldId,
      kind: kind,
      transientFallback: transientFallback);
  // Kota / boyut / ağ hatasında `localPath` aynen geri geliyor — o da zaten
  // veri kökünün içinde, ek bir şey yapmaya gerek yok.
  return result;
}

/// Aktif dünyanın medya klasörüne kopyala. Dünya adı bilinmiyorsa (kapalı
/// dünya / paket ekranı) yolu dokunmadan geri döndürür.
Future<String> localizeMapImage(ProviderReader read, String path) async {
  final worldName = read(activeCampaignProvider);
  if (worldName == null || worldName.isEmpty) return path;
  return LocalMediaLocalizer.localize(
    path,
    ownerDir: LocalMediaLocalizer.worldDir(worldName),
  );
}

/// Best-effort cloud cleanup for a map image ref that was just removed or
/// replaced. No-op for local/transient refs or when no cleanup service is
/// configured. Flushes [flushPrefix] and forces a sync tick first so the
/// post-change row is committed before [EntityMediaCleanupService]'s
/// reference scan runs — the scan keeps the object alive if another node /
/// epoch still references the same SHA-deduped ref.
Future<void> cleanupMapImageRef(
  ProviderReader read, {
  required String? removedRef,
  required String flushPrefix,
}) async {
  final raw = removedRef?.trim() ?? '';
  if (raw.isEmpty || !AssetRef(raw).isCloud) return;
  final cleanup = read(entityMediaCleanupServiceProvider);
  if (cleanup == null) return; // Supabase/Worker not configured → no-op
  try {
    await read(pendingWriteBufferProvider).flushPrefix(flushPrefix);
    await cleanup.cleanupRemovedRef(raw);
  } catch (e) {
    debugPrint('map image cloud cleanup error: $e');
  }
}
