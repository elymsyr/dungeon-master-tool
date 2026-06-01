// First-party catalog publisher (offline tool).
//
//   dart run tool/catalog_publish/bin/publish_catalog.dart \
//       --worker https://dmt-assets.<acct>.workers.dev \
//       [--token <ADMIN_TOKEN>] [--dry-run] [--force]
//
// Reads `assets/first_party/manifest.json`, gzips each entry's bundled payload,
// and uploads it to the worker's admin-gated write route at
// `PUT {worker}/catalog/{r2_path}` (Bearer ADMIN_TOKEN). The manifest itself is
// uploaded LAST as plain JSON at `catalog/manifest.json`, so the index only ever
// points at objects already present. Versioned payload paths
// (`{type}/{slug}@{ver}.json.gz`) are immutable — an already-present object is
// skipped unless `--force`.
//
// Token resolves from `--token` else the `ADMIN_TOKEN` env var. Worker URL from
// `--worker` else the `DMT_WORKER_URL` env var.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final worker = (opts['worker'] ?? Platform.environment['DMT_WORKER_URL'] ?? '')
      .replaceAll(RegExp(r'/+$'), '');
  final token = opts['token'] ?? Platform.environment['ADMIN_TOKEN'] ?? '';
  final dryRun = opts.containsKey('dry-run');
  final force = opts.containsKey('force');

  if (worker.isEmpty) {
    stderr.writeln('ERROR: pass --worker <url> or set DMT_WORKER_URL.');
    exit(2);
  }
  if (!dryRun && token.isEmpty) {
    stderr.writeln('ERROR: pass --token <ADMIN_TOKEN> or set ADMIN_TOKEN '
        '(omit only with --dry-run).');
    exit(2);
  }

  final manifestFile = File('${Directory.current.path}/assets/first_party/manifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('ERROR: assets/first_party/manifest.json not found — '
        'run build_catalog first.');
    exit(2);
  }
  final manifestRaw = manifestFile.readAsStringSync();
  final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
  final entries = (manifest['entries'] as List).cast<Map<String, dynamic>>();

  print('Publishing ${entries.length} entr(ies) → $worker/catalog/'
      '${dryRun ? "  (DRY RUN)" : ""}');

  final client = HttpClient();
  var uploaded = 0, skipped = 0, failed = 0, bytes = 0;
  try {
    for (final e in entries) {
      final r2Path = e['r2_path'] as String;
      final assetPath = e['bundled_asset'] as String?;
      if (assetPath == null) {
        stderr.writeln('  ! ${e['slug']}: no bundled_asset, skipping');
        skipped++;
        continue;
      }
      final src = File('${Directory.current.path}/$assetPath');
      if (!src.existsSync()) {
        stderr.writeln('  ! ${e['slug']}: payload missing ($assetPath)');
        failed++;
        continue;
      }

      if (!force && await _exists(client, '$worker/catalog/$r2Path')) {
        print('  = $r2Path (already present)');
        skipped++;
        continue;
      }

      final gz = gzip.encode(src.readAsBytesSync());
      bytes += gz.length;
      if (dryRun) {
        print('  ~ $r2Path (${_kb(gz.length)}, dry)');
        uploaded++;
        continue;
      }
      final ok = await _put(
          client, '$worker/catalog/$r2Path', token, gz, 'application/gzip');
      if (ok) {
        print('  ✓ $r2Path (${_kb(gz.length)})');
        uploaded++;
      } else {
        failed++;
      }
    }

    // Manifest LAST, plain JSON — never points at a missing object.
    if (!dryRun) {
      final ok = await _put(client, '$worker/catalog/manifest.json', token,
          utf8.encode(manifestRaw), 'application/json');
      print(ok ? '  ✓ manifest.json' : '  ✗ manifest.json FAILED');
      if (!ok) failed++;
    } else {
      print('  ~ manifest.json (dry)');
    }
  } finally {
    client.close(force: true);
  }

  print('Done: $uploaded uploaded, $skipped skipped, $failed failed, '
      '${_kb(bytes)} transferred.');
  if (failed > 0) exit(1);
}

Future<bool> _exists(HttpClient client, String url) async {
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<bool> _put(HttpClient client, String url, String token, List<int> body,
    String contentType) async {
  try {
    final req = await client.putUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    req.add(body);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) return true;
    stderr.writeln('  ✗ PUT $url → ${res.statusCode}: $text');
    return false;
  } catch (e) {
    stderr.writeln('  ✗ PUT $url → $e');
    return false;
  }
}

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[key] = args[++i];
    } else {
      out[key] = '';
    }
  }
  return out;
}
