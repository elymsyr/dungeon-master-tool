import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/utils/error_format.dart';
import '../../domain/entities/catalog/catalog_entry.dart';

/// Cloudflare Worker base URL — `--dart-define=DMT_WORKER_URL=...` (same const
/// used by `network_providers.dart`). Empty → catalog resolves from the bundled
/// assets only.
const String _workerBaseUrl = String.fromEnvironment('DMT_WORKER_URL');
const String _bundledManifest = 'assets/first_party/manifest.json';

/// Cache-bust version for banner art. The worker serves banners with
/// `Cache-Control: immutable, max-age=1y` under a stable key, so re-uploading
/// new art to the same slug would otherwise keep serving the cached old image
/// for a year. Bump this whenever banners are re-cropped/re-uploaded so the
/// `?v=` query becomes a fresh edge + client cache key.
const int kBannerAssetVersion = 2;

/// Public R2 URL for an official package's card banner
/// (`{worker}/catalog/banners/<slug>.jpg?v=N`), or null when no worker is
/// configured. Banners are NOT bundled (only the built-in template/package
/// covers are) — they download from the cloud, so offline cards fall back to
/// the icon cover. Upload via `cloudflare/upload_banners.sh`, then bump
/// [kBannerAssetVersion].
String? officialBannerUrl(String slug) =>
    (_workerBaseUrl.isEmpty || slug.isEmpty)
        ? null
        : '$_workerBaseUrl/catalog/banners/$slug.jpg?v=$kBannerAssetVersion';

/// Reads the first-party content catalog (official packages) from the R2 worker
/// (`{worker}/catalog/*`), falling back to the bundled `assets/first_party/`
/// source when offline, the worker URL is unset, or a fetch fails. This is the
/// READ side that surfaces the published official packages inside the
/// Marketplace — the WRITE side is the `tool/catalog_publish` CLI.
///
/// Uses native [HttpClient] (no `http`/`dio` dep), mirroring
/// `SoundpackCatalogService`. Unlike that service it never surfaces
/// [OfflineException]: offline always degrades to the bundled catalog so the
/// official packs stay installable without a network.
class FirstPartyCatalogService {
  FirstPartyCatalogService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  static const Duration _timeout = Duration(seconds: 12);

  bool get _hasWorker => _workerBaseUrl.isNotEmpty;

  /// Package catalog entries: online R2 manifest → bundled manifest fallback.
  Future<List<CatalogEntry>> fetchManifest() async {
    String? raw;
    if (_hasWorker) {
      try {
        raw = await _getString(
            Uri.parse('$_workerBaseUrl/catalog/manifest.json'));
      } catch (_) {
        raw = null; // offline / 404 / transient → bundled fallback
      }
    }
    raw ??= await _tryBundled(_bundledManifest);
    if (raw == null) return const [];

    final decoded = jsonDecode(raw);
    final entries = (decoded is Map ? decoded['entries'] : null);
    if (entries is! List) return const [];
    return entries
        .whereType<Map>()
        .map((m) => CatalogEntry.fromJson(m.cast<String, dynamic>()))
        .where((e) => e.itemType == 'package')
        .toList(growable: false);
  }

  /// Resolve an entry's payload: online R2 gz → bundled asset fallback.
  /// Throws [StateError] only when neither source yields a payload.
  Future<Map<String, dynamic>> fetchPayload(CatalogEntry entry) async {
    if (_hasWorker && entry.r2Path.isNotEmpty) {
      try {
        final bytes =
            await _getBytes(Uri.parse('$_workerBaseUrl/catalog/${entry.r2Path}'));
        final jsonStr = utf8.decode(gzip.decode(bytes));
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        // fall through to bundled
      }
    }
    final raw = await _tryBundled(entry.bundledAsset);
    if (raw == null) {
      throw StateError('Catalog payload unavailable: ${entry.slug}');
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Download an official package's banner JPEG from R2, or null when no worker
  /// is configured / offline / missing. Used at install time to materialise the
  /// banner as the local package cover.
  Future<Uint8List?> fetchBanner(String slug) async {
    final url = officialBannerUrl(slug);
    if (url == null) return null;
    try {
      return Uint8List.fromList(await _getBytes(Uri.parse(url)));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryBundled(String asset) async {
    if (asset.isEmpty) return null;
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      return null;
    }
  }

  // ── HTTP helpers (mirror SoundpackCatalogService) ──────────────────────

  Future<HttpClientResponse> _get(Uri uri) async {
    try {
      final req = await _httpClient.getUrl(uri).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
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
