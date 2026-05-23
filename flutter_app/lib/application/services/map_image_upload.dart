import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/sync_engine_provider.dart';
import 'entity_media_cleanup_service.dart';
import 'image_upload_helper.dart';
import 'pending_write_buffer.dart';

/// A `read` accessor compatible with both `Ref` (notifiers) and `WidgetRef`
/// (consumer widgets) — lets the map image helpers serve every call site.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Eager-uploads a freshly picked map image (mind map node / world map /
/// battle map background) to Cloudflare R2 when the host world is online +
/// signed-in.
///
/// Returns the cloud `dmt-asset://` ref, or [path] unchanged when the upload
/// is skipped (offline world, signed-out, no service, already a cloud ref) or
/// failed. `quotaExceeded` is true when the upload fell back to local because
/// the user's storage quota is full; `tooLarge` is true when it was rejected
/// for exceeding the per-kind size limit. Offline worlds bundle map media at
/// Make Online instead (see `MediaBundler.bundleSettingsMedia` / `bundleMapMedia`).
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
  if (read(authProvider) == null) {
    return (ref: path, quotaExceeded: false, tooLarge: false, actualBytes: null);
  }
  final assetSvc = read(assetServiceProvider);
  if (assetSvc == null) {
    return (ref: path, quotaExceeded: false, tooLarge: false, actualBytes: null);
  }
  final worldId =
      read(activeCampaignProvider.notifier).data?['world_id'] as String?;
  if (worldId == null || !read(onlineWorldIdsProvider).contains(worldId)) {
    return (ref: path, quotaExceeded: false, tooLarge: false, actualBytes: null);
  }
  return uploadEntityImageRef(assetSvc,
      localPath: path,
      scopeId: worldId,
      kind: kind,
      transientFallback: transientFallback);
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
    await read(syncEngineProvider).forceTick();
    await cleanup.cleanupRemovedRef(raw);
  } catch (e) {
    debugPrint('map image cloud cleanup error: $e');
  }
}
