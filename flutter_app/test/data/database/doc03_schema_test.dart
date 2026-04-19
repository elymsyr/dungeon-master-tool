import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for Doc 03 typed Drift tables. Spins up an in-memory database,
/// confirms schema version reports 7 (bumped by Doc 14 InstalledPackages),
/// and exercises insert/select on every new catalog + content table so
/// codegen is verified end-to-end.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion = 7', () {
    expect(db.schemaVersion, 7);
  });

  group('catalog tables empty on fresh create', () {
    test('all Tier 1 catalog tables start empty', () async {
      expect(await db.select(db.conditions).get(), isEmpty);
      expect(await db.select(db.damageTypes).get(), isEmpty);
      expect(await db.select(db.skills).get(), isEmpty);
      expect(await db.select(db.sizes).get(), isEmpty);
      expect(await db.select(db.creatureTypes).get(), isEmpty);
      expect(await db.select(db.alignments).get(), isEmpty);
      expect(await db.select(db.languages).get(), isEmpty);
      expect(await db.select(db.spellSchools).get(), isEmpty);
      expect(await db.select(db.weaponProperties).get(), isEmpty);
      expect(await db.select(db.weaponMasteries).get(), isEmpty);
      expect(await db.select(db.armorCategories).get(), isEmpty);
      expect(await db.select(db.rarities).get(), isEmpty);
    });

    test('all D&D 5e content tables start empty', () async {
      expect(await db.select(db.monsters).get(), isEmpty);
      expect(await db.select(db.spells).get(), isEmpty);
      expect(await db.select(db.items).get(), isEmpty);
      expect(await db.select(db.feats).get(), isEmpty);
      expect(await db.select(db.backgrounds).get(), isEmpty);
      expect(await db.select(db.speciesCatalog).get(), isEmpty);
      expect(await db.select(db.subclasses).get(), isEmpty);
      expect(await db.select(db.classProgressions).get(), isEmpty);
    });
  });

  group('insert + select round-trips', () {
    test('Conditions', () async {
      await db.into(db.conditions).insert(ConditionsCompanion.insert(
            id: 'srd:stunned',
            name: 'Stunned',
            bodyJson: '{}',
            sourcePackageId: 'srd',
          ));
      final row = await (db.select(db.conditions)
            ..where((c) => c.id.equals('srd:stunned')))
          .getSingle();
      expect(row.name, 'Stunned');
      expect(row.sourcePackageId, 'srd');
    });

    test('Spells with level + school columns', () async {
      await db.into(db.spells).insert(SpellsCompanion.insert(
            id: 'srd:fireball',
            name: 'Fireball',
            level: 3,
            schoolId: 'srd:evocation',
            bodyJson: '{}',
          ));
      final row = await (db.select(db.spells)
            ..where((s) => s.id.equals('srd:fireball')))
          .getSingle();
      expect(row.level, 3);
      expect(row.schoolId, 'srd:evocation');
    });

    test('Items with itemType + optional rarity', () async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'srd:longsword',
            name: 'Longsword',
            itemType: 'weapon',
            bodyJson: '{}',
            rarityId: const Value('srd:common'),
          ));
      final row = await (db.select(db.items)
            ..where((i) => i.id.equals('srd:longsword')))
          .getSingle();
      expect(row.itemType, 'weapon');
      expect(row.rarityId, 'srd:common');
    });

    test('SpeciesCatalog uses table name "species"', () async {
      await db.into(db.speciesCatalog).insert(SpeciesCatalogCompanion.insert(
            id: 'srd:human',
            name: 'Human',
            bodyJson: '{}',
          ));
      final row = await (db.select(db.speciesCatalog)
            ..where((s) => s.id.equals('srd:human')))
          .getSingle();
      expect(row.name, 'Human');
    });

    test('Subclasses with parentClassId', () async {
      await db.into(db.subclasses).insert(SubclassesCompanion.insert(
            id: 'srd:evocation_wizard',
            name: 'School of Evocation',
            bodyJson: '{}',
            parentClassId: 'srd:wizard',
          ));
      final row = await (db.select(db.subclasses)
            ..where((s) => s.id.equals('srd:evocation_wizard')))
          .getSingle();
      expect(row.parentClassId, 'srd:wizard');
    });

    test('Monsters with statBlockJson column', () async {
      await db.into(db.monsters).insert(MonstersCompanion.insert(
            id: 'srd:goblin',
            name: 'Goblin',
            statBlockJson: '{"cr":"1/4"}',
          ));
      final row = await (db.select(db.monsters)
            ..where((m) => m.id.equals('srd:goblin')))
          .getSingle();
      expect(row.statBlockJson, contains('1/4'));
    });
  });

  test('uninstall-by-package filter deletes catalog rows', () async {
    for (final id in ['srd:fire', 'srd:cold']) {
      await db.into(db.damageTypes).insert(DamageTypesCompanion.insert(
            id: id,
            name: id.split(':').last,
            bodyJson: '{}',
            sourcePackageId: 'srd',
          ));
    }
    await db.into(db.damageTypes).insert(DamageTypesCompanion.insert(
          id: 'hb:necrotic',
          name: 'Necrotic',
          bodyJson: '{}',
          sourcePackageId: 'homebrew',
        ));
    final removed = await (db.delete(db.damageTypes)
          ..where((t) => t.sourcePackageId.equals('srd')))
        .go();
    expect(removed, 2);
    final remaining = await db.select(db.damageTypes).get();
    expect(remaining.map((r) => r.id), ['hb:necrotic']);
  });
}
