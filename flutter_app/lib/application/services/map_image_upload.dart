import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/asset_ref.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import 'entity_media_cleanup_service.dart';
import 'local_media_localizer.dart';
import 'shared_media_courier.dart';
import 'pending_write_buffer.dart';

/// A `read` accessor compatible with both `Ref` (notifiers) and `WidgetRef`
/// (consumer widgets) — lets the map image helpers serve every call site.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Aktif dünyanın medya klasörüne kopyala. Dünya adı bilinmiyorsa (kapalı
/// dünya / paket ekranı) yolu dokunmadan geri döndürür.
///
/// Buluta yükleme YOK (Phase D — sayılan katman kaldırıldı): seçicinin verdiği
/// ham yol (`.../Downloads/map.png`) veri kökünün dışında kalıyor, LAN
/// eşlemesi yalnız veri kökü altını taşıyor (`LanSyncSession._mediaFor`).
/// Harita görselinin buluta çıktığı tek yer projeksiyon
/// (`WorldMapNotifier.ensureMapImageProjectable` → transient).
Future<String> localizeMapImage(ProviderReader read, String path) async {
  final worldName = read(activeCampaignProvider);
  if (worldName == null || worldName.isEmpty) return path;
  return LocalMediaLocalizer.localize(
    path,
    ownerDir: LocalMediaLocalizer.worldDir(worldName),
  );
}

/// Projeksiyon için: hâlâ yerel olan bir harita/mindmap görselini transient
/// havuza yükler ve `dmt-transient://` ref'ini döndürür. Dünya online değilse,
/// yol zaten bulut ref'iyse ya da yükleme başarısızsa [path] aynen döner.
///
/// Dönen ref **kalıcı satıra yazılmaz** — transient obje LRU ile atılabilir,
/// ölü ref bırakmak DM'in kendi resmini kaybetmesi olurdu.
Future<String> projectableMapImage(ProviderReader read, String path) async {
  if (path.isEmpty || !AssetRef(path).isLocal) return path;
  final worldId =
      read(activeCampaignProvider.notifier).data?['world_id'] as String?;
  if (worldId == null || !read(onlineWorldIdsProvider).contains(worldId)) {
    return path;
  }
  return await read(sharedMediaCourierProvider).publish(worldId, path) ?? path;
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
