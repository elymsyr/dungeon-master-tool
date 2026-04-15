import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/asset_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';

/// Resolves an [AssetRef] (cloud URI or local path) to an on-disk [File].
///
/// Local refs return `File(path)` when the file exists on disk; cloud refs
/// call into [AssetService.downloadAsset], which is SHA-verified and cached
/// under `cacheDir/r2/assets/`. Returns `null` when the ref cannot be
/// resolved (file missing, asset service offline, download failure).
class AssetRefResolver {
  AssetRefResolver(this._assetService);

  final AssetService? _assetService;

  Future<File?> resolve(AssetRef ref) async {
    if (ref.raw.isEmpty) return null;

    if (ref.isLocal) {
      final file = File(ref.localPath!);
      if (await file.exists()) return file;
      return null;
    }

    final svc = _assetService;
    if (svc == null) return null;

    try {
      return await svc.downloadAsset(ref.r2Key!);
    } catch (_) {
      return null;
    }
  }
}

final assetRefResolverProvider = Provider<AssetRefResolver>((ref) {
  return AssetRefResolver(ref.watch(assetServiceProvider));
});
