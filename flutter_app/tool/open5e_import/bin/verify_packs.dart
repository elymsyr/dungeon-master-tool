// Source ⟷ asset verifier — CLI (offline audit tool, phase **T1**).
//
//   dart run tool/open5e_import/bin/verify_packs.dart --data ../open5e-api-staging/data
//                                                     [--packs assets/open5e_packs]
//                                                     [--only monster,spell,...]
//                                                     [--doc tob,a5e-ag]
//                                                     [--sample 0]
//                                                     [--examples 2]
//                                                     [--markdown]
//                                                     [--allow-disagreements]
//
// Fourth sibling of `audit_packs.dart` (are the fields filled?),
// `dupe_census.dart` (should this entity exist?) and `diff_packs.dart` (what did
// my rebuild change?). This one asks the question none of them can: **does the
// shipped value agree with the fixture it claims to come from?**
//
// The engine, the rule table and the reasoning behind both live in
// `../verify.dart`. This file is argument parsing and the exit code: a
// *disagreement* — both sides carrying a value, and them differing — fails the
// run, because that is a mapping defect. A hole (`absent`) and a fabrication
// (`unsourced`) are reported and do not fail: they are findings for a `B` phase
// and for Stage V, and the corpus has 3,733 of them today.
//
// ignore_for_file: avoid_print
import 'dart:io';

import '../verify.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final dataRoot = opts['data'] ?? '../open5e-api-staging/data';
  final packDir = opts['packs'] ?? 'assets/open5e_packs';

  if (!Directory(dataRoot).existsSync()) {
    stderr.writeln('ERROR: source data root not found: $dataRoot\n'
        'Clone the pinned snapshot first (audit §4 A0).');
    exit(2);
  }
  if (!Directory(packDir).existsSync()) {
    stderr.writeln('ERROR: pack directory not found: $packDir');
    exit(2);
  }

  final VerifyReport report;
  try {
    report = verifyPacks(
      dataRoot: dataRoot,
      packDir: packDir,
      only: _csv(opts['only']),
      docs: _csv(opts['doc']),
      sample: int.tryParse(opts['sample'] ?? '0') ?? 0,
      examples: int.tryParse(opts['examples'] ?? '2') ?? 2,
    );
  } on StateError catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exit(2);
  }

  if (args.contains('--markdown')) {
    report.printMarkdown(dataRoot, packDir);
  } else {
    report.printPlain(dataRoot, packDir);
  }

  final disagreements = report.totals[Verdict.disagree]!;
  if (disagreements > 0 && !args.contains('--allow-disagreements')) {
    stderr.writeln(
        '\nFAIL: $disagreements value(s) disagree with the source fixture.');
    exit(1);
  }
}

Set<String> _csv(String? raw) =>
    (raw ?? '').split(',').where((s) => s.isNotEmpty).toSet();

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
