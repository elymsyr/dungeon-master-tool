import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';

/// Unified content-addressed binary store.
///
/// Tüm cloud kaynaklı binary medya (R2 + Supabase Storage free-media +
/// transient + offline kullanım için indirilen herhangi bir asset) tek
/// dizinde toplanır: `AppPaths.cacheDir/content/{sha256}.bin`. Her bayt
/// blob'un yanında `{sha256}.json` sidecar metadata dosyası bulunur:
/// kaynağı (`sourceUri`), kind, oluşturma+son erişim zamanı, boyut.
///
/// Bu store F1'in temel altyapısıdır. Sonraki fazlar:
/// - F2/F3 [ReferenceGraph] meta'daki sourceUri'yi indeksleyecek.
/// - F4 [EvictionSweeper] orphan ve LRU temizliği için meta'yı kullanacak.
/// - F5 FetchQueue cache miss'lerini buraya yazacak.
///
/// **Lazy migration**: eski `cacheDir/r2/assets/{sha}.bin` ve
/// `cacheDir/free_media/{sha}.bin` cache'leri ilk okunduğunda yeni store'a
/// kopyalanır (atomic). Eski dizinler kasıtlı olarak silinmez — F1
/// rollback'i için 30 gün boyunca dokunulmaz; ileride [pruneLegacyDirs]
/// çağrısı ile temizlenir.
class ContentStore {
  ContentStore(this._root, {List<Directory>? legacyDirs})
      : _legacyDirs = legacyDirs ?? const [];

  final Directory _root;
  final List<Directory> _legacyDirs;

  Directory get root => _root;

  File binFor(String sha) => File(p.join(_root.path, '${_sanitize(sha)}.bin'));
  File _metaFor(String sha) =>
      File(p.join(_root.path, '${_sanitize(sha)}.json'));

  /// Cache hit'te File döner ve [touch=true] ise `lastAccessAt` günceller.
  /// Cache miss'te legacy dizinleri kontrol eder; orada varsa **kopyalayıp**
  /// yeni store'a taşır (atomic) ve File döner. Tamamen yoksa null.
  Future<File?> read(String sha, {bool touch = true}) async {
    final bin = binFor(sha);
    if (await bin.exists()) {
      if (touch) {
        // best-effort — meta yoksa sessizce geç
        unawaited(_touch(sha));
      }
      return bin;
    }

    // Legacy fallback — eski cache dizinlerinden taşı.
    for (final legacy in _legacyDirs) {
      final candidate = File(p.join(legacy.path, '${_sanitize(sha)}.bin'));
      if (await candidate.exists()) {
        try {
          final bytes = await candidate.readAsBytes();
          if (sha256.convert(bytes).toString() != sha.toLowerCase()) {
            // Bozuk legacy dosya — sıradakine bak
            continue;
          }
          await write(
            sha,
            bytes,
            ContentMetadata(
              sha: sha,
              sourceUri: null,
              kind: null,
              sizeBytes: bytes.length,
              createdAt: DateTime.now(),
              lastAccessAt: DateTime.now(),
              legacyMigrated: true,
            ),
          );
          return bin;
        } catch (_) {
          // okunamazsa sıradaki legacy dizinine geç
        }
      }
    }

    return null;
  }

  /// Atomic write: önce `.tmp`'e yaz, sonra rename. Meta sidecar ayrıca yazılır.
  ///
  /// SHA doğrulaması ZORUNLU. Caller [bytes]'ın gerçek SHA'sının [sha]
  /// olduğundan emin olmalı; store ayrıca doğrular ve mismatch'te exception.
  Future<File> write(
    String sha,
    Uint8List bytes,
    ContentMetadata metadata,
  ) async {
    final actual = sha256.convert(bytes).toString();
    if (actual != sha.toLowerCase()) {
      throw ContentStoreException(
        'sha_mismatch',
        'expected=$sha actual=$actual',
      );
    }
    final bin = binFor(sha);
    await bin.parent.create(recursive: true);
    final tmp = File('${bin.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await bin.exists()) {
      // Atomic replace — Dart File.rename hedef varsa overwrite eder.
    }
    await tmp.rename(bin.path);
    await _writeMeta(sha, metadata);
    return bin;
  }

  /// Bin + meta sidecar'ı sil. Dosyalar yoksa sessizce geç.
  Future<void> delete(String sha) async {
    final bin = binFor(sha);
    final meta = _metaFor(sha);
    if (await bin.exists()) {
      try {
        await bin.delete();
      } catch (_) {}
    }
    if (await meta.exists()) {
      try {
        await meta.delete();
      } catch (_) {}
    }
  }

  /// SHA için meta'yı oku. Bin var meta yoksa null (legacy migrate sırasında
  /// nadir olabilir).
  Future<ContentMetadata?> metadataFor(String sha) async {
    final meta = _metaFor(sha);
    if (!await meta.exists()) return null;
    try {
      final raw = await meta.readAsString();
      return ContentMetadata.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sadece `lastAccessAt`'i bugüne çek. Meta yoksa atom oluşturmaz —
  /// touch yalnız mevcut girdiler için anlamlı.
  Future<void> touchAccess(String sha) => _touch(sha);

  Future<void> _touch(String sha) async {
    final m = await metadataFor(sha);
    if (m == null) return;
    await _writeMeta(sha, m.copyWith(lastAccessAt: DateTime.now()));
  }

  Future<void> _writeMeta(String sha, ContentMetadata m) async {
    final f = _metaFor(sha);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(m.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  /// Store'daki tüm girdileri stream eder. Eviction sweeper için.
  Stream<ContentEntry> entries() async* {
    if (!await _root.exists()) return;
    await for (final e in _root.list()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (!name.endsWith('.bin')) continue;
      final sha = name.substring(0, name.length - 4);
      final stat = await e.stat();
      final meta = await metadataFor(sha);
      yield ContentEntry(
        sha: sha,
        file: e,
        sizeBytes: stat.size,
        metadata: meta,
      );
    }
  }

  /// Toplam disk kullanımı (yalnız bin dosyaları, meta küçük sayılmaz).
  Future<int> totalSizeBytes() async {
    if (!await _root.exists()) return 0;
    var total = 0;
    await for (final e in _root.list()) {
      if (e is File && p.basename(e.path).endsWith('.bin')) {
        total += (await e.stat()).size;
      }
    }
    return total;
  }

  /// Belirli SHA için bin dosyası var mı (meta zorunlu değil).
  Future<bool> contains(String sha) => binFor(sha).exists();

  /// Legacy cache dizinlerini sil. F1 rollback penceresi (30 gün) sonrasında
  /// çağrılır. Şimdilik manuel — F4 EvictionSweeper bunu çağırır.
  Future<int> pruneLegacyDirs() async {
    var removed = 0;
    for (final dir in _legacyDirs) {
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
          removed++;
        } catch (_) {}
      }
    }
    return removed;
  }

  static String _sanitize(String sha) {
    // SHA256 hex 64 char [0-9a-f] — path traversal riski yok ama defensive:
    if (!RegExp(r'^[0-9a-fA-F]{1,128}$').hasMatch(sha)) {
      throw ContentStoreException('invalid_sha', sha);
    }
    return sha.toLowerCase();
  }
}

class ContentMetadata {
  ContentMetadata({
    required this.sha,
    required this.sizeBytes,
    required this.createdAt,
    required this.lastAccessAt,
    this.sourceUri,
    this.kind,
    this.legacyMigrated = false,
  });

  /// SHA-256 hex (cache key).
  final String sha;

  /// Bayt boyutu (read-only; write sırasında set edilir).
  final int sizeBytes;

  final DateTime createdAt;
  final DateTime lastAccessAt;

  /// Hangi AssetRef bu bayt-blob'u temsil ediyor: `dmt-asset://...`,
  /// `dmt-public://...`, `dmt-transient://...`. F2 ReferenceGraph ile
  /// orphan tespiti için. Legacy migrate'de null olabilir.
  final String? sourceUri;

  /// `MediaKind.wireName` (örn. `portrait`, `entity_image`, `battle_map`).
  /// F4 EvictionSweeper budget ve istatistik için.
  final String? kind;

  /// Legacy cache dizininden taşınan dosya mı (telemetri için).
  final bool legacyMigrated;

  ContentMetadata copyWith({
    String? sourceUri,
    String? kind,
    DateTime? lastAccessAt,
  }) {
    return ContentMetadata(
      sha: sha,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      lastAccessAt: lastAccessAt ?? this.lastAccessAt,
      sourceUri: sourceUri ?? this.sourceUri,
      kind: kind ?? this.kind,
      legacyMigrated: legacyMigrated,
    );
  }

  Map<String, dynamic> toJson() => {
        'sha': sha,
        'size': sizeBytes,
        'created_at': createdAt.toIso8601String(),
        'last_access_at': lastAccessAt.toIso8601String(),
        if (sourceUri != null) 'source_uri': sourceUri,
        if (kind != null) 'kind': kind,
        if (legacyMigrated) 'legacy_migrated': true,
      };

  factory ContentMetadata.fromJson(Map<String, dynamic> j) {
    return ContentMetadata(
      sha: j['sha'] as String,
      sizeBytes: (j['size'] as num).toInt(),
      createdAt: DateTime.parse(j['created_at'] as String),
      lastAccessAt: DateTime.parse(j['last_access_at'] as String),
      sourceUri: j['source_uri'] as String?,
      kind: j['kind'] as String?,
      legacyMigrated: (j['legacy_migrated'] as bool?) ?? false,
    );
  }
}

class ContentEntry {
  ContentEntry({
    required this.sha,
    required this.file,
    required this.sizeBytes,
    required this.metadata,
  });

  final String sha;
  final File file;
  final int sizeBytes;
  final ContentMetadata? metadata;
}

class ContentStoreException implements Exception {
  ContentStoreException(this.code, this.detail);
  final String code;
  final String detail;
  @override
  String toString() => 'ContentStoreException($code): $detail';
}

/// Tek paylaşılan store. Cache root: `AppPaths.cacheDir/content/`.
/// Legacy dizinler (`r2/assets`, `free_media`) lazy migrate için tanımlı.
final contentStoreProvider = Provider<ContentStore>((ref) {
  final root = Directory(p.join(AppPaths.cacheDir, 'content'));
  final legacy = <Directory>[
    Directory(p.join(AppPaths.cacheDir, 'r2', 'assets')),
    Directory(p.join(AppPaths.cacheDir, 'free_media')),
  ];
  return ContentStore(root, legacyDirs: legacy);
});
