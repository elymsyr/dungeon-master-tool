import 'package:drift/native.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Round-trip coverage for [Dnd5eContentDao]: insert a row via the underlying
/// table, read it back through the DAO accessor, confirm shape + missing-id
/// returns null.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('getSpell returns row by id', () async {
    await db.into(db.spells).insert(SpellsCompanion.insert(
          id: 'srd:fireball',
          name: 'Fireball',
          level: 3,
          schoolId: 'srd:evocation',
          bodyJson: '{"level":3}',
        ));

    final row = await db.dnd5eContentDao.getSpell('srd:fireball');
    expect(row, isNotNull);
    expect(row!.name, 'Fireball');
    expect(row.level, 3);
    expect(row.schoolId, 'srd:evocation');
  });

  test('getSpell returns null for missing id', () async {
    final row = await db.dnd5eContentDao.getSpell('srd:nope');
    expect(row, isNull);
  });

  test('getMonster / getItem / getFeat / getBackground round-trip', () async {
    await db.into(db.monsters).insert(MonstersCompanion.insert(
          id: 'srd:goblin',
          name: 'Goblin',
          statBlockJson: '{}',
        ));
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'srd:longsword',
          name: 'Longsword',
          itemType: 'weapon',
          bodyJson: '{}',
        ));
    await db.into(db.feats).insert(FeatsCompanion.insert(
          id: 'srd:alert',
          name: 'Alert',
          bodyJson: '{}',
        ));
    await db.into(db.backgrounds).insert(BackgroundsCompanion.insert(
          id: 'srd:acolyte',
          name: 'Acolyte',
          bodyJson: '{}',
        ));

    expect((await db.dnd5eContentDao.getMonster('srd:goblin'))!.name, 'Goblin');
    expect((await db.dnd5eContentDao.getItem('srd:longsword'))!.itemType,
        'weapon');
    expect((await db.dnd5eContentDao.getFeat('srd:alert'))!.name, 'Alert');
    expect(
        (await db.dnd5eContentDao.getBackground('srd:acolyte'))!.name,
        'Acolyte');
  });

  test('homebrew round-trip via upsert + watchAllHomebrew', () async {
    final stream = db.dnd5eContentDao.watchAllHomebrew();
    expect(await stream.first, isEmpty);

    await db.dnd5eContentDao.upsertHomebrewEntry(HomebrewEntriesCompanion.insert(
      id: 'hb:campaign1:quest-abc',
      categorySlug: 'quest',
      name: 'Find the Artifact',
      bodyJson: '{"status":"open","reward":"200 gp"}',
    ));

    final row =
        await db.dnd5eContentDao.getHomebrewEntry('hb:campaign1:quest-abc');
    expect(row, isNotNull);
    expect(row!.name, 'Find the Artifact');
    expect(row.categorySlug, 'quest');
    expect(row.sourcePackageId, 'homebrew');

    final byCat = await db.dnd5eContentDao.homebrewByCategory('quest');
    expect(byCat, hasLength(1));
  });

  test('watchAllSpells streams insertions', () async {
    final stream = db.dnd5eContentDao.watchAllSpells();
    final first = await stream.first;
    expect(first, isEmpty);

    await db.into(db.spells).insert(SpellsCompanion.insert(
          id: 'srd:magic-missile',
          name: 'Magic Missile',
          level: 1,
          schoolId: 'srd:evocation',
          bodyJson: '{}',
        ));

    final next = await stream.first;
    expect(next, hasLength(1));
    expect(next.first.id, 'srd:magic-missile');
  });
}
