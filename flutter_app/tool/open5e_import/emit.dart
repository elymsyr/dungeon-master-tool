// Package assembly + asset writer. Produces the `.pkg.json` payload the
// app-side `Open5ePackInstaller` feeds into `PackageRepository.save`.
//
// The payload deliberately ships ONLY `package_name` + `metadata` + `entities`.
// The world_schema / template_id are attached at install time inside the app
// (it embeds the built-in v2 schema), so the asset stays compact and never
// drifts from the live schema definition.
import 'dart:convert';
import 'dart:io';

import 'sources.dart';

class PackResult {
  final SourceDoc doc;
  final Map<String, dynamic> payload;
  final Map<String, int> counts;
  const PackResult(this.doc, this.payload, this.counts);
}

PackResult assemblePack({
  required SourceDoc doc,
  required Map<String, dynamic> entities,
  required String sourceDataRev,
}) {
  final counts = <String, int>{};
  for (final e in entities.values) {
    final slug = (e as Map)['type'] as String;
    counts.update(slug, (n) => n + 1, ifAbsent: () => 1);
  }
  final payload = <String, dynamic>{
    'package_name': doc.packageName,
    'metadata': {
      'title': doc.title,
      'publisher': doc.publisher,
      'license': doc.license,
      'attribution': doc.attribution,
      'game_system': doc.gameSystem,
      'source': doc.title,
      'source_doc_slug': doc.slug,
      'pack_version': '1.0.0',
      'source_data_rev': sourceDataRev,
      'is_srd_overlap': doc.isSrdOverlap,
      'counts': counts,
    },
    'entities': entities,
  };
  return PackResult(doc, payload, counts);
}

void writePack(PackResult r, String outDir) {
  final dir = Directory(outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('$outDir/${r.doc.packageName}.pkg.json');
  // Compact — the payload is machine-read by the installer; minifying keeps the
  // bundled asset small (~40% vs pretty-printed).
  file.writeAsStringSync(jsonEncode(r.payload));
}

void writeUnmappedReport(Map<String, dynamic> report, String outDir) {
  final file = File('$outDir/unmapped_report.json');
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(report));
}

/// Manifest the app reads (via rootBundle) to discover the bundled packs.
void writeManifest(List<PackResult> results, String outDir) {
  final packs = [
    for (final r in results)
      {
        'asset': '${r.doc.packageName}.pkg.json',
        'package_name': r.doc.packageName,
        'title': r.doc.title,
        'publisher': r.doc.publisher,
        'license': r.doc.license,
        'game_system': r.doc.gameSystem,
        'is_srd_overlap': r.doc.isSrdOverlap,
        'counts': r.counts,
      }
  ];
  final file = File('$outDir/manifest.json');
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert({'packs': packs}));
}
