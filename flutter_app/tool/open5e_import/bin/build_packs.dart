// Open5e → content-package transform (offline build tool).
//
//   dart run tool/open5e_import/bin/build_packs.dart \
//       [--data <path-to-open5e-api-staging/data>] \
//       [--out  assets/open5e_packs] \
//       [--rev  <source-data-revision-tag>]
//
// Reads the Open5e v2 fixtures for every registered source document, maps them
// onto the app's package wire format, resolves inter-entity refs, and writes
// one `<package>.pkg.json` per document plus a shared `unmapped_report.json`.
// Fails (exit 1) on any unresolved `_ref` so a broken pack never ships.
//
// ignore_for_file: avoid_print
import 'dart:io';

import '../emit.dart';
import '../loaders.dart';
import '../mappers/chargen.dart';
import '../mappers/item.dart';
import '../mappers/monster.dart';
import '../mappers/spell.dart';
import '../normalize.dart';
import '../refgraph.dart';
import '../sources.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final dataRoot = opts['data'] ??
      '${Directory.current.path}/../open5e-api-staging/data';
  final outDir = opts['out'] ?? 'assets/open5e_packs';
  final rev = opts['rev'] ?? 'staging-2026-05-31';

  if (!Directory(dataRoot).existsSync()) {
    stderr.writeln('ERROR: data root not found: $dataRoot');
    exit(2);
  }

  final norm = Normalizer();
  final docs = sourceDocs(dataRoot);
  final results = <PackResult>[];
  var hadError = false;

  print('Open5e import — ${docs.length} document(s), data=$dataRoot');
  for (final doc in docs) {
    final pack = PackBuilder(doc.packageName);

    if (doc.hasCreatures) {
      mapCreatures(
        pack: pack,
        norm: norm,
        source: doc.title,
        creatures: loadFixtures(doc.v2File('Creature.json')),
        actions: loadFixtures(doc.v2File('CreatureAction.json')),
        attacks: loadFixtures(doc.v2File('CreatureActionAttack.json')),
        traits: loadFixtures(doc.v2File('CreatureTrait.json')),
      );
    }
    if (doc.hasSpells) {
      mapSpells(
        pack: pack,
        norm: norm,
        source: doc.title,
        spells: loadFixtures(doc.v2File('Spell.json')),
      );
    }
    if (doc.hasMagicItems) {
      mapMagicItems(
        pack: pack,
        norm: norm,
        source: doc.title,
        items: loadFixtures(doc.v2File('MagicItem.json')),
      );
    }
    if (doc.hasClasses) {
      mapClasses(
        pack: pack,
        norm: norm,
        source: doc.title,
        classes: loadFixtures(doc.v2File('CharacterClass.json')),
        features: loadFixtures(doc.v2File('ClassFeature.json')),
      );
    }
    if (doc.hasSpecies) {
      mapSpecies(
        pack: pack,
        norm: norm,
        source: doc.title,
        species: loadFixtures(doc.v2File('Species.json')),
        traits: loadFixtures(doc.v2File('SpeciesTrait.json')),
      );
    }
    if (doc.hasBackgrounds) {
      mapBackgrounds(
        pack: pack,
        norm: norm,
        source: doc.title,
        backgrounds: loadFixtures(doc.v2File('Background.json')),
        benefits: loadFixtures(doc.v2File('BackgroundBenefit.json')),
      );
    }
    if (doc.hasFeats) {
      mapFeats(
        pack: pack,
        norm: norm,
        source: doc.title,
        feats: loadFixtures(doc.v2File('Feat.json')),
        benefits: loadFixtures(doc.v2File('FeatBenefit.json')),
      );
    }

    final unresolved = pack.resolveRefs();
    if (unresolved.isNotEmpty) {
      hadError = true;
      stderr.writeln('  ✗ ${doc.packageName}: '
          '${unresolved.length} unresolved refs: ${unresolved.take(10).join(", ")}');
      continue;
    }

    final result = assemblePack(
      doc: doc,
      entities: pack.entities,
      sourceDataRev: rev,
    );
    writePack(result, outDir);
    results.add(result);
    final summary = result.counts.entries
        .map((e) => '${e.value} ${e.key}')
        .join(', ');
    print('  ✓ ${doc.packageName}: $summary  → $outDir/${doc.packageName}.pkg.json');
  }

  writeManifest(results, outDir);
  final report = norm.unmapped.toJson();
  writeUnmappedReport(report, outDir);
  if (norm.unmapped.isEmpty) {
    print('No unmapped lookup values.');
  } else {
    print('Unmapped values logged → $outDir/unmapped_report.json '
        '(${report.length} slug bucket(s)).');
  }

  if (hadError) exit(1);
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    final a = args[i];
    if (a.startsWith('--')) out[a.substring(2)] = args[i + 1];
  }
  return out;
}
