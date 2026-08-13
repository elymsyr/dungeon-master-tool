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
import 'dart:convert';
import 'dart:io';

import '../emit.dart';
import '../gate.dart';
import '../loaders.dart';
import '../mappers/chargen.dart';
import '../mappers/item.dart';
import '../mappers/monster.dart';
import '../mappers/spell.dart';
import '../normalize.dart';
import '../refgraph.dart';
import '../sources.dart';
import '../vocab.dart';

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
  // Upstream Tier-0 vocabulary (audit B9). Read across every document, not per
  // pack: a Tome of Beasts 2 monster speaks `void-speech`, whose fixture lives
  // in `kobold-press/tob/`. Only consulted when the built-in canon misses.
  norm.vocab = Vocabulary.load(dataRoot);
  final docs = sourceDocs(dataRoot);
  final results = <PackResult>[];
  var hadError = false;

  // v1 `Spell.dnd_class` index — the v2 fixtures leave `Spell.classes` empty for
  // most 3rd-party docs, so spells ship with no class link. v1 still carries the
  // comma-string class list per spell name; index it as a fallback for mapSpells.
  // v1 `Monster.*_json` action index (audit B8) — upstream's v2 conversion
  // dropped whole action buckets for some documents. Only consulted for a
  // bucket the v2 fixtures leave empty; see `mapCreatures`.
  final v1Actions = _v1ActionIndex(dataRoot);

  // Class names a spell's `class_refs` softRef can actually land on (audit L3).
  // The built-in pack is in scope in every world (§2.1), so its twelve classes
  // are the safe targets; a tag naming anything else stays a tag only.
  final classPrefix = nameKey('class', '');
  final knownClasses = {
    for (final key in builtinNameIndex())
      if (key.startsWith(classPrefix)) key.substring(classPrefix.length),
  };

  // v1 `Race.json` species index (audit B3) — same gap, same rule: consulted
  // only for a species the v2 fixtures gave zero trait rows.
  final v1Species = _v1SpeciesIndex(dataRoot);

  final v1ByDoc = _v1ClassIndex(dataRoot);
  final v1Global = <String, String>{};
  for (final pref in _v1GlobalPref) {
    v1ByDoc[pref]?.forEach((k, v) => v1Global.putIfAbsent(k, () => v));
  }

  print('Open5e import — ${docs.length} document(s), data=$dataRoot');
  for (final doc in docs) {
    // Skip the Wizards-of-the-Coast SRD documents (SRD 5.1 / 5.2). The app
    // ships its hand-authored built-in "SRD 5.2.1" Core pack instead, so
    // emitting these would duplicate that content. Discovery still surfaces
    // them (the import QA checks map them), they're just never written/shipped.
    if (doc.isSrdOverlap) {
      print('  – ${doc.packageName}: skipped (SRD overlap; built-in pack ships this)');
      continue;
    }
    final pack = PackBuilder(doc.packageName);
    // Third-party vocabulary is seeded into the pack that needs it, never into
    // the built-in schema (audit §2). Rebound per pack so the `{_ref}` the
    // normalizer hands back always points inside the pack being built.
    norm.tier0Seeder = (slug, name) => seedTier0Row(pack, norm.vocab,
        slug: slug, name: name, source: doc.title);

    if (doc.hasCreatures) {
      final v1Doc = _v1DocForCreatures[doc.slug];
      mapCreatures(
        pack: pack,
        norm: norm,
        source: doc.title,
        creatures: loadFixtures(doc.v2File('Creature.json')),
        actions: loadFixtures(doc.v2File('CreatureAction.json')),
        attacks: loadFixtures(doc.v2File('CreatureActionAttack.json')),
        traits: loadFixtures(doc.v2File('CreatureTrait.json')),
        v1Actions: (v1Doc == null ? null : v1Actions[v1Doc]) ?? const {},
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
        knownClasses: knownClasses,
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
        // The level a feature arrives at lives only here (audit B1).
        featureItems: loadFixtures(doc.v2File('ClassFeatureItem.json')),
      );
    }
    if (doc.hasSpecies) {
      final v1SpeciesDoc = _v1DocForSpecies[doc.slug];
      mapSpecies(
        pack: pack,
        norm: norm,
        source: doc.title,
        species: loadFixtures(doc.v2File('Species.json')),
        traits: loadFixtures(doc.v2File('SpeciesTrait.json')),
        // Audit B3 — for a species v2 converted with zero trait rows.
        v1Traits: (v1SpeciesDoc == null ? null : v1Species[v1SpeciesDoc]) ??
            const {},
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

  final merged = mergeOpen5eOriginals(results, outDir, rev);
  writeManifest(merged, outDir);
  final report = norm.unmapped.toJson();
  writeUnmappedReport(report, outDir);
  if (norm.unmapped.isEmpty) {
    print('No unmapped lookup values.');
  } else {
    print('Unmapped values logged → $outDir/unmapped_report.json '
        '(${report.length} slug bucket(s)).');
  }

  // Relational gate (audit T3). The `_ref` check above only proves the refs a
  // pack *has* resolve; this proves it has the ones it must — §3.5's 396
  // actionless tob3 statblocks passed everything else. Runs on what was just
  // written, so a pack that fails here never ships.
  final gate = gatePackDir(outDir);
  gate.printPlain();
  if (gate.violations.isNotEmpty) hadError = true;

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

/// v2 document slug → the v1 document slug holding the same monsters, for the
/// B8 action backfill. Every pair below is verified on the pinned snapshot by
/// monster-count *and* name parity (menagerie 586/586, blackflag 360/360,
/// cc 356/356, tob 391/391, tob2 379/383, tob-2023 405/408, tob3 397/397,
/// taldorei 4/4). The SRD documents are deliberately absent: they are skipped
/// before this point, and `wotc-srd` is not row-parity with `srd-2014` anyway.
const _v1DocForCreatures = {
  'a5e-mm': 'menagerie',
  'bfrd': 'blackflag',
  'ccdx': 'cc',
  'tdcs': 'taldorei',
  'tob': 'tob',
  'tob2': 'tob2',
  'tob-2023': 'tob-2023',
  'tob3': 'tob3',
};

/// v2 document slug → the v1 document holding the same species, for the B3
/// trait recovery. Only the two documents that ship a `Species.json` outside
/// the SRD skip are listed, and both are name-parity on the pinned snapshot
/// (toh 11/11 races, o5e 1/1). Exactly one species needs it — `toh`'s Shade,
/// which v2 converted with zero `SpeciesTrait` rows.
const _v1DocForSpecies = {
  'toh': 'toh',
  'open5e': 'o5e',
};

/// v1 `Race.json` prose column → the v2 trait name it stands in for. `traits`
/// is absent here because it is a multi-trait blob, split on its own headers.
const _v1RaceColumns = {
  'size': 'Size',
  'speed_desc': 'Speed',
  'asi_desc': 'Ability Score Increase',
  'languages': 'Languages',
  'age': 'Age',
  'alignment': 'Alignment',
};

/// Build `v1doc → V1SpeciesIndex` from every `v1/<doc>/Race.json` under
/// [dataRoot]. v1 keeps a race's traits as markdown prose with `***Name.***`
/// headers rather than as rows, so the headers are what turn it back into the
/// `{name, desc}` shape `mapSpecies` already knows how to read.
///
/// The structured columns v1 *does* carry — `size_raw` and `speed_json` — are
/// deliberately **not** read. They are default-filled, not sourced: `size_raw`
/// is `Medium` for all 11 toh races including Derro and Erina, whose own prose
/// says Small, and `speed_json` says 25 for Drow against its own `speed_desc`'s
/// 30. Trusting them would have quietly overwritten seven correct sizes to buy
/// four wrong ones.
Map<String, V1SpeciesIndex> _v1SpeciesIndex(String dataRoot) {
  final out = <String, V1SpeciesIndex>{};
  final v1 = Directory('$dataRoot${Platform.pathSeparator}v1');
  if (!v1.existsSync()) return out;
  for (final ent in v1.listSync().whereType<Directory>()) {
    final slug = ent.path.split(Platform.pathSeparator).last;
    final races = loadFixtures('${ent.path}${Platform.pathSeparator}Race.json');
    if (races.isEmpty) continue;
    final byName = <String, List<Map<String, String>>>{};
    for (final r in races) {
      final name = (r['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final rows = <Map<String, String>>[];
      for (final col in _v1RaceColumns.entries) {
        rows.addAll(_v1TraitRows(r[col.key], fallbackName: col.value));
      }
      // `vision` is one headed trait (Darkvision / Superior Darkvision) and
      // `traits` is every remaining one; both name themselves in the markdown.
      rows.addAll(_v1TraitRows(r['vision'], fallbackName: 'Vision'));
      rows.addAll(_v1TraitRows(r['traits'], fallbackName: 'Trait'));
      if (rows.isNotEmpty) byName[name.toLowerCase()] = rows;
    }
    if (byName.isNotEmpty) out[slug] = byName;
  }
  return out;
}

/// Split a v1 markdown prose column into `{name, desc}` trait rows on its
/// `***Name.***` headers. Text with no header becomes a single row named
/// [fallbackName]; empty or non-string input yields nothing.
List<Map<String, String>> _v1TraitRows(dynamic raw,
    {required String fallbackName}) {
  if (raw is! String) return const [];
  final text = raw.trim();
  if (text.isEmpty) return const [];
  final header = RegExp(r'\*\*\*\s*(.+?)\.?\s*\*\*\*');
  final matches = header.allMatches(text).toList();
  if (matches.isEmpty) {
    return [{'name': fallbackName, 'desc': text}];
  }
  final out = <Map<String, String>>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
    final name = m.group(1)!.trim();
    final desc = text.substring(m.end, end).trim();
    if (name.isEmpty || desc.isEmpty) continue;
    out.add({'name': name, 'desc': desc});
  }
  return out;
}

/// v1 `Monster.*_json` column → the `CreatureAction.action_type` bucket it
/// stands in for.
const _v1ActionColumns = {
  'actions_json': 'ACTION',
  'bonus_actions_json': 'BONUS_ACTION',
  'reactions_json': 'REACTION',
  'legendary_actions_json': 'LEGENDARY_ACTION',
};

/// Build `v1doc → V1ActionIndex` from every `v1/<doc>/Monster.json` under
/// [dataRoot]. The columns hold a JSON *string* of `[{name, desc}, …]`; a
/// malformed or absent column is simply skipped, exactly like `_v1ClassIndex`.
Map<String, V1ActionIndex> _v1ActionIndex(String dataRoot) {
  final out = <String, V1ActionIndex>{};
  final v1 = Directory('$dataRoot${Platform.pathSeparator}v1');
  if (!v1.existsSync()) return out;
  for (final ent in v1.listSync().whereType<Directory>()) {
    final slug = ent.path.split(Platform.pathSeparator).last;
    final monsters =
        loadFixtures('${ent.path}${Platform.pathSeparator}Monster.json');
    if (monsters.isEmpty) continue;
    final byName = <String, Map<String, List<Map<String, String>>>>{};
    for (final m in monsters) {
      final name = (m['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final buckets = <String, List<Map<String, String>>>{};
      for (final col in _v1ActionColumns.entries) {
        final rows = _v1ActionRows(m[col.key]);
        if (rows.isNotEmpty) buckets[col.value] = rows;
      }
      if (buckets.isNotEmpty) byName[name.toLowerCase()] = buckets;
    }
    if (byName.isNotEmpty) out[slug] = byName;
  }
  return out;
}

/// Decode one `*_json` column into `{name, desc}` rows. Accepts the JSON-string
/// form the fixtures use and an already-decoded list, and drops anything that
/// is not an object carrying a non-empty `desc`.
List<Map<String, String>> _v1ActionRows(dynamic raw) {
  dynamic decoded = raw;
  if (raw is String) {
    if (raw.trim().isEmpty) return const [];
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  final out = <Map<String, String>>[];
  for (final e in decoded) {
    if (e is! Map) continue;
    final name = (e['name'] as String?)?.trim() ?? '';
    final desc = (e['desc'] as String?)?.trim() ?? '';
    if (name.isEmpty || desc.isEmpty) continue;
    out.add({'name': name, 'desc': desc});
  }
  return out;
}

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
