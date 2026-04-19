import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_srd_pkg.dart';

void main() {
  late BuildResult built;

  setUpAll(() {
    built = buildSrdPackage();
  });

  test('builds without throwing on the live SRD assets', () {
    expect(built.package.id, 'srd-core-1');
    expect(built.package.packageIdSlug, 'srd');
    expect(built.package.sourceLicense, 'CC BY 4.0');
  });

  test('all 12 catalogs populated', () {
    final p = built.package;
    expect(p.conditions, isNotEmpty, reason: 'conditions');
    expect(p.damageTypes, isNotEmpty, reason: 'damageTypes');
    expect(p.skills, isNotEmpty, reason: 'skills');
    expect(p.sizes, isNotEmpty, reason: 'sizes');
    expect(p.creatureTypes, isNotEmpty, reason: 'creatureTypes');
    expect(p.alignments, isNotEmpty, reason: 'alignments');
    expect(p.languages, isNotEmpty, reason: 'languages');
    expect(p.spellSchools, isNotEmpty, reason: 'spellSchools');
    expect(p.weaponProperties, isNotEmpty, reason: 'weaponProperties');
    expect(p.weaponMasteries, isNotEmpty, reason: 'weaponMasteries');
    expect(p.armorCategories, isNotEmpty, reason: 'armorCategories');
    expect(p.rarities, isNotEmpty, reason: 'rarities');
  });

  test('content lists populated across every type', () {
    final p = built.package;
    expect(p.spells, isNotEmpty);
    expect(p.monsters, isNotEmpty);
    expect(p.items, isNotEmpty);
    expect(p.feats, isNotEmpty);
    expect(p.backgrounds, isNotEmpty);
    expect(p.species, isNotEmpty);
    expect(p.subclasses, isNotEmpty);
    expect(p.classProgressions, isNotEmpty);
  });

  test('every entry id namespaced under srd:', () {
    final p = built.package;
    final all = <String>[
      ...p.conditions.map((e) => e.id),
      ...p.damageTypes.map((e) => e.id),
      ...p.skills.map((e) => e.id),
      ...p.sizes.map((e) => e.id),
      ...p.creatureTypes.map((e) => e.id),
      ...p.alignments.map((e) => e.id),
      ...p.languages.map((e) => e.id),
      ...p.spellSchools.map((e) => e.id),
      ...p.weaponProperties.map((e) => e.id),
      ...p.weaponMasteries.map((e) => e.id),
      ...p.armorCategories.map((e) => e.id),
      ...p.rarities.map((e) => e.id),
      ...p.spells.map((e) => e.id),
      ...p.monsters.map((e) => e.id),
      ...p.items.map((e) => e.id),
      ...p.feats.map((e) => e.id),
      ...p.backgrounds.map((e) => e.id),
      ...p.species.map((e) => e.id),
      ...p.subclasses.map((e) => e.id),
      ...p.classProgressions.map((e) => e.id),
    ];
    for (final id in all) {
      expect(id, startsWith('srd:'), reason: id);
    }
  });

  test('intra-package refs namespaced (spell.schoolId, subclass.parentClassId)',
      () {
    for (final s in built.package.spells) {
      expect(s.schoolId, startsWith('srd:'), reason: s.id);
    }
    for (final s in built.package.subclasses) {
      expect(s.parentClassId, startsWith('srd:'), reason: s.id);
    }
  });

  test('all ids unique within their table', () {
    void uniq(Iterable<String> ids, String label) {
      final list = ids.toList();
      expect(list.toSet().length, list.length, reason: label);
    }

    final p = built.package;
    uniq(p.conditions.map((e) => e.id), 'conditions');
    uniq(p.spells.map((e) => e.id), 'spells');
    uniq(p.monsters.map((e) => e.id), 'monsters');
    uniq(p.items.map((e) => e.id), 'items');
    uniq(p.feats.map((e) => e.id), 'feats');
    uniq(p.backgrounds.map((e) => e.id), 'backgrounds');
    uniq(p.species.map((e) => e.id), 'species');
    uniq(p.subclasses.map((e) => e.id), 'subclasses');
    uniq(p.classProgressions.map((e) => e.id), 'classProgressions');
  });

  test('contentHash is sha256-prefixed and stable across builds', () {
    final second = buildSrdPackage();
    expect(built.contentHash, startsWith('sha256:'));
    expect(built.contentHash, second.contentHash);
  });

  test('envelope round-trips through Dnd5ePackageCodec.decode', () {
    const codec = Dnd5ePackageCodec();
    final asJson = jsonEncode(built.envelope);
    final decoded =
        codec.decode((jsonDecode(asJson) as Map).cast<String, Object?>());
    expect(decoded.id, built.package.id);
    expect(decoded.packageIdSlug, built.package.packageIdSlug);
    expect(decoded.conditions.length, built.package.conditions.length);
    expect(decoded.spells.length, built.package.spells.length);
    expect(decoded.monsters.length, built.package.monsters.length);
  });

  test('envelope carries top-level contentHash field for importer', () {
    expect(built.envelope['contentHash'], built.contentHash);
  });
}
