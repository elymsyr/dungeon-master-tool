// Relational sanity gate — CLI (offline audit tool, phase **T3**).
//
//   dart run tool/open5e_import/bin/gate_packs.dart [--packs assets/open5e_packs]
//                                                   [--examples 5]
//
// The engine, the rule list and the reasoning behind each rule live in
// `../gate.dart`. This file is argument parsing and the exit code: any violation
// fails the run, because every rule here describes content that is broken rather
// than merely thin. `build_packs` runs the same gate over what it just wrote.
//
// ignore_for_file: avoid_print
import 'dart:io';

import '../gate.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final packDir = opts['packs'] ?? 'assets/open5e_packs';

  if (!Directory(packDir).existsSync()) {
    stderr.writeln('ERROR: pack directory not found: $packDir');
    exit(2);
  }

  final report = gatePackDir(packDir);
  report.printPlain(examples: int.tryParse(opts['examples'] ?? '5') ?? 5);
  if (report.violations.isNotEmpty) {
    stderr.writeln('\nFAIL: ${report.violations.length} relational violation(s) '
        'in $packDir.');
    exit(1);
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq > 0) {
      out[a.substring(2, eq)] = a.substring(eq + 1);
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[a.substring(2)] = args[++i];
    }
  }
  return out;
}
