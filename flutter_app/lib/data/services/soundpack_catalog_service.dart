import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/audio/soundpack_catalog.dart';
import 'soundpad_loader.dart';

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

  /// Download every file of [entry], writing each atomically (`.tmp` → rename).
  ///
  /// - [SoundpackKind.theme]: files land under `{soundpadRoot}/{id}/` and the
  ///   self-contained `theme.yaml` is auto-discovered by `loadAllThemes`.
  /// - [SoundpackKind.library]: files land at their declared paths under
  ///   `{soundpadRoot}/` and the pack's ambience/SFX entries are merged into
  ///   `soundpad_library.yaml`.
  ///
  /// [onProgress] reports `(filesDone, filesTotal)`. Returns `(ok, message)`
  /// matching the soundpad result-tuple convention.
  Future<(bool, String)> downloadPack(
    SoundpackCatalogEntry entry,
    String soundpadRoot, {
    void Function(int done, int total)? onProgress,
  }) async {
    final isLibrary = entry.kind == SoundpackKind.library;
    // theme → install under a per-pack dir; library → directly under the root.
    final destRoot = p.normalize(
        isLibrary ? soundpadRoot : p.join(soundpadRoot, entry.id));
    final newFiles = <String>[];
    try {
      await Directory(destRoot).create(recursive: true);

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
        newFiles.add(destPath);

        onProgress?.call(i + 1, total);
      }

      if (isLibrary) {
        final (ok, msg) = await SoundpadLoader.mergeLibraryEntries(
          soundpadRoot,
          entry.entries
              .map((e) => {
                    'category': e.category,
                    'id': e.id,
                    'name': e.name,
                    'file': e.file,
                  })
              .toList(),
        );
        if (!ok) return (false, msg);
      }
      return (true, entry.id);
    } on OfflineException {
      await _cleanup(entry, soundpadRoot, newFiles);
      rethrow;
    } catch (e) {
      _log.e('Soundpack download failed (${entry.id}): $e');
      await _cleanup(entry, soundpadRoot, newFiles);
      if (isOfflineError(e)) throw const OfflineException();
      return (false, e.toString());
    }
  }

  /// Roll back a failed download. Theme packs own their dir, so delete it
  /// wholesale; library packs share the root, so only remove files we wrote.
  Future<void> _cleanup(
    SoundpackCatalogEntry entry,
    String soundpadRoot,
    List<String> writtenFiles,
  ) async {
    try {
      if (entry.kind == SoundpackKind.theme) {
        final dir = Directory(p.join(soundpadRoot, entry.id));
        if (await dir.exists()) await dir.delete(recursive: true);
      } else {
        for (final f in writtenFiles) {
          final file = File(f);
          if (await file.exists()) await file.delete();
        }
      }
    } catch (_) {
      // best-effort — leave partial state rather than crash.
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
