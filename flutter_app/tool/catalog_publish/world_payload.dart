// Shared world-payload helpers for the catalog build + publish CLIs.
//
// A bundled world under `assets/worlds/<dir>/` is three JSON files plus a media
// tree. The catalog ships it as ONE gzipped envelope object
// (`catalog/world/<slug>@<ver>.json.gz`) with the media uploaded alongside as
// raw objects under `catalog/world-media/<slug>@<ver>/<rel>`.
//
// build_catalog and publish_catalog MUST agree byte-for-byte on the envelope —
// the builder records its gzipped `size_bytes` in the manifest and the
// publisher uploads it — so the envelope lives here, not in either CLI.
import 'dart:convert';
import 'dart:io';

/// The single catalog payload for a bundled world: its own manifest plus both
/// blueprints, exactly as `BundledWorldsInstaller` reads them off the asset
/// bundle. A missing blueprint is omitted (the installer tolerates either one
/// being absent, but not both).
Map<String, dynamic> buildWorldEnvelope(String worldDirPath) {
  Map<String, dynamic>? read(String name) {
    final f = File('$worldDirPath/$name');
    if (!f.existsSync()) return null;
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  final manifest = read('manifest.json');
  if (manifest == null) {
    throw StateError('$worldDirPath/manifest.json not found');
  }
  final world = read('world-blueprint.json');
  final character = read('blueprint.json');
  if (world == null && character == null) {
    throw StateError('$worldDirPath: no blueprint files');
  }
  return <String, dynamic>{
    'manifest': manifest,
    if (world != null) 'world_blueprint': world,
    if (character != null) 'character_blueprint': character,
  };
}

/// Envelope → the exact bytes uploaded to `r2_path`. Compact (not indented) so
/// the size the builder records matches what the publisher sends.
List<int> encodeWorldEnvelope(Map<String, dynamic> envelope) =>
    gzip.encode(utf8.encode(jsonEncode(envelope)));

/// Every media file in a world manifest's `files` block that belongs on R2.
///
/// Two deliberate exclusions:
///  - `files.pdf_url` — a publisher download link, not a bundled path.
///  - `*.pdf` — the adventure PDF is `all-rights-reserved`; we do not
///    redistribute it from our bucket. The catalog entry carries `pdf_url`
///    instead and the client fetches it from the publisher.
List<String> worldMediaPaths(Object? files) {
  final out = <String>[];
  void walk(Object? node, String? key) {
    if (key == 'pdf_url') return;
    if (node is String) {
      if (node.isEmpty) return;
      if (node.toLowerCase().endsWith('.pdf')) return;
      if (!out.contains(node)) out.add(node);
    } else if (node is List) {
      for (final e in node) {
        walk(e, key);
      }
    } else if (node is Map) {
      node.forEach((k, v) => walk(v, k.toString()));
    }
  }

  walk(files, null);
  return out;
}

/// Content type for a raw media object, by extension. Unknown extensions
/// (`.gcs` GURPS character sheets) fall back to octet-stream.
String contentTypeForMedia(String path) {
  final ext = path.toLowerCase().split('.').last;
  switch (ext) {
    case 'webp':
      return 'image/webp';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'svg':
      return 'image/svg+xml';
    case 'mp3':
      return 'audio/mpeg';
    case 'ogg':
      return 'audio/ogg';
    case 'wav':
      return 'audio/wav';
    case 'json':
    case 'gcs':
      return 'application/json';
    default:
      return 'application/octet-stream';
  }
}
