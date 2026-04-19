import 'package:drift/native.dart';
import 'package:dungeon_master_tool/application/dnd5e/package/dnd5e_package_importer.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/custom_effect_registry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/conflict_resolution.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/content_hash.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/dnd5e_package.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

Dnd5ePackage _sample({
  String slug = 'srd',
  String id = 'pkg-srd-uuid',
  String version = '1.0.0',
  List<String> extensions = const [],
}) =>
    Dnd5ePackage(
      id: id,
      packageIdSlug: slug,
      name: 'SRD Core',
      version: version,
      authorId: 'anthropic',
      authorName: 'SRD',
      requiredRuntimeExtensions: extensions,
      conditions: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{}'),
        CatalogEntry(id: 'prone', name: 'Prone', bodyJson: '{}'),
        CatalogEntry(id: 'blinded', name: 'Blinded', bodyJson: '{}'),
      ],
      damageTypes: const [
        CatalogEntry(id: 'fire', name: 'Fire', bodyJson: '{}'),
        CatalogEntry(id: 'cold', name: 'Cold', bodyJson: '{}'),
      ],
      spellSchools: const [
        CatalogEntry(id: 'evocation', name: 'Evocation', bodyJson: '{}'),
      ],
      rarities: const [
        CatalogEntry(id: 'common', name: 'Common', bodyJson: '{}'),
      ],
      spells: const [
        SpellEntry(
          id: 'fireball',
          name: 'Fireball',
          level: 3,
          schoolId: 'evocation',
          bodyJson: '{}',
        ),
      ],
      monsters: const [
        MonsterEntry(
          id: 'goblin',
          name: 'Goblin',
          statBlockJson: '{"cr":"1/4"}',
        ),
      ],
      items: const [
        ItemEntry(
          id: 'longsword',
          name: 'Longsword',
          itemType: 'weapon',
          rarityId: 'common',
          bodyJson: '{}',
        ),
      ],
      feats: const [
        NamedEntry(id: 'alert', name: 'Alert', bodyJson: '{}'),
      ],
      backgrounds: const [
        NamedEntry(id: 'soldier', name: 'Soldier', bodyJson: '{}'),
      ],
      species: const [
        NamedEntry(id: 'human', name: 'Human', bodyJson: '{}'),
      ],
      subclasses: const [
        SubclassEntry(
          id: 'evocation_wizard',
          name: 'School of Evocation',
          parentClassId: 'wizard',
          bodyJson: '{}',
        ),
      ],
    );

class _Ext implements CustomEffectImpl {
  @override
  final String id;
  _Ext(this.id);
}

void main() {
  late AppDatabase db;
  late CustomEffectRegistry reg;
  late Dnd5ePackageImporter importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reg = CustomEffectRegistry();
    importer = Dnd5ePackageImporter(db, reg);
  });

  tearDown(() async => db.close());

  test('imports catalog + entity rows with namespaced ids', () async {
    final res = await importer.import(_sample());
    expect(res, isA<PackageImportSuccess>());
    final report = (res as PackageImportSuccess).report;
    expect(report.count('conditions'), 3);
    expect(report.count('damageTypes'), 2);
    expect(report.count('spells'), 1);
    expect(report.count('monsters'), 1);
    expect(report.count('items'), 1);
    expect(report.count('subclasses'), 1);

    final conds = await db.select(db.conditions).get();
    expect(conds.map((c) => c.id).toSet(),
        {'srd:stunned', 'srd:prone', 'srd:blinded'});
    expect(conds.every((c) => c.sourcePackageId == 'srd'), true);

    final spell = await db.select(db.spells).getSingle();
    expect(spell.id, 'srd:fireball');
    expect(spell.schoolId, 'srd:evocation');
    expect(spell.level, 3);

    final item = await db.select(db.items).getSingle();
    expect(item.id, 'srd:longsword');
    expect(item.rarityId, 'srd:common');

    final sub = await db.select(db.subclasses).getSingle();
    expect(sub.id, 'srd:evocation_wizard');
    expect(sub.parentClassId, 'srd:wizard');

    final installs = await db.select(db.installedPackages).get();
    expect(installs.length, 1);
    expect(installs.single.sourcePackageId, 'pkg-srd-uuid');
    expect(installs.single.packageIdSlug, 'srd');
  });

  test('fails when required runtime extension missing', () async {
    final res =
        await importer.import(_sample(extensions: const ['srd:wish']));
    expect(res, isA<PackageImportError>());
    expect((res as PackageImportError).message, contains('srd:wish'));
  });

  test('passes when runtime extension registered', () async {
    reg.register(_Ext('srd:wish'));
    final res =
        await importer.import(_sample(extensions: const ['srd:wish']));
    expect(res, isA<PackageImportSuccess>());
  });

  test('expectedContentHash mismatch fails import', () async {
    final res = await importer.import(_sample(),
        expectedContentHash: 'sha256:deadbeef');
    expect(res, isA<PackageImportError>());
    expect((res as PackageImportError).message, contains('hash mismatch'));
  });

  test('expectedContentHash match succeeds', () async {
    final pkg = _sample();
    final hash = computeContentHash(pkg.namespaced());
    final res = await importer.import(pkg, expectedContentHash: hash);
    expect(res, isA<PackageImportSuccess>());
  });

  test('overwrite re-install replaces catalog rows', () async {
    await importer.import(_sample());
    // Second install — content changed (two conditions only).
    final upgraded = Dnd5ePackage(
      id: 'pkg-srd-uuid',
      packageIdSlug: 'srd',
      name: 'SRD Core',
      version: '2.0.0',
      authorId: 'anthropic',
      authorName: 'SRD',
      conditions: const [
        CatalogEntry(id: 'stunned', name: 'Stunned', bodyJson: '{"v":2}'),
      ],
    );
    final res = await importer.import(upgraded,
        onConflict: ConflictResolution.overwrite);
    expect(res, isA<PackageImportSuccess>());
    final conds = await db.select(db.conditions).get();
    expect(conds.length, 1);
    expect(conds.single.id, 'srd:stunned');
    expect(conds.single.bodyJson, '{"v":2}');
    // Installed registry keeps only the upgraded row.
    final installs = await db.select(db.installedPackages).get();
    expect(installs.length, 1);
    expect(installs.single.version, '2.0.0');
  });

  test('skip re-install leaves existing rows untouched', () async {
    await importer.import(_sample());
    final upgraded =
        _sample(version: '2.0.0'); // Same sourcePackageId + slug.
    final res = await importer.import(upgraded,
        onConflict: ConflictResolution.skip);
    expect(res, isA<PackageImportSuccess>());
    final warnings =
        (res as PackageImportSuccess).report.warnings;
    expect(warnings.first, contains('already installed'));
    final installs = await db.select(db.installedPackages).get();
    expect(installs.single.version, '1.0.0');
  });

  test('duplicate conflict requires fresh slug — importer reports error', () async {
    await importer.import(_sample());
    final res = await importer.import(_sample(),
        onConflict: ConflictResolution.duplicate);
    expect(res, isA<PackageImportError>());
    expect((res as PackageImportError).message, contains('fresh packageIdSlug'));
  });

  test('validation error short-circuits (no rows written)', () async {
    final bad = Dnd5ePackage(
      id: 'u',
      packageIdSlug: 'srd',
      name: 'n',
      version: '1',
      authorId: 'a',
      authorName: 'A',
      conditions: const [
        CatalogEntry(id: 'stunned', name: 'A', bodyJson: '{}'),
        CatalogEntry(id: 'stunned', name: 'B', bodyJson: '{}'),
      ],
    );
    final res = await importer.import(bad);
    expect(res, isA<PackageImportError>());
    expect(await db.select(db.conditions).get(), isEmpty);
    expect(await db.select(db.installedPackages).get(), isEmpty);
  });
}
