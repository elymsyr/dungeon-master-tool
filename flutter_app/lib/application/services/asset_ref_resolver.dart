import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../data/services/first_party_art_service.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../providers/first_party_catalog_provider.dart';
import 'content_ref_index.dart';
import 'content_store.dart';

/// Resolves an [AssetRef] (cloud / public / content URI veya local path) to
/// an on-disk [File].
///
/// - Local refs → `File(path)` (dosya diskte varsa).
/// - `dmt-asset://` → [AssetService.downloadAsset] (Cloudflare R2, SHA-verified,
///   `cacheDir/r2/assets/` altında cache'li).
/// - `dmt-public://` → [FreeMediaService.resolveFreeMedia] (Supabase Storage
///   `free-media`, SHA-verified, `cacheDir/free_media/` altında cache'li).
/// - `dmt-art://` → [FirstPartyArtService] (önce app bundle, sonra R2
///   catalog'un public route'u; `cacheDir/art/` altında cache'li).
/// - `dmt-content://` → cihazdan bağımsız ref (Faz 3.5). Sırayla: içerik
///   store'u (yukarıdaki ortak sha kontrolü), [ContentRefIndex] üzerinden
///   **yerel özgün dosya** (baytlar bu cihazda üretildiyse ağa hiç çıkılmaz),
///   son çare dünyanın bulut medyası (Faz 5d): imzalı URL'le R2'den, oradan
///   store'a. DM'in ikinci cihazı da oyuncu da aynı yolu kullanır.
///
/// Çözülemeyen her durumda (dosya yok, servis offline, download hatası) null.
class AssetRefResolver {
  AssetRefResolver(
    this._assetService,
    this._freeMediaService,
    this._store,
    this._artService,
    this._contentIndex,
  );

  final AssetService? _assetService;
  final FreeMediaService? _freeMediaService;
  final ContentStore _store;
  final FirstPartyArtService _artService;
  final ContentRefIndex _contentIndex;
  final _WorldMediaSigner _signer = _WorldMediaSigner();

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

    // Baytlar zaten içerik-adresli store'da olabilir — daha önce indirilmiş
    // ya da `.dmtz` ile gelmiştir. Servis katmanına hiç uğramadan
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
      return _fetchWorldMedia(sha, ref.contentExt);
    }

    final svc = _assetService;
    if (svc == null) return null;

    try {
      return await svc.downloadAsset(ref.r2Key!);
    } catch (_) {
      return null;
    }
  }

  /// Dünyanın bulut medyasından: imza (toplu) → R2 → store.
  Future<File?> _fetchWorldMedia(String sha, String ext) async {
    final svc = _assetService;
    if (svc == null) return null;
    final url = await _signer.urlFor(sha, svc);
    if (url == null) return null;
    try {
      return await svc.downloadSigned(url, sha, ext);
    } catch (e) {
      debugPrint('AssetRefResolver: $sha indirilemedi: $e');
      return null;
    }
  }
}

/// Bulutta henüz olmayan `dmt-content://` görselinin (DM'in cihazı yüklemeyi
/// bitirmedi, ağ koptu) yeniden deneme beklemesi: 10 sn, iki katına çıkarak
/// en çok 5 dk. Ekranda duran görsel böylece kendiliğinden gelir; yeniden
/// açmak gerekmez.
Duration mediaRetryDelay(int attempt) =>
    Duration(seconds: (10 << attempt.clamp(0, 5)).clamp(10, 300));

/// Aynı anda istenen sha'ları kısa bir pencerede toplayıp tek imza isteğine
/// çevirir: bir kart listesi açılırken onlarca görsel birden çözülüyor, her
/// biri ayrı worker isteği olmasın.
///
/// Bulutta olmayan sha (henüz yüklenmedi / limitin üstünde) kısa süre
/// hatırlanır — liste kaydırılırken her yeniden çizim yeni istek atmasın.
/// [mediaRetryDelay]'in ilk adımından kısa: yeniden deneme önbelleğe takılmasın.
class _WorldMediaSigner {
  static const Duration _window = Duration(milliseconds: 50);
  static const Duration _missTtl = Duration(seconds: 8);
  static const int _max = 100;

  final Map<String, Completer<String?>> _pending = {};
  final Map<String, DateTime> _missUntil = {};
  Timer? _timer;
  AssetService? _svc;

  Future<String?> urlFor(String sha, AssetService svc) {
    final until = _missUntil[sha];
    if (until != null && DateTime.now().isBefore(until)) {
      return Future.value(null);
    }
    _svc = svc;
    _timer ??= Timer(_window, () => unawaited(_flush()));
    return _pending.putIfAbsent(sha, Completer<String?>.new).future;
  }

  Future<void> _flush() async {
    _timer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    final shas = batch.keys.toList();
    for (var i = 0; i < shas.length; i += _max) {
      final part = shas.sublist(i, (i + _max).clamp(0, shas.length));
      var urls = const <String, String>{};
      try {
        urls = await _svc!.signWorldMedia('get', part);
      } catch (e) {
        debugPrint('AssetRefResolver: imza alınamadı (${part.length}): $e');
      }
      final until = DateTime.now().add(_missTtl);
      for (final sha in part) {
        final url = urls[sha];
        if (url == null) _missUntil[sha] = until;
        batch[sha]!.complete(url);
      }
    }
  }
}

final assetRefResolverProvider = Provider<AssetRefResolver>((ref) {
  return AssetRefResolver(
    ref.watch(assetServiceProvider),
    ref.watch(freeMediaServiceProvider),
    ref.watch(contentStoreProvider),
    ref.watch(firstPartyArtServiceProvider),
    ref.watch(contentRefIndexProvider),
  );
});
