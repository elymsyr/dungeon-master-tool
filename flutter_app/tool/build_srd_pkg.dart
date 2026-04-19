/// Build the SRD Core monolith from the split authoring assets in
/// `assets/packages/srd_core/` and write
/// `assets/packages/srd_core.dnd5e-pkg.json` plus the content hash report.
///
/// Run from `flutter_app/`:
///
/// ```
/// dart run tool/build_srd_pkg.dart
/// ```
///
/// The split sources stay editable per category; the monolith is what the
/// runtime `SrdBootstrapService` will load from `rootBundle` on first launch.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';

const _packageMeta = <String, String>{
  'id': 'srd-core-1',
  'packageIdSlug': 'srd',
  'name': 'D&D 5e SRD Core Rules',
  'version': '1.0.0',
  'authorId': 'wizards',
  'authorName': 'Wizards of the Coast',
  'sourceLicense': 'CC BY 4.0',
  'description': 'System Reference Document 5.2.1 — released under CC BY 4.0.',
};

const defaultAssetRoot = 'assets/packages/srd_core';
const defaultOutputPath = 'assets/packages/srd_core.dnd5e-pkg.json';

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

BuildResult buildSrdPackage({String assetRoot = defaultAssetRoot}) {
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

  final pkg = Dnd5ePackage(
    id: _packageMeta['id']!,
    packageIdSlug: _packageMeta['packageIdSlug']!,
    name: _packageMeta['name']!,
    version: _packageMeta['version']!,
    authorId: _packageMeta['authorId']!,
    authorName: _packageMeta['authorName']!,
    sourceLicense: _packageMeta['sourceLicense']!,
    description: _packageMeta['description'],
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
  ).namespaced();

  final hash = computeContentHash(pkg);
  final envelope = const Dnd5ePackageCodec().encode(pkg);
  // Stamp the envelope so the importer can verify integrity without
  // recomputing from scratch on every install.
  envelope['contentHash'] = hash;

  return BuildResult(package: pkg, contentHash: hash, envelope: envelope);
}

void main(List<String> args) {
  final outputPath = args.isNotEmpty ? args.first : defaultOutputPath;
  final result = buildSrdPackage();
  File(outputPath).writeAsStringSync(result.toPrettyJson());

  final p = result.package;
  stdout
    ..writeln('Wrote $outputPath')
    ..writeln('contentHash: ${result.contentHash}')
    ..writeln('catalogs:')
    ..writeln('  conditions:       ${p.conditions.length}')
    ..writeln('  damageTypes:      ${p.damageTypes.length}')
    ..writeln('  skills:           ${p.skills.length}')
    ..writeln('  sizes:            ${p.sizes.length}')
    ..writeln('  creatureTypes:    ${p.creatureTypes.length}')
    ..writeln('  alignments:       ${p.alignments.length}')
    ..writeln('  languages:        ${p.languages.length}')
    ..writeln('  spellSchools:     ${p.spellSchools.length}')
    ..writeln('  weaponProperties: ${p.weaponProperties.length}')
    ..writeln('  weaponMasteries:  ${p.weaponMasteries.length}')
    ..writeln('  armorCategories:  ${p.armorCategories.length}')
    ..writeln('  rarities:         ${p.rarities.length}')
    ..writeln('content:')
    ..writeln('  spells:             ${p.spells.length}')
    ..writeln('  monsters:           ${p.monsters.length}')
    ..writeln('  items:              ${p.items.length}')
    ..writeln('  feats:              ${p.feats.length}')
    ..writeln('  backgrounds:        ${p.backgrounds.length}')
    ..writeln('  species:            ${p.species.length}')
    ..writeln('  subclasses:         ${p.subclasses.length}')
    ..writeln('  classProgressions:  ${p.classProgressions.length}');
}
