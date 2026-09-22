// Faz 5a — pull'un satır uygulaması. Ağ yok: [CloudPullService.apply] bir
// delta sayfasını yerele yazar, test sonucu Drift'ten okur.
//
//   flutter test test/application/services/cloud_pull_apply_test.dart
//
// Kapsam:
//   1. Tip dönüşümü: ISO → unix saniye, bool → 0/1, jsonb → TEXT.
//   2. LWW (§2.8): yereli daha yeni olan satır EZİLMEZ.
//   3. Tombstone: yereli eski olan satır silinir, yeni olan yaşar.
//   4. Combatant: `conditions_json` yerel satırlara açılır, world_id düşer.
//   5. Aynalanmayan yerel kolon (`is_online`) korunur — INSERT OR REPLACE değil.
//   6. Damga `worlds.cloud_revision`'a yazılır.
//   7. Round-trip: pull edilen satır push'a geri verildiğinde aynı gövde çıkar.

import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:dungeon_master_tool/application/services/cloud_pull_service.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late CloudPullService svc;

  String iso(DateTime t) => t.toUtc().toIso8601String();
  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  CloudDelta delta({
    Map<String, List<Map<String, dynamic>>> tables = const {},
    List<Map<String, dynamic>> tombstones = const [],
    int revision = 10,
    bool complete = true,
  }) =>
      CloudDelta.fromJson({
        'revision': revision,
        'complete': complete,
        'tables': tables,
        'tombstones': tombstones,
      });

  Map<String, dynamic> cloudEntity(
    String id,
    DateTime updatedAt, {
    String name = 'Ejder',
    bool linked = false,
    int revision = 5,
  }) =>
      {
        'id': id,
        'world_id': 'w1',
        'category_slug': 'npc',
        'name': name,
        'source': '',
        'description': '',
        'image_path': '',
        'images_json': '[]',
        'tags_json': '[]',
        'dm_notes': 'gizli',
        'pdfs_json': '[]',
        'location_id': null,
        'fields_json': '{"hp":12}',
        'package_id': null,
        'package_entity_id': null,
        'linked': linked,
        'dm_only_keys': ['hp'],
        'revision': revision,
        'created_at': iso(DateTime.utc(2026, 1, 1)),
        'updated_at': iso(updatedAt),
      };

  Future<Map<String, Object?>?> entityRow(String id) async => (await db
          .customSelect('SELECT * FROM world_entities WHERE id = ?',
              variables: [Variable<String>(id)])
          .getSingleOrNull())
      ?.data;

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    svc = CloudPullService(
        db: db, client: SupabaseClient('http://localhost:1', 'test-key'));
    await db.worldsDao.upsert(WorldsCompanion.insert(
      id: 'w1',
      worldName: 'Aegis',
      isOnline: const Value(true),
    ));
  });

  tearDown(() async => db.close());

  test('yeni satır yerele iner; ISO ve bool yerel tiplere çevrilir', () async {
    final t = DateTime.utc(2026, 6, 1);
    final res = await svc.apply(
        'w1',
        delta(tables: {
          'world_entities': [cloudEntity('e1', t, linked: true)],
        }));

    expect(res.applied, 1);
    final row = (await entityRow('e1'))!;
    expect(row['name'], 'Ejder');
    expect(row['linked'], 1, reason: 'Postgres boolean → SQLite 0/1');
    expect(row['updated_at'], unix(t), reason: 'ISO → unix saniye');
    expect(row['fields_json'], '{"hp":12}');
  });

  test('bulutta olmayan kolonlar (revision, dm_only_keys) yerele sızmaz',
      () async {
    await svc.apply(
        'w1',
        delta(tables: {
          'world_entities': [cloudEntity('e1', DateTime.utc(2026, 6, 1))],
        }));
    expect((await entityRow('e1'))!.containsKey('revision'), isFalse);
    expect((await entityRow('e1'))!.containsKey('dm_only_keys'), isFalse);
  });

  test('LWW: yerel satır daha yeniyse gelen satır atılır', () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'Yerel hali',
      updatedAt: Value(DateTime.utc(2026, 9, 1)),
    ));

    final res = await svc.apply(
        'w1',
        delta(tables: {
          'world_entities': [
            cloudEntity('e1', DateTime.utc(2026, 6, 1), name: 'Bulut hali'),
          ],
        }));

    expect(res.applied, 0);
    expect((await entityRow('e1'))!['name'], 'Yerel hali');
  });

  test('LWW: bulut satırı daha yeniyse yerel ezilir', () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'Yerel hali',
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ));

    await svc.apply(
        'w1',
        delta(tables: {
          'world_entities': [
            cloudEntity('e1', DateTime.utc(2026, 6, 1), name: 'Bulut hali'),
          ],
        }));

    expect((await entityRow('e1'))!['name'], 'Bulut hali');
  });

  test('tombstone: yerel düzenleme eskiyse satır silinir', () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'Silinecek',
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ));

    final res = await svc.apply(
        'w1',
        delta(tombstones: [
          {
            'table_name': 'world_entities',
            'row_id': 'e1',
            'deleted_at': iso(DateTime.utc(2026, 6, 1)),
            'revision': 7,
          }
        ]));

    expect(res.removed, 1);
    expect(await entityRow('e1'), isNull);
  });

  test('tombstone: yerel düzenleme daha yeniyse satır yaşar (§2.8)', () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'Yaşayan',
      updatedAt: Value(DateTime.utc(2026, 9, 1)),
    ));

    final res = await svc.apply(
        'w1',
        delta(tombstones: [
          {
            'table_name': 'world_entities',
            'row_id': 'e1',
            'deleted_at': iso(DateTime.utc(2026, 6, 1)),
            'revision': 7,
          }
        ]));

    expect(res.removed, 0);
    expect((await entityRow('e1'))!['name'], 'Yaşayan');
  });

  test('pull silmesi yerel tombstone BIRAKMAZ — push geri göndermesin',
      () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'x',
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ));
    await svc.apply(
        'w1',
        delta(tombstones: [
          {
            'table_name': 'world_entities',
            'row_id': 'e1',
            'deleted_at': iso(DateTime.utc(2026, 6, 1)),
            'revision': 7,
          }
        ]));

    final stones = await db
        .customSelect('SELECT * FROM sync_tombstones WHERE world_id = ?',
            variables: [const Variable<String>('w1')])
        .get();
    expect(stones, isEmpty);
  });

  test('combatant: conditions_json yerel satırlara açılır, world_id düşer',
      () async {
    await db.customStatement(
      'INSERT INTO encounters (id, world_id, session_id, name) '
      'VALUES (?, ?, ?, ?)',
      ['enc1', 'w1', 's1', 'Pusu'],
    );

    await svc.apply(
        'w1',
        delta(tables: {
          'world_combatants': [
            {
              'id': 'c1',
              'world_id': 'w1',
              'encounter_id': 'enc1',
              'entity_id': null,
              'name': 'Goblin',
              'init': 14,
              'ac': 13,
              'hp': 5,
              'max_hp': 7,
              'token_id': null,
              'sort_order': 0,
              'conditions_json':
                  '[{"name":"zehirli","duration":2,"initial_duration":3,'
                      '"entity_id":null}]',
              'revision': 4,
              'updated_at': iso(DateTime.utc(2026, 6, 1)),
            }
          ],
        }));

    final c = (await db
            .customSelect('SELECT * FROM combatants WHERE id = ?',
                variables: [const Variable<String>('c1')])
            .getSingle())
        .data;
    expect(c['name'], 'Goblin');
    expect(c['encounter_id'], 'enc1');
    expect(c.containsKey('world_id'), isFalse,
        reason: 'yerel combatants dünyayı encounter üzerinden biliyor');

    final conds = await db
        .customSelect('SELECT * FROM combat_conditions WHERE combatant_id = ?',
            variables: [const Variable<String>('c1')])
        .get();
    expect(conds.length, 1);
    expect(conds.first.data['name'], 'zehirli');
    expect(conds.first.data['initial_duration'], 3);
  });

  test('encounter tombstone savaşçılarını ve koşullarını da düşürür', () async {
    await db.customStatement(
      'INSERT INTO encounters (id, world_id, session_id, name, updated_at) '
      'VALUES (?,?,?,?,?)',
      ['enc1', 'w1', 's1', 'Pusu', unix(DateTime.utc(2026, 1, 1))],
    );
    await db.customStatement(
      'INSERT INTO combatants (id, encounter_id, name) VALUES (?, ?, ?)',
      ['c1', 'enc1', 'Goblin'],
    );
    await db.customStatement(
      'INSERT INTO combat_conditions (combatant_id, name) VALUES (?, ?)',
      ['c1', 'zehirli'],
    );

    await svc.apply(
        'w1',
        delta(tombstones: [
          {
            'table_name': 'world_encounters',
            'row_id': 'enc1',
            'deleted_at': iso(DateTime.utc(2026, 6, 1)),
            'revision': 7,
          }
        ]));

    expect(await db.customSelect('SELECT * FROM encounters').get(), isEmpty);
    expect(await db.customSelect('SELECT * FROM combatants').get(), isEmpty,
        reason: 'FK cascade yok (foreign_keys = OFF), elle düşürülmeli');
    expect(
        await db.customSelect('SELECT * FROM combat_conditions').get(), isEmpty);
  });

  test('karakter: jsonb dizi TEXT olur, aynalanmayan is_online korunur',
      () async {
    await db.customStatement(
      'INSERT INTO world_characters (id, world_id, template_id, template_name, '
      'payload_json, referenced_entity_ids_json, is_online, created_at, '
      'updated_at) VALUES (?,?,?,?,?,?,?,?,?)',
      [
        'ch1', 'w1', 't1', 'Savaşçı', '{}', '[]', 1,
        unix(DateTime.utc(2026, 1, 1)), unix(DateTime.utc(2026, 1, 1)),
      ],
    );

    await svc.apply(
        'w1',
        delta(tables: {
          'world_characters': [
            {
              'id': 'ch1',
              'world_id': 'w1',
              'owner_id': 'user-1',
              'template_id': 't1',
              'template_name': 'Savaşçı',
              'payload_json': '{"hp":30}',
              'referenced_entity_ids': ['e1', 'e2'],
              'revision': 3,
              'created_at': iso(DateTime.utc(2026, 1, 1)),
              'updated_at': iso(DateTime.utc(2026, 6, 1)),
            }
          ],
        }));

    final row = (await db
            .customSelect('SELECT * FROM world_characters WHERE id = ?',
                variables: [const Variable<String>('ch1')])
            .getSingle())
        .data;
    expect(row['payload_json'], '{"hp":30}');
    expect(row['referenced_entity_ids_json'], '["e1","e2"]',
        reason: 'jsonb dizi yerelde TEXT');
    expect(row['owner_id'], 'user-1');
    expect(row['is_online'], 1,
        reason: 'aynalanmayan kolon korunmalı — INSERT OR REPLACE değil');
  });

  test('1:1 tablo world_id anahtarıyla yazılır', () async {
    await svc.apply(
        'w1',
        delta(tables: {
          'world_settings': [
            {
              'world_id': 'w1',
              'settings_json': '{"tema":"koyu"}',
              'revision': 2,
              'updated_at': iso(DateTime.utc(2026, 6, 1)),
            }
          ],
        }));

    final row = (await db
            .customSelect('SELECT * FROM world_settings WHERE world_id = ?',
                variables: [const Variable<String>('w1')])
            .getSingle())
        .data;
    expect(row['settings_json'], '{"tema":"koyu"}');
  });

  test('installed_packages bileşik anahtarla yazılır ve silinir', () async {
    await svc.apply(
        'w1',
        delta(tables: {
          'world_installed_packages': [
            {
              'world_id': 'w1',
              'package_id': 'p1',
              'package_name': 'SRD',
              'package_version': '5.2.1',
              'installed_at': iso(DateTime.utc(2026, 1, 1)),
              'last_synced_at': iso(DateTime.utc(2026, 1, 1)),
              'revision': 2,
              'updated_at': iso(DateTime.utc(2026, 6, 1)),
            }
          ],
        }));
    expect(
        (await db.customSelect('SELECT * FROM installed_packages').get()).length,
        1);

    final res = await svc.apply(
        'w1',
        delta(tombstones: [
          {
            'table_name': 'world_installed_packages',
            'row_id': 'p1',
            'deleted_at': iso(DateTime.utc(2026, 7, 1)),
            'revision': 8,
          }
        ]));
    expect(res.removed, 1);
    expect(await db.customSelect('SELECT * FROM installed_packages').get(),
        isEmpty);
  });

  test('damga worlds.cloud_revision"a yazılır', () async {
    await svc.apply('w1', delta(revision: 42));
    expect((await db.worldsDao.getById('w1'))!.cloudRevision, 42);
  });

  test('round-trip: pull edilen satır push tarafından aynı gövdeyle üretilir',
      () async {
    final t = DateTime.utc(2026, 6, 1);
    final incoming = cloudEntity('e1', t, name: 'Ejder');
    await svc.apply('w1', delta(tables: {
      'world_entities': [incoming]
    }));

    final push = CloudPushService(
        db: db, client: SupabaseClient('http://localhost:1', 'test-key'));
    final batches = await push.collect(
        'w1', DateTime.fromMillisecondsSinceEpoch(0), {
      'npc': ['hp']
    });
    final out = batches.firstWhere((b) => b.table == 'world_entities').rows.single;

    // Echo guard'ın (096) çalışması buna bağlı: geri giden gövde bulutta duran
    // gövdeyle aynıysa `OLD.* IS DISTINCT FROM NEW.*` yanlış olur ve revizyon
    // kıpırdamaz. Farklı çıkan tek kolon olsa döngü kapanmazdı.
    for (final k in incoming.keys.where((k) => k != 'revision')) {
      expect(out[k], incoming[k], reason: '$k round-trip"te değişti');
    }
    expect(jsonDecode(out['fields_json'] as String), {'hp': 12});
  });
}
