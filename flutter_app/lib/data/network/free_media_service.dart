import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

// SHA-256 doğrulaması artık ContentStore.write içinde — sha import burada
// yalnızca uploadFreeMedia bayt hash'i için kullanılır.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/content_store.dart';
import '../../core/utils/id_gen.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// Ücretsiz medya pipeline'ı — Supabase Storage `free-media` public bucket.
///
/// Karakter portreleri ve world/package kapak resimleri buraya gider; bu
/// içerikler kullanıcının 100MB storage quota'sına SAYILMAZ (`free_media_assets`
/// hiçbir quota toplamına dahil değil — bkz. migration 053).
///
/// `AssetService` (Cloudflare R2) ile aynı şekli izler ama Worker yok:
/// doğrudan Supabase Storage API'si kullanılır. SHA-256 content addressing →
/// aynı içerik = aynı path = re-upload yok.
class FreeMediaService {
  FreeMediaService({
    required SupabaseClient supabase,
    required ContentStore contentStore,
  })  : _supabase = supabase,
        _store = contentStore;

  final SupabaseClient _supabase;
  final ContentStore _store;
  final HttpClient _httpClient = HttpClient();

  static const String _bucket = 'free-media';

  /// Ücretsiz medyayı `free-media` bucket'ına yükler + `free_media_assets`
  /// metadata satırı insert eder. Dönen URI `dmt-public://{path}`.
  ///
  /// [kind] mutlaka `counted == false` olmalıdır (free media).
  Future<Uri> uploadFreeMedia(
    File file, {
    required MediaKind kind,
    String? scopeId,
  }) async {
    assert(!kind.counted, 'uploadFreeMedia yalnızca ücretsiz kind kabul eder');
    final user = _requireUser();

    if (!await file.exists()) {
      throw FreeMediaException('file_not_found', file.path);
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > kind.maxBytes) {
      throw FreeMediaException(
        'too_large',
        '${bytes.length} > ${kind.maxBytes}',
      );
    }

    final sha = sha256.convert(bytes).toString();
    final ext = _extensionOf(file.path);
    final mime = _guessMime(ext);
    final path = '${user.id}/$sha$ext';

    // Dedupe — aynı sha zaten yüklenmişse re-upload yapma.
    final existing = await _supabase
        .from('free_media_assets')
        .select('storage_path')
        .eq('storage_path', path)
        .maybeSingle();
    if (existing != null) {
      await _writeCacheWithMeta(sha, bytes, path, kind);
      return Uri.parse(AssetRef.formatPublicUri(path));
    }

    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );

    // Metadata insert — RLS policy `owner_id = auth.uid()` doğrulamayı yapar.
    await _supabase.from('free_media_assets').insert({
      'id': newId(),
      'owner_id': user.id,
      'storage_path': path,
      'sha256_hash': sha,
      'mime_type': mime,
      'size_bytes': bytes.length,
      'kind': kind.wireName,
      'original_filename': p.basename(file.path),
      'scope_id': ?scopeId,
    });

    // Yüklenen baytları local cache'e de yaz — hemen render edilebilsin.
    await _writeCacheWithMeta(sha, bytes, path, kind);

    return Uri.parse(AssetRef.formatPublicUri(path));
  }

  /// `dmt-public://` ref'in storage path'ini cache-first çözer.
  /// Cache miss'te `free-media` bucket'ından indirir, SHA-doğrular, cache'ler.
  /// Çözülemezse null döner.
  ///
  /// İndirme **public URL** üzerinden yapılır (authenticated `download()`
  /// değil). `free-media` public bucket olduğundan public URL endpoint'i
  /// RLS'i bypass eder → herhangi bir kullanıcının görseli çözülebilir; bu
  /// sayede storage SELECT policy'si owner-scoped kalabilir (cross-user
  /// enumeration kapalı — bkz. migration 058).
  Future<File?> resolveFreeMedia(String publicPath) async {
    final sha = _shaFromPath(publicPath);

    final cached = await _store.read(sha);
    if (cached != null) return cached;

    final Uint8List bytes;
    try {
      final url = _supabase.storage.from(_bucket).getPublicUrl(publicPath);
      bytes = await _downloadPublic(url);
    } catch (_) {
      return null;
    }

    try {
      return await _writeCacheWithMeta(sha, bytes, publicPath, null);
    } on ContentStoreException {
      // SHA mismatch — corrupt download
      return null;
    }
  }

  /// Public URL'den ham baytları indirir. Public bucket → auth header gerekmez.
  Future<Uint8List> _downloadPublic(String url) async {
    final req = await _httpClient.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw FreeMediaException('download_failed_${res.statusCode}', url);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Kullanıcının tüm ücretsiz medyası (galeri "All worlds" görünümü).
  Future<List<FreeMediaAssetRow>> listForUser() async {
    final user = _requireUser();
    final rows = await _supabase
        .from('free_media_assets')
        .select()
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => FreeMediaAssetRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Belirli scope'a (campaign/package id) ait ücretsiz medya.
  Future<List<FreeMediaAssetRow>> listForScope(String scopeId) async {
    final user = _requireUser();
    final rows = await _supabase
        .from('free_media_assets')
        .select()
        .eq('owner_id', user.id)
        .eq('scope_id', scopeId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => FreeMediaAssetRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Storage object'ini + metadata satırını siler.
  ///
  /// [keepCache] `true` ise local SHA cache KORUNUR — entity silindiğinde
  /// cloud objesi kalkar ama trash'ten restore edilirse resim local'den
  /// render olmaya devam eder (bkz. EntityMediaCleanupService).
  Future<void> deleteFreeMedia(
    String publicPath, {
    bool keepCache = false,
  }) async {
    final user = _requireUser();
    await _supabase.storage.from(_bucket).remove([publicPath]);
    await _supabase
        .from('free_media_assets')
        .delete()
        .eq('owner_id', user.id)
        .eq('storage_path', publicPath);
    if (keepCache) return;
    await _store.delete(_shaFromPath(publicPath));
  }

  // ── helpers ────────────────────────────────────────────────────────────

  Future<File> _writeCacheWithMeta(
    String sha,
    Uint8List bytes,
    String publicPath,
    MediaKind? kind,
  ) async {
    return _store.write(
      sha,
      bytes,
      ContentMetadata(
        sha: sha,
        sizeBytes: bytes.length,
        createdAt: DateTime.now(),
        lastAccessAt: DateTime.now(),
        sourceUri: AssetRef.formatPublicUri(publicPath),
        kind: kind?.wireName,
      ),
    );
  }

  /// `{uid}/{sha256}.{ext}` path'inden sha256 hex'ini çıkarır.
  static String _shaFromPath(String path) {
    final lastSlash = path.lastIndexOf('/');
    final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
    final dot = filename.indexOf('.');
    final base = dot >= 0 ? filename.substring(0, dot) : filename;
    return base.toLowerCase();
  }

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw FreeMediaException('not_signed_in', '');
    return user;
  }

  static String _extensionOf(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext.isEmpty ? '.png' : ext;
  }

  static String _guessMime(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.png':
      default:
        return 'image/png';
    }
  }
}

/// `free_media_assets` tablosundan okunan tek satırın value-object'i.
class FreeMediaAssetRow {
  FreeMediaAssetRow({
    required this.id,
    required this.storagePath,
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    required this.originalFilename,
    required this.scopeId,
  });

  final String id;
  final String storagePath;
  final String sha256;
  final String mimeType;
  final int sizeBytes;
  final String kind;
  final String? originalFilename;
  final String? scopeId;

  /// `dmt-public://` ref karşılığı — entity/metadata slot'larında saklanır.
  String get ref => AssetRef.formatPublicUri(storagePath);

  factory FreeMediaAssetRow.fromJson(Map<String, dynamic> json) {
    return FreeMediaAssetRow(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String,
      sha256: json['sha256_hash'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      kind: json['kind'] as String,
      originalFilename: json['original_filename'] as String?,
      scopeId: json['scope_id'] as String?,
    );
  }
}

class FreeMediaException implements Exception {
  FreeMediaException(this.code, this.detail);
  final String code;
  final String detail;
  @override
  String toString() => 'FreeMediaException($code): $detail';
}
