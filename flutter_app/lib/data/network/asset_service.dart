import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloudflare R2 asset pipeline — Worker gatekeeper'ı üzerinden upload/download.
///
/// Mimari bkz. docs/ONLINE_REPORT.md §4.3, §7.3, §8.1.
///
/// R2 object key formatı: `{uploader_id}/{campaign_id}/{sha256}.{ext}`
/// - Worker PUT isteklerde key prefix'inin JWT sub'ı ile eşleştiğini doğrular
///   (path traversal savunması).
/// - Download sonrası client SHA-256 doğrulaması yapar; mismatch → cache silinir.
class AssetService {
  AssetService({
    required SupabaseClient supabase,
    required String workerBaseUrl,
    required Directory cacheDir,
    HttpClient? httpClient,
  })  : _supabase = supabase,
        _workerBaseUrl = workerBaseUrl.replaceAll(RegExp(r'/$'), ''),
        _cacheDir = cacheDir,
        _httpClient = httpClient ?? HttpClient();

  final SupabaseClient _supabase;
  final String _workerBaseUrl;
  final Directory _cacheDir;
  final HttpClient _httpClient;

  static const int _maxDownloadRetries = 2;

  /// Per-item upload limiti — cloud_backup_repository_impl.dart'taki
  /// cloudBackupItemSizeLimit ile aynı değer. Worker tarafında MAX_UPLOAD_BYTES
  /// ile de senkron (wrangler.toml).
  static const int maxItemBytes = 10 * 1024 * 1024;

  /// Worker'a upload + `community_assets` metadata insert.
  /// Dönen URI `dmt-asset://{r2_object_key}` — domain event'lerde referans.
  Future<Uri> uploadAsset(
    File file, {
    required String campaignId,
    String? sessionId,
  }) async {
    final user = _requireUser();
    final token = _requireToken();

    if (!await file.exists()) {
      throw AssetServiceException('file_not_found', file.path);
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > maxItemBytes) {
      throw AssetServiceException(
        'too_large',
        '${bytes.length} > $maxItemBytes',
      );
    }
    final sha = sha256.convert(bytes).toString();
    final ext = _extensionOf(file.path);
    final mime = _guessMime(ext);

    final r2Key = '${user.id}/$campaignId/$sha$ext';

    // Dedupe — aynı sha zaten yüklenmişse re-upload yapma.
    final existing = await _supabase
        .from('community_assets')
        .select('r2_object_key')
        .eq('uploader_id', user.id)
        .eq('r2_object_key', r2Key)
        .maybeSingle();
    if (existing != null) {
      return Uri.parse('dmt-asset://$r2Key');
    }

    final uri = Uri.parse('$_workerBaseUrl/assets/$r2Key');

    final req = await _httpClient.putUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(HttpHeaders.contentTypeHeader, mime);
    req.headers.contentLength = bytes.length;
    req.headers.set('X-Content-SHA256', sha);
    req.add(bytes);

    final res = await req.close();
    if (res.statusCode != 200) {
      final body = await _readBody(res);
      if (res.statusCode == 413 && body.contains('quota_exceeded')) {
        throw AssetQuotaExceededException(body);
      }
      throw AssetServiceException('upload_failed_${res.statusCode}', body);
    }
    await res.drain<void>();

    // Metadata insert — RLS policy `uploader_id = auth.uid()` doğrulamayı yapar.
    await _supabase.from('community_assets').insert({
      'id': _uuidV4(),
      'uploader_id': user.id,
      'r2_object_key': r2Key,
      'sha256_hash': sha,
      'mime_type': mime,
      'size_bytes': bytes.length,
      'original_filename': p.basename(file.path),
      'campaign_id': campaignId,
      'session_id': ?sessionId,
    });

    return Uri.parse('dmt-asset://$r2Key');
  }

  /// Cache-first download. SHA-256 doğrulaması yapar; mismatch → cache at + hata.
  Future<File> downloadAsset(String r2Key) async {
    final token = _requireToken();
    final expectedSha = extractShaFromKey(r2Key);
    final cacheFile = _cacheFileFor(expectedSha);

    if (await cacheFile.exists()) {
      final ok = await _verifyFileHash(cacheFile, expectedSha);
      if (ok) return cacheFile;
      await cacheFile.delete();
    }

    await cacheFile.parent.create(recursive: true);

    for (int attempt = 0; attempt <= _maxDownloadRetries; attempt++) {
      try {
        return await _downloadOnce(r2Key, token, cacheFile, expectedSha);
      } on AssetRateLimitException {
        if (attempt == _maxDownloadRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw AssetServiceException('download_failed', r2Key);
  }

  Future<File> _downloadOnce(
    String r2Key,
    String token,
    File cacheFile,
    String expectedSha,
  ) async {
    final uri = Uri.parse('$_workerBaseUrl/assets/$r2Key');
    final req = await _httpClient.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close();

    if (res.statusCode == 429) {
      await res.drain<void>();
      throw AssetRateLimitException();
    }
    if (res.statusCode != 200) {
      final body = await _readBody(res);
      throw AssetServiceException('download_${res.statusCode}', body);
    }

    final sink = cacheFile.openWrite();
    try {
      await res.pipe(sink);
    } catch (_) {
      await sink.close();
      if (await cacheFile.exists()) await cacheFile.delete();
      rethrow;
    }

    final ok = await _verifyFileHash(cacheFile, expectedSha);
    if (!ok) {
      await cacheFile.delete();
      throw AssetServiceException('sha256_mismatch', r2Key);
    }
    return cacheFile;
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

  /// Kullanıcının tüm kampanyalardaki asset metadata'larını listele.
  /// "All worlds" görünümü için kullanılır.
  Future<List<CommunityAssetRow>> listAssetsForUser() async {
    final user = _requireUser();
    final rows = await _supabase
        .from('community_assets')
        .select()
        .eq('uploader_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => CommunityAssetRow.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// R2 object'ini + community_assets row'unu + local cache'i sil.
  /// Worker DELETE + Supabase delete atomic değil — hata durumunda row
  /// kalabilir; sonraki upload dedupe ile aynı row'u döner.
  Future<void> deleteAsset(String r2Key) async {
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

    await evictCache(r2Key);
  }

  Future<void> evictCache(String r2Key) async {
    final sha = extractShaFromKey(r2Key);
    final file = _cacheFileFor(sha);
    if (await file.exists()) await file.delete();
  }

  Future<int> cacheSizeBytes() async {
    final dir = Directory(p.join(_cacheDir.path, 'assets'));
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entry in dir.list()) {
      if (entry is File) {
        total += (await entry.stat()).size;
      }
    }
    return total;
  }

  // ── helpers ────────────────────────────────────────────────────────────

  File _cacheFileFor(String sha256Hex) =>
      File(p.join(_cacheDir.path, 'assets', '$sha256Hex.bin'));

  Future<bool> _verifyFileHash(File file, String expected) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString() == expected.toLowerCase();
  }

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
      return await res.transform(utf8.decoder).join();
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

  static String _guessMime(String ext) {
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
      case '.gz':
        return 'application/gzip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Basit UUID v4. `uuid` paketini import etmemek için el-yapımı.
  /// Burada büyük bir randomness gereksinimi yok — Supabase PK olarak kullanılır.
  static String _uuidV4() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    final bytes = List<int>.generate(16, (i) => (rng >> (i * 2)) & 0xff);
    // Additional entropy from microsecond drift
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] ^= (DateTime.now().microsecondsSinceEpoch >> i) & 0xff;
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
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

/// Worker 413 + `quota_exceeded` döndürdüğünde fırlatılır. Caller, dosyayı
/// local fallback olarak kaydetme kararı için bu exception'ı yakalar.
class AssetQuotaExceededException implements Exception {
  AssetQuotaExceededException(this.detail);
  final String detail;
  @override
  String toString() => 'AssetQuotaExceededException: $detail';
}
