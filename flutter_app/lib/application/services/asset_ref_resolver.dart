import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../data/services/first_party_art_service.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../providers/first_party_catalog_provider.dart';
import 'content_ref_index.dart';
import 'content_store.dart';

/// Resolves an [AssetRef] (cloud / public / transient URI veya local path) to
/// an on-disk [File].
///
/// - Local refs → `File(path)` (dosya diskte varsa).
/// - `dmt-asset://` → [AssetService.downloadAsset] (Cloudflare R2, SHA-verified,
///   `cacheDir/r2/assets/` altında cache'li).
/// - `dmt-public://` → [FreeMediaService.resolveFreeMedia] (Supabase Storage
///   `free-media`, SHA-verified, `cacheDir/free_media/` altında cache'li).
/// - `dmt-art://` → [FirstPartyArtService] (önce app bundle, sonra R2
///   catalog'un public route'u; `cacheDir/art/` altında cache'li).
/// - `dmt-transient://` → `transient_shares` tablosundan SHA ile `uploader_id`
///   bulunur (RLS çağıranı kendi dünyalarına kısıtlar), sonra
///   [AssetService.downloadTransient] SHA-cache-first indirir.
/// - `dmt-content://` → cihazdan bağımsız ref (Faz 3.5). Sırayla: içerik
///   store'u (yukarıdaki ortak sha kontrolü), [ContentRefIndex] üzerinden
///   **yerel özgün dosya** (baytlar bu cihazda üretildiyse ağa hiç çıkılmaz),
///   son çare transient indirmesi. Çözülemezse [MissingMediaReporter] SHA'yı
///   DM'e bildirir ve DM yükleyince bir sonraki denemede iner.
///
/// Çözülemeyen her durumda (dosya yok, servis offline, download hatası) null.
class AssetRefResolver {
  AssetRefResolver(
    this._assetService,
    this._freeMediaService,
    this._supabase,
    this._store,
    this._artService,
    this._contentIndex,
  );

  final AssetService? _assetService;
  final FreeMediaService? _freeMediaService;
  final SupabaseClient? _supabase;
  final ContentStore _store;
  final FirstPartyArtService _artService;
  final ContentRefIndex _contentIndex;

  Future<File?> resolve(AssetRef ref) async {
    if (ref.raw.isEmpty) return null;

    if (ref.isLocal) {
      final file = File(ref.localPath!);
      if (await file.exists()) return file;
      return null;
    }

    if (ref.isArt) {
      return _artService.resolve(ref.artName!);
    }

    // Baytlar zaten içerik-adresli store'da olabilir — LAN eşlemesi bunları
    // taşıyor, ya da daha önce indirilmiştir. Servis katmanına hiç uğramadan
    // dön: giriş yapılmamış / offline / servis null olan durumlarda da resim
    // açılsın.
    final sha = ref.contentSha;
    if (sha != null) {
      final cached = await _store.read(sha);
      if (cached != null) return cached;
    }

    if (ref.isPublic) {
      return _freeMediaService?.resolveFreeMedia(ref.publicPath!);
    }

    if (ref.isContent) {
      if (sha == null) return null;
      // Baytları bu cihaz üretmişse (DM'in kendi kartı) ağa hiç çıkma.
      final local = await _contentIndex.fileForSha(sha);
      if (local != null) return local;
      return _downloadTransient(sha, ref.contentExt);
    }

    if (ref.isTransient) {
      final tsha = ref.transientSha;
      if (tsha == null) return null;
      return _downloadTransient(tsha, ref.transientExt);
    }

    final svc = _assetService;
    if (svc == null) return null;

    try {
      return await svc.downloadAsset(ref.r2Key!);
    } catch (_) {
      return null;
    }
  }

  /// SHA → transient havuzdan indirme. `uploader_id` ref'te taşınmaz,
  /// `transient_shares` satırından gelir (RLS çağıranı kendi dünyalarına
  /// kısıtlar). `dmt-transient://` ve `dmt-content://` aynı yolu kullanır —
  /// baytların havuza giriş biçimi ikisinde de aynı.
  Future<File?> _downloadTransient(String sha, String fallbackExt) async {
    final sb = _supabase;
    final svc = _assetService;
    if (sb == null || svc == null) return null;
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
        (row['ext'] as String?) ?? fallbackExt,
        row['uploader_id'] as String,
      );
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
    ref.watch(contentStoreProvider),
    ref.watch(firstPartyArtServiceProvider),
    ref.watch(contentRefIndexProvider),
  );
});
