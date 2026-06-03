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

  // v1 `Spell.dnd_class` index — the v2 fixtures leave `Spell.classes` empty for
  // most 3rd-party docs, so spells ship with no class link. v1 still carries the
  // comma-string class list per spell name; index it as a fallback for mapSpells.
  final v1ByDoc = _v1ClassIndex(dataRoot);
  final v1Global = <String, String>{};
  for (final pref in _v1GlobalPref) {
    v1ByDoc[pref]?.forEach((k, v) => v1Global.putIfAbsent(k, () => v));
  }

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
      // Doc-scoped v1 link overlays the global fallback so cross-edition name
      // collisions (e.g. Acid Arrow) resolve to this document's class list.
      final mapped = _v1DocForV2[doc.slug];
      final v1ForDoc = <String, String>{
        ...v1Global,
        if (mapped != null && v1ByDoc[mapped] != null) ...v1ByDoc[mapped]!,
      };
      mapSpells(
        pack: pack,
        norm: norm,
        source: doc.title,
        spells: loadFixtures(doc.v2File('Spell.json')),
        v1ClassByName: v1ForDoc,
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

/// v2 document slug → the v1 document slug that holds its `Spell.dnd_class`
/// linkage. Verified by spell-count parity (wz=warlock 43, a5e-ag=a5e 371,
/// toh=toh 91, …). srd-2024/spells-that-dont-suck already carry v2 classes.
const _v1DocForV2 = {
  'deepm': 'dmag',
  'deepmx': 'dmag-e',
  'toh': 'toh',
  'kp': 'kp',
  'wz': 'warlock',
  'a5e-ag': 'a5e',
  'open5e': 'o5e',
  'srd-2014': 'wotc-srd',
};

/// Preference order for the cross-doc global fallback (canonical SRD lists win
/// when a spell name isn't found in its own document's v1 index).
const _v1GlobalPref = [
  'wotc-srd',
  'o5e',
  'a5e',
  'dmag',
  'dmag-e',
  'toh',
  'kp',
  'warlock',
];

/// Build `v1doc → { spellNameLower → dnd_class }` from every `v1/<doc>/Spell.json`
/// under [dataRoot]. Used to recover class tags absent from the v2 fixtures.
Map<String, Map<String, String>> _v1ClassIndex(String dataRoot) {
  final out = <String, Map<String, String>>{};
  final v1 = Directory('$dataRoot${Platform.pathSeparator}v1');
  if (!v1.existsSync()) return out;
  for (final ent in v1.listSync().whereType<Directory>()) {
    final slug = ent.path.split(Platform.pathSeparator).last;
    final spells = loadFixtures('${ent.path}${Platform.pathSeparator}Spell.json');
    if (spells.isEmpty) continue;
    final m = <String, String>{};
    for (final s in spells) {
      final name = (s['name'] as String?)?.trim();
      final dc = (s['dnd_class'] as String?)?.trim();
      if (name != null && name.isNotEmpty && dc != null && dc.isNotEmpty) {
        m[name.toLowerCase()] = dc;
      }
    }
    if (m.isNotEmpty) out[slug] = m;
  }
  return out;
}
