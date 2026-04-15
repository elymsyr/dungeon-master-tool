import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../core/utils/deep_copy.dart';
import '../../data/network/asset_service.dart';
import '../../domain/value_objects/asset_ref.dart';

/// Walks a world-backup `data` map and uploads every local image referenced
/// by an entity — or sitting loose in `{worldsDir}/{worldName}/media/` — to
/// Cloudflare R2 via [AssetService]. Entity strings are rewritten in place
/// to `dmt-asset://{r2_key}` and a `media_manifest` is attached to the
/// returned map.
///
/// Uses [AssetService.uploadAsset]'s SHA dedupe ([lines 68-76]) so rerunning
/// a backup after a partial failure is cheap.
///
/// Failures for individual files are collected in [MediaBundleResult.failures]
/// and do NOT abort the bundle — upload best-effort, let the user retry.
class MediaBundler {
  MediaBundler(this._assetService);

  final AssetService _assetService;

  /// Deep-clone [data] (so the in-memory entity graph is untouched), upload
  /// all local-path media to R2, replace strings with `dmt-asset://` URIs,
  /// attach `data['media_manifest']`, and return the new map.
  Future<MediaBundleResult> bundleWorldMedia({
    required String worldName,
    required String worldId,
    required Map<String, dynamic> data,
  }) async {
    final cloned = deepCopyJson(data) as Map<String, dynamic>;
    final manifest = <Map<String, dynamic>>[];
    final failures = <MediaBundleFailure>[];
    // Dedupe by r2_key so the manifest lists each asset once even when
    // multiple entities reference the same file.
    final seenKeys = <String, int>{};

    Future<String?> uploadAndTrack(
      String localPath,
      String refLabel, {
      bool bubbleErrors = true,
    }) async {
      final file = File(localPath);
      if (!await file.exists()) {
        failures.add(MediaBundleFailure(localPath, 'file_not_found'));
        return null;
      }
      try {
        final uri = await _assetService.uploadAsset(
          file,
          campaignId: worldId,
        );
        final key = uri.toString().substring(AssetRef.scheme.length);

        final existingIdx = seenKeys[key];
        if (existingIdx != null) {
          (manifest[existingIdx]['referenced_by'] as List).add(refLabel);
          return AssetRef.formatCloudUri(key);
        }

        final bytes = await file.length();
        final sha = AssetService.extractShaFromKey(key);
        manifest.add({
          'r2_key': key,
          'sha256': sha,
          'size_bytes': bytes,
          'original_filename': p.basename(localPath),
          'referenced_by': <String>[refLabel],
        });
        seenKeys[key] = manifest.length - 1;
        return AssetRef.formatCloudUri(key);
      } catch (e) {
        if (bubbleErrors) {
          failures.add(MediaBundleFailure(localPath, '$e'));
        }
        return null;
      }
    }

    // Track already-cloud refs so we surface them in the manifest even when
    // no re-upload is needed. This lets the restore side download them into
    // the new device's media dir so the gallery shows them.
    void trackExistingCloudRef(String cloudRef, String refLabel) {
      final key = cloudRef.substring(AssetRef.scheme.length);
      final existingIdx = seenKeys[key];
      if (existingIdx != null) {
        (manifest[existingIdx]['referenced_by'] as List).add(refLabel);
        return;
      }
      try {
        final sha = AssetService.extractShaFromKey(key);
        manifest.add({
          'r2_key': key,
          'sha256': sha,
          // size + filename are unknown here; the restorer doesn't need them
          // (downloadAsset looks up by key).
          'referenced_by': <String>[refLabel],
        });
        seenKeys[key] = manifest.length - 1;
      } catch (_) {
        // malformed key — skip
      }
    }

    // 1. Walk entities.
    final entities = cloned['entities'];
    if (entities is Map<String, dynamic>) {
      for (final entry in entities.entries) {
        final entityId = entry.key;
        final entityMap = entry.value;
        if (entityMap is! Map<String, dynamic>) continue;

        // Legacy imagePath
        final legacyPath = entityMap['image_path'];
        if (legacyPath is String && legacyPath.isNotEmpty) {
          final assetRef = AssetRef(legacyPath);
          if (assetRef.isCloud) {
            trackExistingCloudRef(legacyPath, 'entity:$entityId:image_path');
          } else {
            final uri = await uploadAndTrack(
              legacyPath,
              'entity:$entityId:image_path',
            );
            if (uri != null) entityMap['image_path'] = uri;
          }
        }

        // images list
        final images = entityMap['images'];
        if (images is List) {
          for (var i = 0; i < images.length; i++) {
            final raw = images[i];
            if (raw is! String || raw.isEmpty) continue;
            final assetRef = AssetRef(raw);
            if (assetRef.isCloud) {
              trackExistingCloudRef(raw, 'entity:$entityId:images[$i]');
              continue;
            }
            final uri =
                await uploadAndTrack(raw, 'entity:$entityId:images[$i]');
            if (uri != null) images[i] = uri;
          }
        }
      }
    }

    // 2. Walk the media directory for gallery files that aren't referenced
    // by any entity — still bundle them so the gallery round-trips.
    final mediaDir = Directory(p.join(AppPaths.worldsDir, worldName, 'media'));
    if (await mediaDir.exists()) {
      final referencedPaths = <String>{};
      // Track which local paths already made it into the manifest via entities
      // so we don't upload them twice. Note: entity paths got rewritten above,
      // so we compute the original path from the sha <-> filename mapping by
      // re-reading the original data.
      final original = data['entities'];
      if (original is Map<String, dynamic>) {
        for (final e in original.values) {
          if (e is! Map<String, dynamic>) continue;
          final imagePath = e['image_path'];
          if (imagePath is String &&
              imagePath.isNotEmpty &&
              !AssetRef(imagePath).isCloud) {
            referencedPaths.add(p.canonicalize(imagePath));
          }
          final imgs = e['images'];
          if (imgs is List) {
            for (final x in imgs) {
              if (x is String && x.isNotEmpty && !AssetRef(x).isCloud) {
                referencedPaths.add(p.canonicalize(x));
              }
            }
          }
        }
      }

      await for (final entry in mediaDir.list()) {
        if (entry is! File) continue;
        final ext = p.extension(entry.path).toLowerCase();
        if (!_imageExts.contains(ext)) continue;
        final canonical = p.canonicalize(entry.path);
        if (referencedPaths.contains(canonical)) continue;
        await uploadAndTrack(entry.path, 'gallery');
      }
    }

    cloned['media_manifest'] = manifest;
    cloned['media_manifest_version'] = 1;

    return MediaBundleResult(
      data: cloned,
      manifest: manifest,
      failures: failures,
    );
  }

  static const _imageExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.bmp',
    '.webp',
    '.gif',
  };

  /// For tests — stable SHA-256 hex of [file].
  static Future<String> sha256Of(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}

class MediaBundleResult {
  MediaBundleResult({
    required this.data,
    required this.manifest,
    required this.failures,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> manifest;
  final List<MediaBundleFailure> failures;
}

class MediaBundleFailure {
  MediaBundleFailure(this.localPath, this.reason);
  final String localPath;
  final String reason;

  @override
  String toString() => '$localPath: $reason';
}
