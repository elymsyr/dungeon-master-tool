import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/asset_ref.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import 'entity_media_cleanup_service.dart';
import '../../domain/value_objects/media_kind.dart';
import 'local_media_localizer.dart';
import 'pending_write_buffer.dart';
import 'world_media_sync.dart';

/// A `read` accessor compatible with both `Ref` (notifiers) and `WidgetRef`
/// (consumer widgets) — lets the map image helpers serve every call site.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Aktif dünyanın medya klasörüne kopyala. Dünya adı bilinmiyorsa (kapalı
/// dünya / paket ekranı) yolu dokunmadan geri döndürür.
///
/// Buluta yükleme burada YOK: seçicinin verdiği ham yol (`.../Downloads/map.png`)
/// veri kökünün dışında kalıyor, `.dmtz` yalnız veri kökü altını taşıyor
/// (`ContentCodec._mediaFor`). Multiplayer dünyada kopya push turuyla
/// dünyanın bulut medyasına çıkar (Faz 5d).
Future<String> localizeMapImage(ProviderReader read, String path) async {
  final worldId = read(activeCampaignProvider);
  if (worldId == null || worldId.isEmpty) return path;
  return LocalMediaLocalizer.localize(
    path,
    ownerDir: LocalMediaLocalizer.worldDir(worldId),
  );
}

/// Projeksiyon için: hâlâ yerel olan bir harita/mindmap görselinin
/// `dmt-content://` ref'ini döndürür; dünyanın bulut medyasında değilse önce
/// yükler (harita limitiyle). Dünya online değilse, yol zaten ref'se ya da
/// yükleme başarısızsa [path] aynen döner.
///
/// Dönen ref **kalıcı satıra yazılmaz** — DM'in satırı yerel yolunu korur,
/// ref yalnız o projeksiyonda.
Future<String> projectableMapImage(ProviderReader read, String path) async {
  if (path.isEmpty || !AssetRef(path).isLocal) return path;
  final worldId =
      read(activeCampaignProvider.notifier).data?['world_id'] as String?;
  final media = read(worldMediaSyncProvider);
  if (worldId == null ||
      media == null ||
      !read(onlineWorldIdsProvider).contains(worldId)) {
    return path;
  }
  try {
    return await media.publish(worldId, path, kind: MediaKind.battleMap) ??
        path;
  } catch (e) {
    debugPrint('projectableMapImage $path: $e');
    return path;
  }
}

/// Best-effort cloud cleanup for a map image ref that was just removed or
/// replaced. No-op for local/content refs or when no cleanup service is
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
