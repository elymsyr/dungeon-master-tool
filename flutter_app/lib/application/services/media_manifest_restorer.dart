import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../data/network/asset_service.dart';

/// Downloads every asset listed in a world backup's `media_manifest` and
/// mirrors it into `{worldsDir}/{worldName}/media/` so that:
///   1. `entity.images` refs (which stay as `dmt-asset://` URIs) are already
///      cached locally on first render.
///   2. The media gallery's `_scanLocalImages()` picks them up and shows
///      them to the user without waiting for entity-by-entity resolution.
///
/// Failures are aggregated in [MediaRestoreResult.failures] and do NOT
/// abort the restore — user gets a retry affordance at the call site.
class MediaManifestRestorer {
  MediaManifestRestorer(this._assetService);

  final AssetService _assetService;

  Future<MediaRestoreResult> restore({
    required String worldName,
    required List<dynamic>? manifest,
  }) async {
    if (manifest == null || manifest.isEmpty) {
      return MediaRestoreResult(restored: 0, failures: const []);
    }

    final mediaDir = Directory(p.join(AppPaths.worldsDir, worldName, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    var restored = 0;
    final failures = <MediaRestoreFailure>[];

    for (final entry in manifest) {
      if (entry is! Map) continue;
      final r2Key = entry['r2_key'] as String?;
      if (r2Key == null || r2Key.isEmpty) continue;

      try {
        final cacheFile = await _assetService.downloadAsset(r2Key);
        final target = await _pickTargetPath(
          dir: mediaDir,
          originalFilename: entry['original_filename'] as String?,
          r2Key: r2Key,
          cacheFile: cacheFile,
        );
        if (target == null) {
          // Already present (same bytes) — count as restored.
          restored++;
          continue;
        }
        await cacheFile.copy(target);
        restored++;
      } catch (e) {
        failures.add(MediaRestoreFailure(r2Key, '$e'));
      }
    }

    return MediaRestoreResult(restored: restored, failures: failures);
  }

  /// Resolve a target path for [cacheFile] inside [dir]. Returns `null` when
  /// an identical file already exists (no copy needed).
  Future<String?> _pickTargetPath({
    required Directory dir,
    required String? originalFilename,
    required String r2Key,
    required File cacheFile,
  }) async {
    final sha = AssetService.extractShaFromKey(r2Key);
    final ext = _extFromKey(r2Key);
    final preferred = originalFilename != null && originalFilename.isNotEmpty
        ? originalFilename
        : '$sha$ext';

    final primary = p.join(dir.path, preferred);
    if (!await File(primary).exists()) return primary;

    // Collision: is it the same content? Compare sizes as a cheap proxy.
    final existing = File(primary);
    final existingLen = await existing.length();
    final newLen = await cacheFile.length();
    if (existingLen == newLen) return null;

    // Different content — fall back to sha-named path.
    final fallback = p.join(dir.path, '$sha$ext');
    if (!await File(fallback).exists()) return fallback;
    return null;
  }

  static String _extFromKey(String r2Key) {
    final dot = r2Key.lastIndexOf('.');
    if (dot < 0) return '';
    return r2Key.substring(dot);
  }
}

class MediaRestoreResult {
  MediaRestoreResult({required this.restored, required this.failures});
  final int restored;
  final List<MediaRestoreFailure> failures;
}

class MediaRestoreFailure {
  MediaRestoreFailure(this.r2Key, this.reason);
  final String r2Key;
  final String reason;

  @override
  String toString() => '$r2Key: $reason';
}
