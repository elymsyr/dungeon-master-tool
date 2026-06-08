// First-party catalog manifest builder (offline tool).
//
//   dart run tool/catalog_publish/bin/build_catalog.dart
//
// Emits `assets/first_party/manifest.json` — the index the app reads to browse
// the first-party "Official Content" catalog. Each entry describes one
// installable item (package / world / character / template / sound) and carries
// BOTH a `bundled_asset` (a Flutter asset path used as the offline fallback) and
// an `r2_path` (the gzipped object the publish CLI uploads under R2 `catalog/`),
// so the app works online (R2, fresh + updatable) and offline (bundled) with no
// payload duplicated in the binary.
//
// v1 seeds the catalog from the already-built Open5e packs (the 22
// `assets/open5e_packs/*.pkg.json`) as `package` entries. World / character /
// template / sound entries are appended from `assets/first_party/<type>/*.json`
// hand-authored sources when present (none required to ship).
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _open5eDir = 'assets/open5e_packs';
const _firstPartyDir = 'assets/first_party';
const _bannerCreditsFile =
    'assets/first_party/banners/banner-credits.yaml';
const _catalogVersion = '2026-06-01';

void main(List<String> args) {
  final root = Directory.current.path;
  final open5eManifest = File('$root/$_open5eDir/manifest.json');
  if (!open5eManifest.existsSync()) {
    stderr.writeln('ERROR: $_open5eDir/manifest.json not found — '
        'run build_packs first.');
    exit(2);
  }

  final credits = _bannerCredits(root);
  final entries = <Map<String, dynamic>>[];
  entries.addAll(_packageEntries(root, open5eManifest));
  entries.addAll(_handAuthoredEntries(root));
  // Attach banner artwork attribution (creator + source link) to every entry
  // whose slug has a credit in banner-credits.yaml, so the install dialog can
  // surface a clickable image credit.
  var credited = 0;
  for (final e in entries) {
    final c = credits[e['slug']];
    if (c != null) {
      e['banner_credit'] = c;
      credited++;
    }
  }

  final out = <String, dynamic>{
    'catalog_version': _catalogVersion,
    'entries': entries,
  };
  final dir = Directory('$root/$_firstPartyDir')..createSync(recursive: true);
  final file = File('${dir.path}/manifest.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));

  final byType = <String, int>{};
  for (final e in entries) {
    byType.update(e['item_type'] as String, (n) => n + 1, ifAbsent: () => 1);
  }
  print('Wrote ${file.path}');
  print('  ${entries.length} entr(ies): '
      '${byType.entries.map((e) => "${e.value} ${e.key}").join(", ")}');
  print('  $credited with banner credit');
}

/// Parse `banner-credits.yaml` into `slug -> {creator, link}`. Returns empty
/// when the file is missing so the catalog still builds without it.
Map<String, Map<String, String>> _bannerCredits(String root) {
  final file = File('$root/$_bannerCreditsFile');
  if (!file.existsSync()) return const {};
  final doc = loadYaml(file.readAsStringSync());
  final credits = (doc is YamlMap ? doc['credits'] : null);
  if (credits is! YamlMap) return const {};
  final out = <String, Map<String, String>>{};
  credits.forEach((slug, info) {
    if (info is! YamlMap) return;
    final link = info['link']?.toString().trim() ?? '';
    final creator = info['creator']?.toString().trim() ?? '';
    if (link.isEmpty && creator.isEmpty) return;
    out[slug.toString()] = {
      if (creator.isNotEmpty) 'creator': creator,
      if (link.isNotEmpty) 'link': link,
    };
  });
  return out;
}

/// One `package` catalog entry per Open5e pack, sourced from its `*.pkg.json`
/// metadata. `bundled_asset` reuses the existing open5e asset (no copy);
/// `r2_path` is the versioned, immutable object the publish CLI uploads.
List<Map<String, dynamic>> _packageEntries(String root, File manifest) {
  final json = jsonDecode(manifest.readAsStringSync());
  final packs = (json is Map ? json['packs'] : null);
  if (packs is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final p in packs.whereType<Map>()) {
    final asset = p['asset'] as String;
    final slug = p['package_name'] as String;
    final packFile = File('$root/$_open5eDir/$asset');
    if (!packFile.existsSync()) continue;
    final payload = jsonDecode(packFile.readAsStringSync()) as Map;
    final meta = (payload['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final version = (meta['pack_version'] as String?) ?? '1.0.0';
    out.add({
      'item_type': 'package',
      'slug': slug,
      'title': (meta['title'] as String?) ?? p['title'] ?? slug,
      'version': version,
      'publisher': (meta['publisher'] as String?) ?? p['publisher'] ?? '',
      'license': (meta['license'] as String?) ?? p['license'] ?? '',
      'attribution': (meta['attribution'] as String?) ?? '',
      'game_system': (meta['game_system'] as String?) ?? p['game_system'] ?? '',
      'is_srd_overlap': (meta['is_srd_overlap'] as bool?) ?? false,
      'counts': (p['counts'] as Map?)?.cast<String, dynamic>() ?? const {},
      'bundled_asset': '$_open5eDir/$asset',
      'r2_path': 'package/$slug@$version.json.gz',
      'size_bytes': packFile.lengthSync(),
    });
  }
  return out;
}

/// Hand-authored world / character / template / sound entries, read from
/// `assets/first_party/<type>/*.json`. Each source file is a payload whose
/// sidecar `*.meta.json` (optional) supplies catalog fields; absent fields fall
/// back to filename + sane defaults. Returns empty when no sources exist.
List<Map<String, dynamic>> _handAuthoredEntries(String root) {
  const types = ['world', 'character', 'template', 'sound'];
  final out = <Map<String, dynamic>>[];
  for (final type in types) {
    final dir = Directory('$root/$_firstPartyDir/$type');
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.json') || name.endsWith('.meta.json')) continue;
      final slug = name.substring(0, name.length - '.json'.length);
      final metaFile = File('${dir.path}/$slug.meta.json');
      final meta = metaFile.existsSync()
          ? (jsonDecode(metaFile.readAsStringSync()) as Map)
              .cast<String, dynamic>()
          : <String, dynamic>{};
      final version = (meta['version'] as String?) ?? '1.0.0';
      out.add({
        'item_type': type,
        'slug': slug,
        'title': (meta['title'] as String?) ?? slug,
        'version': version,
        'publisher': (meta['publisher'] as String?) ?? '',
        'license': (meta['license'] as String?) ?? '',
        'attribution': (meta['attribution'] as String?) ?? '',
        'game_system': (meta['game_system'] as String?) ?? '',
        'is_srd_overlap': false,
        'counts': (meta['counts'] as Map?)?.cast<String, dynamic>() ?? const {},
        'bundled_asset': '$_firstPartyDir/$type/$name',
        'r2_path': '$type/$slug@$version.json.gz',
        'size_bytes': f.lengthSync(),
      });
    }
  }
  return out;
}
