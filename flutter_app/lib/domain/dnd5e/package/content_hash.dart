import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'catalog_entry.dart';
import 'content_entry.dart';
import 'dnd5e_package.dart';

/// Computes `sha256:<hex>` over the package's **content only** (not metadata),
/// in a canonical form so the hash round-trips across serialize/deserialize
/// cycles regardless of insertion order. Per Doc 14 §File Format.
///
/// Canonical form: each entry reduced to a `[key, ...discriminating fields]`
/// tuple, entries sorted by id within each table, tables emitted in a fixed
/// order. `bodyJson` is hashed as-is (already-canonical is the producer's
/// responsibility — matches the "store what you get" stance of Doc 03).
String computeContentHash(Dnd5ePackage pkg) {
  final buf = StringBuffer();

  void catalog(String label, List<CatalogEntry> rows) {
    buf.write('[$label]\n');
    final sorted = [...rows]..sort((a, b) => a.id.compareTo(b.id));
    for (final e in sorted) {
      buf
        ..write(jsonEncode([e.id, e.name, e.bodyJson]))
        ..write('\n');
    }
  }

  catalog('conditions', pkg.conditions);
  catalog('damageTypes', pkg.damageTypes);
  catalog('skills', pkg.skills);
  catalog('sizes', pkg.sizes);
  catalog('creatureTypes', pkg.creatureTypes);
  catalog('alignments', pkg.alignments);
  catalog('languages', pkg.languages);
  catalog('spellSchools', pkg.spellSchools);
  catalog('weaponProperties', pkg.weaponProperties);
  catalog('weaponMasteries', pkg.weaponMasteries);
  catalog('armorCategories', pkg.armorCategories);
  catalog('rarities', pkg.rarities);

  void typed(String label, List<ContentEntry> rows, List Function(ContentEntry) shape) {
    buf.write('[$label]\n');
    final sorted = [...rows]..sort((a, b) => a.id.compareTo(b.id));
    for (final e in sorted) {
      buf
        ..write(jsonEncode(shape(e)))
        ..write('\n');
    }
  }

  typed('spells', pkg.spells,
      (e) => [e.id, e.name, (e as SpellEntry).level, e.schoolId, e.bodyJson]);
  typed('monsters', pkg.monsters,
      (e) => [e.id, e.name, (e as MonsterEntry).statBlockJson]);
  typed(
      'items',
      pkg.items,
      (e) => [
            e.id,
            e.name,
            (e as ItemEntry).itemType,
            e.rarityId ?? '',
            e.bodyJson,
          ]);
  typed('feats', pkg.feats,
      (e) => [e.id, e.name, (e as NamedEntry).bodyJson]);
  typed('backgrounds', pkg.backgrounds,
      (e) => [e.id, e.name, (e as NamedEntry).bodyJson]);
  typed('species', pkg.species,
      (e) => [e.id, e.name, (e as NamedEntry).bodyJson]);
  typed(
      'subclasses',
      pkg.subclasses,
      (e) => [
            e.id,
            e.name,
            (e as SubclassEntry).parentClassId,
            e.bodyJson,
          ]);
  typed('classProgressions', pkg.classProgressions,
      (e) => [e.id, e.name, (e as NamedEntry).bodyJson]);

  final digest = sha256.convert(utf8.encode(buf.toString()));
  return 'sha256:$digest';
}
