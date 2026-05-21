import 'dart:io';

import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
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
/// to surface a "stored on device" notice. Every other fallback (offline, no
/// service, missing file, already-cloud ref) returns `quotaExceeded: false`.
Future<({String ref, bool quotaExceeded})> uploadEntityImageRef(
  AssetService? service, {
  required String localPath,
  required String scopeId,
  required MediaKind kind,
}) async {
  if (service == null || !AssetRef(localPath).isLocal) {
    return (ref: localPath, quotaExceeded: false);
  }
  final file = File(localPath);
  if (!await file.exists()) return (ref: localPath, quotaExceeded: false);
  try {
    final uri = await service.uploadAsset(
      file,
      campaignId: scopeId,
      kind: kind,
    );
    return (ref: uri.toString(), quotaExceeded: false);
  } on AssetQuotaExceededException catch (_) {
    return (ref: localPath, quotaExceeded: true);
  } catch (_) {
    return (ref: localPath, quotaExceeded: false);
  }
}

/// Uploads a local character portrait to the free-media bucket (quota-exempt)
/// and returns its `dmt-public://` ref. Same fallback contract as
/// [uploadEntityImageRef].
Future<String> uploadCharacterPortraitRef(
  FreeMediaService? service, {
  required String localPath,
  required String scopeId,
}) async {
  if (service == null || !AssetRef(localPath).isLocal) return localPath;
  final file = File(localPath);
  if (!await file.exists()) return localPath;
  try {
    final uri = await service.uploadFreeMedia(
      file,
      kind: MediaKind.characterPortrait,
      scopeId: scopeId,
    );
    return uri.toString();
  } catch (_) {
    return localPath;
  }
}

/// If `metadata['cover_image_path']` is a local path, uploads it to the
/// free-media bucket and returns a shallow copy of [metadata] with the value
/// replaced by the `dmt-public://` ref. Returns [metadata] unchanged when
/// there is nothing to upload or the upload fails.
Future<Map<String, dynamic>> uploadCoverImageInMetadata(
  FreeMediaService? service, {
  required Map<String, dynamic> metadata,
  required MediaKind coverKind,
  required String scopeId,
}) async {
  final path = metadata['cover_image_path'];
  if (service == null || path is! String || !AssetRef(path).isLocal) {
    return metadata;
  }
  final file = File(path);
  if (!await file.exists()) return metadata;
  try {
    final uri = await service.uploadFreeMedia(
      file,
      kind: coverKind,
      scopeId: scopeId,
    );
    return {...metadata, 'cover_image_path': uri.toString()};
  } catch (_) {
    return metadata;
  }
}
