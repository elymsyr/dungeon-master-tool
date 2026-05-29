import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/audio/soundpack_catalog.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Fetches the curated soundpack catalog from GitHub and downloads packs into
/// the local soundpad root. Uses native [HttpClient] (no `http`/`dio` dep),
/// mirroring the download pattern in `AssetService` / `FreeMediaService`.
///
/// Offline / network failures surface as [OfflineException] so the UI collapses
/// them into the single "You're offline" state (see [isOfflineError]).
class SoundpackCatalogService {
  SoundpackCatalogService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  static const Duration _timeout = Duration(seconds: 20);

  /// GET the manifest JSON → list of catalog entries. Throws [OfflineException]
  /// when the network is unreachable.
  Future<List<SoundpackCatalogEntry>> fetchManifest() async {
    final String raw;
    try {
      raw = await _getString(Uri.parse(soundpackManifestUrl));
    } on SoundpackCatalogException catch (e) {
      // Manifest not published yet → show empty catalog, not an error.
      if (e.statusCode == 404) return const [];
      rethrow;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Soundpack manifest is not a JSON object');
    }
    final packs = (decoded['packs'] as List?) ?? const [];
    return packs
        .whereType<Map<String, dynamic>>()
        .map(SoundpackCatalogEntry.fromJson)
        .where((e) => e.isValid)
        .toList(growable: false);
  }

  /// Whether [entry] is already installed (its theme directory exists).
  Future<bool> isInstalled(SoundpackCatalogEntry entry, String soundpadRoot) {
    return Directory(p.join(soundpadRoot, entry.id)).exists();
  }

  /// Download all files of [entry] into `{soundpadRoot}/{id}/`, preserving
  /// relative sub-paths. Each file is written atomically (`.tmp` → rename).
  /// [onProgress] reports `(filesDone, filesTotal)` as it advances.
  /// Returns `(ok, message)` matching the soundpad result-tuple convention.
  Future<(bool, String)> downloadPack(
    SoundpackCatalogEntry entry,
    String soundpadRoot, {
    void Function(int done, int total)? onProgress,
  }) async {
    final destDir = Directory(p.join(soundpadRoot, entry.id));
    final destRoot = p.normalize(destDir.path);
    try {
      await destDir.create(recursive: true);

      final total = entry.files.length;
      onProgress?.call(0, total);

      for (var i = 0; i < entry.files.length; i++) {
        final rel = entry.files[i];
        final destPath = p.normalize(p.join(destRoot, rel));
        // Path-traversal guard — a malformed manifest must not escape the dir.
        if (!p.isWithin(destRoot, destPath)) {
          throw FormatException('Illegal soundpack file path: $rel');
        }

        final url = Uri.parse('${entry.baseUrl}$rel');
        final bytes = await _getBytes(url);

        final outFile = File(destPath);
        await outFile.parent.create(recursive: true);
        final tmp = File('$destPath.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(destPath);

        onProgress?.call(i + 1, total);
      }
      return (true, entry.id);
    } on OfflineException {
      await _cleanup(destDir);
      rethrow;
    } catch (e) {
      _log.e('Soundpack download failed (${entry.id}): $e');
      await _cleanup(destDir);
      if (isOfflineError(e)) throw const OfflineException();
      return (false, e.toString());
    }
  }

  Future<void> _cleanup(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // best-effort — leave partial dir rather than crash.
    }
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────

  Future<HttpClientResponse> _get(Uri uri) async {
    try {
      final req = await _httpClient.getUrl(uri).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        // NOT HttpException — that is matched by isOfflineError, which would
        // mislabel a 404 (manifest not published) as "you're offline".
        throw SoundpackCatalogException(res.statusCode, uri.toString());
      }
      return res;
    } on SocketException {
      throw const OfflineException();
    } on HandshakeException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException();
    }
  }

  Future<String> _getString(Uri uri) async {
    final res = await _get(uri);
    return res.transform(utf8.decoder).join();
  }

  Future<List<int>> _getBytes(Uri uri) async {
    final res = await _get(uri);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

/// Non-2xx HTTP response from the soundpack catalog/CDN. Deliberately distinct
/// from [HttpException] so [isOfflineError] does not mislabel it as offline.
class SoundpackCatalogException implements Exception {
  const SoundpackCatalogException(this.statusCode, this.url);
  final int statusCode;
  final String url;
  @override
  String toString() => 'SoundpackCatalogException($statusCode): $url';
}
