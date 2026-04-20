import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:dungeon_master_tool/application/dnd5e/content/copy_on_write_helper.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the copy-on-write save path: editing an SRD spell must fork
/// a new `hb:` row while leaving the original SRD row untouched; editing
/// an already-homebrew row must upsert in place.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seedSrdFireball() async {
    await db.into(db.spells).insert(SpellsCompanion.insert(
          id: 'srd:fireball',
          name: 'Fireball',
          level: 3,
          schoolId: 'srd:evocation',
          bodyJson: '{"level":3}',
          sourcePackageId: const Value('srd'),
          installedPackageId: const Value('install:srd-spells-1'),
        ));
  }

  test('resolveWriteId forks srd -> hb', () {
    final id = resolveWriteId(
        currentId: 'srd:fireball', activeCampaignId: 'w1');
    expect(id, matches(r'^hb:w1:[0-9a-f-]{36}$'));
  });

  test('resolveWriteId keeps hb unchanged', () {
    final id = resolveWriteId(
        currentId: 'hb:w1:abc', activeCampaignId: 'w1');
    expect(id, 'hb:w1:abc');
  });

  test('saveEditedEntity forks SRD spell; leaves original intact', () async {
    await seedSrdFireball();

    final writeId = await saveEditedEntity(
      db: db,
      currentId: 'srd:fireball',
      categorySlug: 'spell',
      activeCampaignId: 'w1',
      name: 'Blaze',
      bodyJson: {'level': 3, 'description': 'Custom blast'},
      extras: const {'level': 3, 'schoolId': 'srd:evocation'},
    );

    expect(writeId, startsWith('hb:w1:'));

    final forked = await (db.select(db.spells)
          ..where((t) => t.id.equals(writeId)))
        .getSingle();
    expect(forked.name, 'Blaze');
    expect(forked.campaignId, 'w1');
    expect(forked.level, 3);
    expect(forked.schoolId, 'srd:evocation');

    final original = await (db.select(db.spells)
          ..where((t) => t.id.equals('srd:fireball')))
        .getSingle();
    expect(original.name, 'Fireball');
    expect(original.campaignId, isNull);
  });

  test('saveEditedEntity upserts in place for hb row', () async {
    final id = 'hb:w1:existing';
    await db.into(db.spells).insert(SpellsCompanion.insert(
          id: id,
          name: 'Old Name',
          level: 1,
          schoolId: 'srd:evocation',
          bodyJson: '{}',
          campaignId: const Value('w1'),
        ));

    final writeId = await saveEditedEntity(
      db: db,
      currentId: id,
      categorySlug: 'spell',
      activeCampaignId: 'w1',
      name: 'New Name',
      bodyJson: {'level': 1},
      extras: const {'level': 1, 'schoolId': 'srd:evocation'},
    );

    expect(writeId, id);
    final row = await (db.select(db.spells)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.name, 'New Name');
    expect(row.campaignId, 'w1');
  });

  test('saveEditedEntity forks SRD item with extras', () async {
    await db.into(db.items).insert(ItemsCompanion.insert(
          id: 'srd:longsword',
          name: 'Longsword',
          itemType: 'weapon',
          bodyJson: '{}',
          sourcePackageId: const Value('srd'),
          installedPackageId: const Value('install:srd-core-1'),
        ));

    final writeId = await saveEditedEntity(
      db: db,
      currentId: 'srd:longsword',
      categorySlug: 'item',
      activeCampaignId: 'w2',
      name: 'Custom Blade',
      bodyJson: {'t': 'weapon'},
      extras: const {'itemType': 'weapon', 'rarityId': 'srd:rare'},
    );

    final row = await (db.select(db.items)..where((t) => t.id.equals(writeId)))
        .getSingle();
    expect(writeId, startsWith('hb:w2:'));
    expect(row.name, 'Custom Blade');
    expect(row.itemType, 'weapon');
    expect(row.rarityId, 'srd:rare');
    expect(row.campaignId, 'w2');
  });

  test('saveEditedEntity throws on unsupported slug', () async {
    await expectLater(
      saveEditedEntity(
        db: db,
        currentId: 'srd:whatever',
        categorySlug: 'quest',
        activeCampaignId: 'w1',
        name: 'X',
        bodyJson: const {},
      ),
      throwsArgumentError,
    );
  });
}
