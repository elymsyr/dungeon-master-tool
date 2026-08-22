// Dumps the hand-authored built-in SRD 5.2.1 pack (srd_core) to a `.pkg.json`
// in the same wire shape as the Open5e packs, so the art_gen prompt/grid tools
// can treat it as just another package.
//
//   dart run tool/srd_art_dump/bin/dump_srd.dart <out.pkg.json>
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dump_srd.dart <out.pkg.json>');
    exit(2);
  }
  final pack = buildSrdCorePack();
  final out = <String, dynamic>{
    'package_name': 'dnd5e-srd',
    'metadata': {
      'title': 'D&D 5e SRD (Built-in)',
      'publisher': 'Wizards of the Coast',
      'license': 'CC-BY-4.0',
      'game_system': '5e-2024',
      'source': 'SRD 5.2.1',
      'pack_version': srdCorePackVersion,
      'is_srd_overlap': true,
    },
    'entities': pack.entities,
  };
  File(args.first).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(out));

  final counts = <String, int>{};
  for (final e in pack.entities.values) {
    final t = (e as Map)['type'] as String;
    counts[t] = (counts[t] ?? 0) + 1;
  }
  stderr.writeln('dumped ${pack.entities.length} entities -> ${args.first}');
  stderr.writeln(counts);
}
