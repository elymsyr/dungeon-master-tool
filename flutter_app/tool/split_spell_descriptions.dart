/// Splits the inline "Cantrip Upgrade:" (cantrips) and "At Higher Levels:"
/// (level 1 spells) suffixes out of `body.description` and into dedicated
/// `body.cantripUpgrade` / `body.higherLevelSlot` fields on the SRD
/// authoring JSON.
///
/// Run from `flutter_app/`:
///
/// ```
/// dart run tool/split_spell_descriptions.dart
/// ```
///
/// After running, re-build the monolith with `tool/build_srd_pkg.dart`.
library;

import 'dart:convert';
import 'dart:io';

const _assetRoot = 'assets/packages/srd_core';

const _jobs = <({String file, String marker, String target})>[
  (
    file: 'spells_cantrips.json',
    marker: 'Cantrip Upgrade:',
    target: 'cantripUpgrade',
  ),
  (
    file: 'spells_1.json',
    marker: 'At Higher Levels:',
    target: 'higherLevelSlot',
  ),
];

void main() {
  for (final job in _jobs) {
    _processFile(job.file, job.marker, job.target);
  }
}

void _processFile(String name, String marker, String target) {
  final path = '$_assetRoot/$name';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('skip: $path (not found)');
    return;
  }

  final raw = file.readAsStringSync();
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  var touched = 0;
  for (final entry in list) {
    final body = (entry['body'] as Map).cast<String, dynamic>();
    final desc = body['description'];
    if (desc is! String) continue;
    final idx = desc.indexOf(marker);
    if (idx < 0) continue;
    body['description'] = desc.substring(0, idx).trim();
    body[target] = desc.substring(idx + marker.length).trim();
    touched++;
  }

  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(list)}\n');
  stdout.writeln('$path: $touched spells updated ($marker → body.$target)');
}
