/// Build the SRD Core monolith AND the 4-way split from the authoring
/// assets in `assets/packages/srd_core/`:
///
/// - `assets/packages/srd_core.dnd5e-pkg.json` (monolith — legacy)
/// - `assets/packages/srd_rules.dnd5e-pkg.json` (catalogs + feats + backgrounds)
/// - `assets/packages/srd_spells.dnd5e-pkg.json` (spells)
/// - `assets/packages/srd_bestiary.dnd5e-pkg.json` (monsters)
/// - `assets/packages/srd_heroes.dnd5e-pkg.json` (species / lineages / classes / subclasses / items)
///
/// All 4 splits keep `packageIdSlug: 'srd'` so id namespacing stays `srd:*`
/// and cross-package foreign keys (e.g. a spell referencing a spell-school
/// row) remain valid once all packages are installed. Distinct `id` values
/// (`srd-rules-1`, `srd-spells-1`, …) let the importer track install state
/// per envelope.
///
/// Run from `flutter_app/`:
///
/// ```
/// dart run tool/build_srd_pkg.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';

const _monolithMeta = <String, String>{
  'id': 'srd-core-1',
  'packageIdSlug': 'srd',
  'name': 'D&D 5e SRD Core Rules',
  'version': '1.0.0',
  'authorId': 'wizards',
  'authorName': 'Wizards of the Coast',
  'sourceLicense': 'CC BY 4.0',
  'description': 'System Reference Document 5.2.1 — released under CC BY 4.0.',
};

const _splitMeta = <String, Map<String, String>>{
  'rules': {
    'id': 'srd-rules-1',
    'name': 'D&D 5e SRD — Rules',
    'description':
        'Catalogs (conditions, damage types, skills, sizes, spell-schools, '
            'etc.) plus feats and backgrounds. Prerequisite for the other SRD packages.',
  },
  'spells': {
    'id': 'srd-spells-1',
    'name': 'D&D 5e SRD — Spells',
    'description': 'Cantrips through 9th-level spells from the SRD 5.2.1.',
  },
  'bestiary': {
    'id': 'srd-bestiary-1',
    'name': 'D&D 5e SRD — Bestiary',
    'description': 'Monster stat blocks from the SRD 5.2.1.',
  },
  'heroes': {
    'id': 'srd-heroes-1',
    'name': 'D&D 5e SRD — Heroes',
    'description':
        'Species, lineages, classes, subclasses, and items from the SRD 5.2.1.',
  },
};

const defaultAssetRoot = 'assets/packages/srd_core';
const defaultOutputPath = 'assets/packages/srd_core.dnd5e-pkg.json';
const rulesOutputPath = 'assets/packages/srd_rules.dnd5e-pkg.json';
const spellsOutputPath = 'assets/packages/srd_spells.dnd5e-pkg.json';
const bestiaryOutputPath = 'assets/packages/srd_bestiary.dnd5e-pkg.json';
const heroesOutputPath = 'assets/packages/srd_heroes.dnd5e-pkg.json';

const _spellFiles = <String>[
  'spells_cantrips.json',
  'spells_1.json',
  'spells_2.json',
  'spells_3.json',
  'spells_4.json',
  'spells_5.json',
  'spells_6.json',
  'spells_7.json',
  'spells_8.json',
  'spells_9.json',
];

const _featFiles = <String>[
  'feats.json',
  'feats_general.json',
  'feats_fighting_style.json',
  'feats_epic_boon.json',
];

class BuildResult {
  final Dnd5ePackage package;
  final String contentHash;
  final Map<String, Object?> envelope;

  const BuildResult({
    required this.package,
    required this.contentHash,
    required this.envelope,
  });

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(envelope);
}

class _Sources {
  final List<CatalogEntry> conditions;
  final List<CatalogEntry> damageTypes;
  final List<CatalogEntry> skills;
  final List<CatalogEntry> sizes;
  final List<CatalogEntry> creatureTypes;
  final List<CatalogEntry> alignments;
  final List<CatalogEntry> languages;
  final List<CatalogEntry> spellSchools;
  final List<CatalogEntry> weaponProperties;
  final List<CatalogEntry> weaponMasteries;
  final List<CatalogEntry> armorCategories;
  final List<CatalogEntry> rarities;
  final List<SpellEntry> spells;
  final List<MonsterEntry> monsters;
  final List<ItemEntry> items;
  final List<NamedEntry> feats;
  final List<NamedEntry> backgrounds;
  final List<NamedEntry> species;
  final List<SubclassEntry> subclasses;
  final List<NamedEntry> classProgressions;

  _Sources({
    required this.conditions,
    required this.damageTypes,
    required this.skills,
    required this.sizes,
    required this.creatureTypes,
    required this.alignments,
    required this.languages,
    required this.spellSchools,
    required this.weaponProperties,
    required this.weaponMasteries,
    required this.armorCategories,
    required this.rarities,
    required this.spells,
    required this.monsters,
    required this.items,
    required this.feats,
    required this.backgrounds,
    required this.species,
    required this.subclasses,
    required this.classProgressions,
  });
}

_Sources _readSources(String assetRoot) {
  List<Map<String, Object?>> readList(String name) {
    final raw = jsonDecode(File('$assetRoot/$name').readAsStringSync()) as List;
    return raw.map((e) => (e as Map).cast<String, Object?>()).toList();
  }

  Map<String, Object?> bodyOf(Map<String, Object?> m) {
    final v = m['body'];
    if (v is! Map) return const <String, Object?>{};
    return v.cast<String, Object?>();
  }

  CatalogEntry catalogFromMap(Map<String, Object?> m) => CatalogEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        bodyJson: jsonEncode(bodyOf(m)),
      );

  List<CatalogEntry> readCatalog(String file) =>
      readList(file).map(catalogFromMap).toList(growable: false);

  List<SpellEntry> readSpells() {
    final out = <SpellEntry>[];
    for (final file in _spellFiles) {
      for (final m in readList(file)) {
        final body = bodyOf(m);
        out.add(SpellEntry(
          id: m['id'] as String,
          name: m['name'] as String,
          level: body['level'] as int,
          schoolId: body['schoolId'] as String,
          bodyJson: jsonEncode(body),
        ));
      }
    }
    return out;
  }

  List<MonsterEntry> readMonsters() {
    return readList('monsters.json').map((m) {
      return MonsterEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        statBlockJson: jsonEncode(bodyOf(m)),
      );
    }).toList(growable: false);
  }

  List<ItemEntry> readItems() {
    return readList('items.json').map((m) {
      final body = bodyOf(m);
      return ItemEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        itemType: body['t'] as String,
        rarityId: body['rarityId'] as String?,
        bodyJson: jsonEncode(body),
      );
    }).toList(growable: false);
  }

  List<NamedEntry> readNamed(List<String> files) {
    final out = <NamedEntry>[];
    for (final file in files) {
      for (final m in readList(file)) {
        out.add(NamedEntry(
          id: m['id'] as String,
          name: m['name'] as String,
          bodyJson: jsonEncode(bodyOf(m)),
        ));
      }
    }
    return out;
  }

  List<SubclassEntry> readSubclasses() {
    return readList('subclasses.json').map((m) {
      final body = bodyOf(m);
      return SubclassEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        parentClassId: body['parentClassId'] as String,
        bodyJson: jsonEncode(body),
      );
    }).toList(growable: false);
  }

  return _Sources(
    conditions: readCatalog('conditions.json'),
    damageTypes: readCatalog('damage_types.json'),
    skills: readCatalog('skills.json'),
    sizes: readCatalog('sizes.json'),
    creatureTypes: readCatalog('creature_types.json'),
    alignments: readCatalog('alignments.json'),
    languages: readCatalog('languages.json'),
    spellSchools: readCatalog('spell_schools.json'),
    weaponProperties: readCatalog('weapon_properties.json'),
    weaponMasteries: readCatalog('weapon_masteries.json'),
    armorCategories: readCatalog('armor_categories.json'),
    rarities: readCatalog('rarities.json'),
    spells: readSpells(),
    monsters: readMonsters(),
    items: readItems(),
    feats: readNamed(_featFiles),
    backgrounds: readNamed(const ['backgrounds.json']),
    species: readNamed(const ['species.json', 'lineages.json']),
    subclasses: readSubclasses(),
    classProgressions: readNamed(const ['classes.json']),
  );
}

BuildResult _finalize(Dnd5ePackage pkg) {
  final namespaced = pkg.namespaced();
  final hash = computeContentHash(namespaced);
  final envelope = const Dnd5ePackageCodec().encode(namespaced);
  envelope['contentHash'] = hash;
  return BuildResult(package: namespaced, contentHash: hash, envelope: envelope);
}

BuildResult buildSrdPackage({String assetRoot = defaultAssetRoot}) {
  final s = _readSources(assetRoot);
  final pkg = Dnd5ePackage(
    id: _monolithMeta['id']!,
    packageIdSlug: _monolithMeta['packageIdSlug']!,
    name: _monolithMeta['name']!,
    version: _monolithMeta['version']!,
    authorId: _monolithMeta['authorId']!,
    authorName: _monolithMeta['authorName']!,
    sourceLicense: _monolithMeta['sourceLicense']!,
    description: _monolithMeta['description'],
    conditions: s.conditions,
    damageTypes: s.damageTypes,
    skills: s.skills,
    sizes: s.sizes,
    creatureTypes: s.creatureTypes,
    alignments: s.alignments,
    languages: s.languages,
    spellSchools: s.spellSchools,
    weaponProperties: s.weaponProperties,
    weaponMasteries: s.weaponMasteries,
    armorCategories: s.armorCategories,
    rarities: s.rarities,
    spells: s.spells,
    monsters: s.monsters,
    items: s.items,
    feats: s.feats,
    backgrounds: s.backgrounds,
    species: s.species,
    subclasses: s.subclasses,
    classProgressions: s.classProgressions,
  );
  return _finalize(pkg);
}

Map<String, BuildResult> buildSrdSplit({String assetRoot = defaultAssetRoot}) {
  final s = _readSources(assetRoot);

  final rules = Dnd5ePackage(
    id: _splitMeta['rules']!['id']!,
    packageIdSlug: _monolithMeta['packageIdSlug']!,
    name: _splitMeta['rules']!['name']!,
    version: _monolithMeta['version']!,
    authorId: _monolithMeta['authorId']!,
    authorName: _monolithMeta['authorName']!,
    sourceLicense: _monolithMeta['sourceLicense']!,
    description: _splitMeta['rules']!['description']!,
    conditions: s.conditions,
    damageTypes: s.damageTypes,
    skills: s.skills,
    sizes: s.sizes,
    creatureTypes: s.creatureTypes,
    alignments: s.alignments,
    languages: s.languages,
    spellSchools: s.spellSchools,
    weaponProperties: s.weaponProperties,
    weaponMasteries: s.weaponMasteries,
    armorCategories: s.armorCategories,
    rarities: s.rarities,
    feats: s.feats,
    backgrounds: s.backgrounds,
  );

  final spells = Dnd5ePackage(
    id: _splitMeta['spells']!['id']!,
    packageIdSlug: _monolithMeta['packageIdSlug']!,
    name: _splitMeta['spells']!['name']!,
    version: _monolithMeta['version']!,
    authorId: _monolithMeta['authorId']!,
    authorName: _monolithMeta['authorName']!,
    sourceLicense: _monolithMeta['sourceLicense']!,
    description: _splitMeta['spells']!['description']!,
    spells: s.spells,
  );

  final bestiary = Dnd5ePackage(
    id: _splitMeta['bestiary']!['id']!,
    packageIdSlug: _monolithMeta['packageIdSlug']!,
    name: _splitMeta['bestiary']!['name']!,
    version: _monolithMeta['version']!,
    authorId: _monolithMeta['authorId']!,
    authorName: _monolithMeta['authorName']!,
    sourceLicense: _monolithMeta['sourceLicense']!,
    description: _splitMeta['bestiary']!['description']!,
    monsters: s.monsters,
  );

  final heroes = Dnd5ePackage(
    id: _splitMeta['heroes']!['id']!,
    packageIdSlug: _monolithMeta['packageIdSlug']!,
    name: _splitMeta['heroes']!['name']!,
    version: _monolithMeta['version']!,
    authorId: _monolithMeta['authorId']!,
    authorName: _monolithMeta['authorName']!,
    sourceLicense: _monolithMeta['sourceLicense']!,
    description: _splitMeta['heroes']!['description']!,
    items: s.items,
    species: s.species,
    subclasses: s.subclasses,
    classProgressions: s.classProgressions,
  );

  return {
    'rules': _finalize(rules),
    'spells': _finalize(spells),
    'bestiary': _finalize(bestiary),
    'heroes': _finalize(heroes),
  };
}

void _write(String path, BuildResult r) {
  File(path).writeAsStringSync(r.toPrettyJson());
}

void main(List<String> args) {
  final outputPath = args.isNotEmpty ? args.first : defaultOutputPath;

  final monolith = buildSrdPackage();
  _write(outputPath, monolith);

  final splits = buildSrdSplit();
  _write(rulesOutputPath, splits['rules']!);
  _write(spellsOutputPath, splits['spells']!);
  _write(bestiaryOutputPath, splits['bestiary']!);
  _write(heroesOutputPath, splits['heroes']!);

  stdout.writeln('Wrote $outputPath (monolith)');
  stdout.writeln('  contentHash: ${monolith.contentHash}');
  for (final k in const ['rules', 'spells', 'bestiary', 'heroes']) {
    final r = splits[k]!;
    final p = r.package;
    final total = p.conditions.length +
        p.damageTypes.length +
        p.skills.length +
        p.sizes.length +
        p.creatureTypes.length +
        p.alignments.length +
        p.languages.length +
        p.spellSchools.length +
        p.weaponProperties.length +
        p.weaponMasteries.length +
        p.armorCategories.length +
        p.rarities.length +
        p.spells.length +
        p.monsters.length +
        p.items.length +
        p.feats.length +
        p.backgrounds.length +
        p.species.length +
        p.subclasses.length +
        p.classProgressions.length;
    stdout.writeln('Wrote srd_$k.dnd5e-pkg.json ($total entries)');
    stdout.writeln('  contentHash: ${r.contentHash}');
  }
}
