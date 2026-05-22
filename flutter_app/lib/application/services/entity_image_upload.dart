import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/auth_provider.dart';
import '../providers/beta_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/package_provider.dart';
import '../providers/sync_engine_provider.dart';
import 'entity_media_cleanup_service.dart';
import 'image_upload_helper.dart';
import 'pending_write_buffer.dart';

/// Max number of images allowed per entity image collection — the portrait
/// gallery (`entity.images`) and each schema-defined image field are each
/// capped at this count.
const int kMaxEntityImages = 5;

/// Eager-uploads freshly picked entity image [paths] to Cloudflare R2 when the
/// host entity is online + signed-in, mirroring the gating used for entity
/// portraits (`entity_card._PortraitGallery`).
///
/// Returns the resolved refs (cloud `dmt-asset://` ref, or the local path
/// unchanged when upload is skipped/failed), the online world id whose outbox
/// row should be drained (null for package entities / offline / skipped),
/// `quotaExceeded` — true when any upload fell back to local because the
/// user's storage quota is full, and `tooLarge` — true when any upload was
/// rejected for exceeding the per-kind size limit (callers surface a snackbar).
///
/// Offline worlds bundle their media at Make Online, so they skip the upload
/// here and return the paths untouched.
Future<
        ({
          List<String> refs,
          String? pushWorldId,
          bool quotaExceeded,
          bool tooLarge,
        })>
    eagerUploadEntityImages(WidgetRef ref, List<String> paths) async {
  if (ref.read(authProvider) == null) {
    return (
      refs: paths,
      pushWorldId: null,
      quotaExceeded: false,
      tooLarge: false,
    );
  }
  final assetSvc = ref.read(assetServiceProvider);
  if (assetSvc == null) {
    return (
      refs: paths,
      pushWorldId: null,
      quotaExceeded: false,
      tooLarge: false,
    );
  }

  final String scopeId;
  final MediaKind kind;
  String? pushWorldId;
  final packageName = ref.read(activePackageProvider);
  if (packageName != null) {
    // Package entity image — counted R2; no per-row outbox to drain.
    if (!ref.read(betaProvider).isActive) {
      return (
        refs: paths,
        pushWorldId: null,
        quotaExceeded: false,
        tooLarge: false,
      );
    }
    scopeId = packageName;
    kind = MediaKind.packageEntityImage;
  } else {
    // World entity image — only eager-upload for an online world.
    final worldId =
        ref.read(activeCampaignProvider.notifier).data?['world_id'] as String?;
    if (worldId == null ||
        !ref.read(onlineWorldIdsProvider).contains(worldId)) {
      return (
        refs: paths,
        pushWorldId: null,
        quotaExceeded: false,
        tooLarge: false,
      );
    }
    scopeId = worldId;
    kind = MediaKind.worldEntityImage;
    pushWorldId = worldId;
  }

  final results = await Future.wait([
    for (final p in paths)
      uploadEntityImageRef(assetSvc,
          localPath: p, scopeId: scopeId, kind: kind),
  ]);
  return (
    refs: [for (final r in results) r.ref],
    pushWorldId: pushWorldId,
    quotaExceeded: results.any((r) => r.quotaExceeded),
    tooLarge: results.any((r) => r.tooLarge),
  );
}

/// Best-effort cloud cleanup for an entity image ref that was just removed.
///
/// No-op when the ref is local/transient, still referenced in [remaining],
/// the host is [readOnly], or no cleanup service is configured. Flushes the
/// `entity:` outbox prefix and forces a sync tick first so the post-removal
/// row is committed before [EntityMediaCleanupService]'s reference scan runs
/// — otherwise the scan sees this entity's stale ref and skips the delete.
Future<void> cleanupRemovedEntityImageRef(
  WidgetRef ref,
  String removedRef, {
  required bool readOnly,
  required List<String> remaining,
}) async {
  if (readOnly) return; // read-only / built-in package entity
  if (!AssetRef(removedRef).isCloud) return; // only dmt-asset:// counted
  if (remaining.contains(removedRef)) return; // duplicate in same entity
  if (ref.read(authProvider) == null) return;
  final packageName = ref.read(activePackageProvider);
  if (packageName != null && !ref.read(betaProvider).isActive) {
    return; // non-beta package image was never uploaded
  }
  final cleanup = ref.read(entityMediaCleanupServiceProvider);
  if (cleanup == null) return; // Supabase/Worker not configured → no-op
  try {
    await ref.read(pendingWriteBufferProvider).flushPrefix('entity:');
    await ref.read(syncEngineProvider).forceTick();
    await cleanup.cleanupRemovedRef(removedRef);
  } catch (e) {
    debugPrint('entity image cloud cleanup error: $e');
  }
}
