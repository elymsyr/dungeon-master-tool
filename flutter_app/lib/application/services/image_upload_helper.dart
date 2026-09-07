import 'dart:io';

import '../../data/network/asset_service.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// Eager image-upload helpers — share the upload + graceful-fallback shape so
/// every image-pick spot (and the refresh/sync paths) can push a freshly
/// chosen file to the cloud immediately, the way `_pickCover` already does.
///
/// Each function takes the resolved service (nullable — caller reads it from
/// the provider) so it works from both UI (`WidgetRef`) and services (`Ref`)
/// without a ref-type dependency.
///
/// Contract for all three: never throw, never re-upload an already-cloud ref,
/// and on any failure (offline / quota / no service / missing file) return the
/// input unchanged so the caller keeps a usable local path.

/// Uploads a local entity image to Cloudflare R2 (counted quota) and returns
/// its `dmt-asset://` ref. Returns [localPath] untouched when [service] is
/// null, the path is already a cloud ref, the file is missing, or the upload
/// fails.
///
/// The result's [quotaExceeded] is `true` only when the upload fell back to
/// the local path because the user's storage quota is full — callers use it
/// to surface a "stored on device" notice. [tooLarge] is `true` when the
/// upload was rejected because the file exceeds the per-kind size limit
/// ([MediaKind.maxBytes]); callers surface a "not backed up to cloud" notice.
/// When [tooLarge] is `true`, [actualBytes] is the rejected file's size so
/// the snackbar can show both the actual size and the limit; otherwise `null`.
/// Every other fallback (offline, no service, missing file, already-cloud
/// ref) returns both flags `false`.
Future<({String ref, bool quotaExceeded, bool tooLarge, int? actualBytes})>
    uploadEntityImageRef(
  AssetService? service, {
  required String localPath,
  required String scopeId,
  required MediaKind kind,
  bool transientFallback = false,
}) async {
  if (service == null || !AssetRef(localPath).isLocal) {
    return (
      ref: localPath,
      quotaExceeded: false,
      tooLarge: false,
      actualBytes: null,
    );
  }
  final file = File(localPath);
  if (!await file.exists()) {
    return (
      ref: localPath,
      quotaExceeded: false,
      tooLarge: false,
      actualBytes: null,
    );
  }
  try {
    final uri = await service.uploadAsset(
      file,
      campaignId: scopeId,
      kind: kind,
    );
    return (
      ref: uri.toString(),
      quotaExceeded: false,
      tooLarge: false,
      actualBytes: null,
    );
  } on AssetQuotaExceededException catch (_) {
    // Counted quota full. For projection ([transientFallback] true), fall
    // back to the shared transient pool (per-user 100 MB cap, global LRU)
    // so online players still resolve it; the transient ref must NOT be
    // persisted (server LRU may evict + R2 lifecycle TTL).
    if (transientFallback) {
      try {
        final uri = await service.uploadTransientShare(
          file,
          kind: kind,
          worldId: scopeId,
        );
        return (
          ref: uri.toString(),
          quotaExceeded: false,
          tooLarge: false,
          actualBytes: null,
        );
      } on TransientQuotaExceededException catch (_) {
        // İki katmanlı: counted full + transient full. Caller bunu
        // "her iki alan da dolu" mesajına çevirir.
        return (
          ref: localPath,
          quotaExceeded: true,
          tooLarge: false,
          actualBytes: null,
        );
      } catch (_) {
        return (
          ref: localPath,
          quotaExceeded: true,
          tooLarge: false,
          actualBytes: null,
        );
      }
    }
    return (
      ref: localPath,
      quotaExceeded: true,
      tooLarge: false,
      actualBytes: null,
    );
  } on AssetServiceException catch (e) {
    final isTooLarge = e.code == 'too_large';
    int? size;
    if (isTooLarge) {
      try {
        size = await file.length();
      } catch (_) {}
    }
    return (
      ref: localPath,
      quotaExceeded: false,
      tooLarge: isTooLarge,
      actualBytes: size,
    );
  } catch (_) {
    return (
      ref: localPath,
      quotaExceeded: false,
      tooLarge: false,
      actualBytes: null,
    );
  }
}
