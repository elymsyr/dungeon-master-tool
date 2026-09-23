import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/content_store.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// Cloudflare R2 asset pipeline — Worker gatekeeper'ı üzerinden upload/download.
///
/// Mimari bkz. docs/media-storage-redesign.md.
///
/// Yazılan iki prefix var; sayılan (`{uploader}/{campaign}/{sha}`) katman
/// kaldırıldı (Phase D) — Worker o prefix'e PUT'u 410 ile reddediyor, GET
/// bir sürüm boyunca çalışmaya devam ediyor:
/// - `worlds/{worldId}/{sha}{ext}` — multiplayer dünyanın medyası (Faz 5d).
///   Baytlar worker'dan geçmez: [signWorldMedia] toplu imza verir, istemci
///   R2 ile doğrudan konuşur ([putSigned], [downloadSigned]).
/// - `pub/{sha}{ext}` — marketplace + karakter medyası, refcount'lu, pinned.
///
/// Download sonrası client SHA-256 doğrulaması yapar; mismatch → cache silinir.
class AssetService {
  AssetService({
    required SupabaseClient supabase,
    required String workerBaseUrl,
    required ContentStore contentStore,
    HttpClient? httpClient,
    Duration stall = const Duration(seconds: 30),
  })  : _supabase = supabase,
        _workerBaseUrl = workerBaseUrl.replaceAll(RegExp(r'/$'), ''),
        _store = contentStore,
        _stall = stall,
        _httpClient = httpClient ?? (HttpClient()..connectionTimeout = stall);

  final SupabaseClient _supabase;
  final String _workerBaseUrl;
  final ContentStore _store;
  final HttpClient _httpClient;

  static const int _maxDownloadRetries = 2;

  /// Bağlantı kurulana, yanıt başlıkları gelene ya da bir sonraki bayt parçası
  /// akana kadar en çok bu kadar beklenir. Sınırsız bekleyen tek bir istek
  /// (yarı açık bağlantı) medya şeridini uygulama kapanana dek kilitliyordu.
  final Duration _stall;


  /// Marketplace yayını için **pinned** upload: `pub/{sha}{ext}`.
  ///
  /// Kullanıcı-prefix'li sayan katmanın aksine key içerik-adreslidir, yani iki
  /// yayıncı aynı görseli yayınlarsa R2'de tek kopya durur. Kapasiteyi ve
  /// refcount'u `pub_asset_reserve` yönetir; `exists=true` dönerse obje zaten
  /// havuzdadır ve **PUT atlanır** (asıl dedup kazancı burada).
  ///
  /// [refKey] refcount sahibi — marketplace için listing id. Listing silinince
  /// `pub_asset_release(refKey)` ile bırakılır; son ref gidince obje düşer.
  ///
  /// Dönen ref `dmt-asset://pub/{sha}{ext}` — kasıtlı olarak mevcut cloud
  /// şeması: resolver/downloader yolu değişmeden çalışır, Worker `pub/` GET'ini
  /// zaten herkese açık servis eder.
  Future<Uri> uploadPub(
    File file, {
    required MediaKind kind,
    required String refKey,
  }) async {
    final token = _requireToken();
    _requireUser();

    if (!await file.exists()) {
      throw AssetServiceException('file_not_found', file.path);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > kind.maxBytes) {
      throw AssetServiceException(
        'too_large',
        '${bytes.length} > ${kind.maxBytes}',
      );
    }
    final sha = sha256.convert(bytes).toString();
    final ext = _extensionOf(file.path);
    final mime = mimeOf(ext);

    final Map<String, dynamic> reserved;
    try {
      reserved = Map<String, dynamic>.from(
        await _supabase.rpc('pub_asset_reserve', params: {
          '_sha': sha,
          '_ext': ext,
          '_bytes': bytes.length,
          '_mime': mime,
          '_ref_key': refKey,
        }) as Map,
      );
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.hint ?? ''}';
      if (msg.contains('pool_full') || msg.contains('pinned_user_full')) {
        throw PinnedQuotaExceededException(msg);
      }
      rethrow;
    }

    final r2Key = reserved['key'] as String? ?? 'pub/$sha$ext';
    if (reserved['exists'] == true) {
      return Uri.parse('${AssetRef.scheme}$r2Key');
    }

    final req = await _httpClient.putUrl(Uri.parse('$_workerBaseUrl/assets/$r2Key'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(HttpHeaders.contentTypeHeader, mime);
    req.headers.contentLength = bytes.length;
    req.headers.set('X-Content-SHA256', sha);
    req.headers.set('X-Asset-Kind', kind.wireName);
    req.add(bytes);

    final res = await req.close();
    if (res.statusCode != 200) {
      final body = await _readBody(res);
      // Rezervasyon durdu ama obje yok — bırak, yoksa refcount sızıntısı olur.
      try {
        await _supabase.rpc('pub_asset_release',
            params: {'_ref_key': refKey, '_sha': sha});
      } catch (_) {}
      throw AssetServiceException('pub_upload_failed_${res.statusCode}', body);
    }
    await res.drain<void>();

    return Uri.parse('${AssetRef.scheme}$r2Key');
  }

  /// [refKey]'in pinned ref'lerini bırakır (sha NULL → hepsi). Son ref
  /// gidince obje havuzdan düşer. Best-effort — çağıran hata yutabilir.
  Future<void> releasePub(String refKey) async {
    await _supabase.rpc('pub_asset_release', params: {'_ref_key': refKey});
  }

  // ── Dünya medyası (Faz 5d) ─────────────────────────────────────────────

  /// Worker'dan toplu imza: [shas] için ~1 saatlik R2 URL'leri. İzni olmayan
  /// sha haritada **yer almaz** (hata değil). `put` yalnız dünyanın sahibine
  /// ve rezerve edilmiş sha'lara ([worldId] zorunlu), `get` dünyanın
  /// üyelerine ve yüklenmiş sha'lara verilir.
  Future<Map<String, String>> signWorldMedia(
    String op,
    List<String> shas, {
    String? worldId,
  }) async {
    final token = _requireToken();
    final req = await _httpClient
        .postUrl(Uri.parse('$_workerBaseUrl/world-media/sign'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({
      'op': op,
      'shas': shas,
      'world_id': ?worldId,
    }));
    final res = await _guard(req, req.close, _stall);
    final body = await _readBody(res);
    if (res.statusCode == 429) throw AssetRateLimitException();
    if (res.statusCode != 200) {
      throw AssetServiceException('sign_${res.statusCode}', body);
    }
    final urls = (jsonDecode(body) as Map)['urls'] as Map? ?? const {};
    return {for (final e in urls.entries) '${e.key}': '${e.value}'};
  }

  /// İmzalı URL'e PUT. `Content-Length` ve `Content-Type` imzaya bağlı:
  /// rezervasyondaki değerlerle birebir aynı gitmeli, yoksa R2 403 döner.
  Future<void> putSigned(
    String url,
    File file, {
    required int bytes,
    required String mime,
  }) async {
    final req = await _httpClient.putUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.contentTypeHeader, mime);
    req.headers.contentLength = bytes;
    // Gönderim tıkanırsa `addStream` de dönmez; süre boya göre — en yavaş
    // 64 KB/sn'lik bir hat kabul.
    final res = await _guard(req, () async {
      await req.addStream(file.openRead());
      return req.close();
    }, _stall + Duration(seconds: bytes ~/ (64 * 1024)));
    if (res.statusCode != 200) {
      throw AssetServiceException('put_${res.statusCode}', await _readBody(res));
    }
    await res.drain<void>().timeout(_stall, onTimeout: () {});
  }

  /// [body] [limit] içinde bitmezse istek iptal edilir: `TimeoutException`.
  Future<T> _guard<T>(
    HttpClientRequest req,
    Future<T> Function() body,
    Duration limit,
  ) =>
      body().timeout(limit, onTimeout: () {
        final e = TimeoutException('${req.method} ${req.uri.host}', limit);
        req.abort(e);
        throw e;
      });

  /// İmzalı URL'den indirip [ContentStore]'a yazar; sha doğrulanır. Ref
  /// `dmt-content://` olarak kaydedilir — kartın satırı da onu taşıyor, yani
  /// önbellek süpürmesi indirileni yetim sanmaz.
  Future<File> downloadSigned(String url, String sha, String ext) =>
      _downloadOnce(Uri.parse(url), null, sha,
          AssetRef.formatContentUri(sha, ext));

  /// Cache-first download. SHA-256 doğrulaması yapar; mismatch → cache at + hata.
  /// Cache hit'te (yeni store veya legacy migrate) zero transfer.
  Future<File> downloadAsset(String r2Key) async {
    final expectedSha = extractShaFromKey(r2Key);

    // Cache önce, token sonra: baytlar bizdeyse oturum/ağ olmadan da dönsün.
    final cached = await _store.read(expectedSha);
    if (cached != null) return cached;

    final token = _requireToken();

    for (int attempt = 0; attempt <= _maxDownloadRetries; attempt++) {
      try {
        return await _downloadOnce(
          Uri.parse('$_workerBaseUrl/assets/$r2Key'),
          token,
          expectedSha,
          'dmt-asset://$r2Key',
        );
      } on AssetRateLimitException {
        if (attempt == _maxDownloadRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw AssetServiceException('download_failed', r2Key);
  }

  /// [token] null ise istek imzalı bir URL'e gidiyor, başlık gerekmez.
  Future<File> _downloadOnce(
    Uri uri,
    String? token,
    String expectedSha,
    String sourceUri,
  ) async {
    final req = await _httpClient.getUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final res = await _guard(req, req.close, _stall);

    if (res.statusCode == 429) {
      await res.drain<void>();
      throw AssetRateLimitException();
    }
    if (res.statusCode != 200) {
      final body = await _readBody(res);
      throw AssetServiceException('download_${res.statusCode}', body);
    }

    // Stream'i baytlara topla — store.write atomic rename + SHA verify yapar.
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(_stall)) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    try {
      return await _store.write(
        expectedSha,
        bytes,
        ContentMetadata(
          sha: expectedSha,
          sizeBytes: bytes.length,
          createdAt: DateTime.now(),
          lastAccessAt: DateTime.now(),
          sourceUri: sourceUri,
        ),
      );
    } on ContentStoreException catch (e) {
      if (e.code == 'sha_mismatch') {
        throw AssetServiceException('sha256_mismatch', sourceUri);
      }
      rethrow;
    }
  }

  /// Kullanıcının bir kampanyaya yüklediği asset metadata'larını listele.
  /// RLS policy `uploader_id = auth.uid()` filtreyi zaten uyguluyor.
  Future<List<CommunityAssetRow>> listAssetsForCampaign(
    String campaignId,
  ) async {
    final user = _requireUser();
    final rows = await _supabase
        .from('community_assets')
        .select()
        .eq('uploader_id', user.id)
        .eq('campaign_id', campaignId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => CommunityAssetRow.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// R2 object'ini + community_assets row'unu sil.
  /// Worker DELETE + Supabase delete atomic değil — hata durumunda row
  /// kalabilir; sonraki upload dedupe ile aynı row'u döner.
  ///
  /// [keepCache] `true` ise local SHA cache KORUNUR — entity silindiğinde
  /// cloud objesi kalkar ama trash'ten restore edilirse resim local'den
  /// render olmaya devam eder (bkz. EntityMediaCleanupService).
  Future<void> deleteAsset(String r2Key, {bool keepCache = false}) async {
    final user = _requireUser();
    final token = _requireToken();

    final uri = Uri.parse('$_workerBaseUrl/assets/$r2Key');
    final req = await _httpClient.deleteUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close();
    if (res.statusCode != 200 && res.statusCode != 404) {
      final body = await _readBody(res);
      throw AssetServiceException('delete_failed_${res.statusCode}', body);
    }
    await res.drain<void>();

    await _supabase
        .from('community_assets')
        .delete()
        .eq('uploader_id', user.id)
        .eq('r2_object_key', r2Key);

    if (!keepCache) await evictCache(r2Key);
  }

  Future<void> evictCache(String r2Key) async {
    final sha = extractShaFromKey(r2Key);
    await _store.delete(sha);
  }

  Future<int> cacheSizeBytes() => _store.totalSizeBytes();

  // ── helpers ────────────────────────────────────────────────────────────

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw AssetServiceException('not_signed_in', '');
    return user;
  }

  String _requireToken() {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw AssetServiceException('no_access_token', '');
    }
    return token;
  }

  Future<String> _readBody(HttpClientResponse res) async {
    try {
      return await res.transform(utf8.decoder).join().timeout(_stall);
    } catch (_) {
      return '';
    }
  }

  /// Key'in son segmentinden sha256 hex'ini çıkarır.
  /// Format: `{user}/{campaign}/{sha256}.{ext}`
  static String extractShaFromKey(String r2Key) {
    final lastSlash = r2Key.lastIndexOf('/');
    final filename = lastSlash >= 0 ? r2Key.substring(lastSlash + 1) : r2Key;
    final dot = filename.indexOf('.');
    final base = dot >= 0 ? filename.substring(0, dot) : filename;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(base)) {
      throw AssetServiceException('invalid_r2_key', r2Key);
    }
    return base.toLowerCase();
  }

  static String _extensionOf(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext.isEmpty ? '.bin' : ext;
  }

  /// Uzantı → MIME. Dünya medyasında rezervasyona yazılan ve PUT'ta gönderilen
  /// değer bu — ikisi aynı fonksiyondan geldiği için imza tutuyor.
  static String mimeOf(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
        return 'audio/ogg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.flac':
        return 'audio/flac';
      case '.gz':
        return 'application/gzip';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}

/// `community_assets` tablosundan okunan tek bir satırın value-object'i.
class CommunityAssetRow {
  CommunityAssetRow({
    required this.id,
    required this.r2Key,
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
    required this.originalFilename,
    required this.campaignId,
  });

  final String id;
  final String r2Key;
  final String sha256;
  final String mimeType;
  final int sizeBytes;
  final String? originalFilename;
  final String? campaignId;

  factory CommunityAssetRow.fromJson(Map<String, dynamic> json) {
    return CommunityAssetRow(
      id: json['id'] as String,
      r2Key: json['r2_object_key'] as String,
      sha256: json['sha256_hash'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      originalFilename: json['original_filename'] as String?,
      campaignId: json['campaign_id'] as String?,
    );
  }
}

class AssetServiceException implements Exception {
  AssetServiceException(this.code, this.detail);
  final String code;
  final String detail;
  @override
  String toString() => 'AssetServiceException($code): $detail';
}

class AssetRateLimitException implements Exception {
  @override
  String toString() => 'AssetRateLimitException';
}

/// R2'nin toplam tavanı (9 GB, dünya medyasıyla ortak) ya da yayıncı payı
/// (500 MB) dolu — yeni marketplace yayını reddedildi. Mevcut listing'ler
/// etkilenmez.
class PinnedQuotaExceededException implements Exception {
  PinnedQuotaExceededException(this.detail);
  final String detail;
  @override
  String toString() => 'PinnedQuotaExceededException: $detail';
}
