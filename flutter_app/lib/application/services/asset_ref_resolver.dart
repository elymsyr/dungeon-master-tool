import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';

/// Resolves an [AssetRef] (cloud / public / transient URI veya local path) to
/// an on-disk [File].
///
/// - Local refs → `File(path)` (dosya diskte varsa).
/// - `dmt-asset://` → [AssetService.downloadAsset] (Cloudflare R2, SHA-verified,
///   `cacheDir/r2/assets/` altında cache'li).
/// - `dmt-public://` → [FreeMediaService.resolveFreeMedia] (Supabase Storage
///   `free-media`, SHA-verified, `cacheDir/free_media/` altında cache'li).
/// - `dmt-transient://` → `transient_shares` tablosundan SHA ile `uploader_id`
///   bulunur (RLS çağıranı kendi dünyalarına kısıtlar), sonra
///   [AssetService.downloadTransient] SHA-cache-first indirir.
///
/// Çözülemeyen her durumda (dosya yok, servis offline, download hatası) null.
class AssetRefResolver {
  AssetRefResolver(this._assetService, this._freeMediaService, this._supabase);

  final AssetService? _assetService;
  final FreeMediaService? _freeMediaService;
  final SupabaseClient? _supabase;

  Future<File?> resolve(AssetRef ref) async {
    if (ref.raw.isEmpty) return null;

    if (ref.isLocal) {
      final file = File(ref.localPath!);
      if (await file.exists()) return file;
      return null;
    }

    if (ref.isPublic) {
      return _freeMediaService?.resolveFreeMedia(ref.publicPath!);
    }

    if (ref.isTransient) {
      final sha = ref.transientSha;
      final sb = _supabase;
      final svc = _assetService;
      if (sha == null || sb == null || svc == null) return null;
      try {
        final row = await sb
            .from('transient_shares')
            .select('uploader_id, ext')
            .eq('sha256', sha)
            .limit(1)
            .maybeSingle();
        if (row == null) return null;
        return await svc.downloadTransient(
          sha,
          (row['ext'] as String?) ?? ref.transientExt,
          row['uploader_id'] as String,
        );
      } catch (_) {
        return null;
      }
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
  // Runtime guard for sub-isolates where Supabase.initialize() may not have
  // run yet — reading Supabase.instance.client there asserts.
  SupabaseClient? client;
  if (SupabaseConfig.isConfigured) {
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }
  }
  return AssetRefResolver(
    ref.watch(assetServiceProvider),
    ref.watch(freeMediaServiceProvider),
    client,
  );
});
