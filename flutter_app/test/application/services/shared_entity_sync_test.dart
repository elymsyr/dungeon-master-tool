// Oyuncunun paylaşılan kartları yerelde (102): açılışta ve her sinyalde yalnız
// doğrulama — damga listesi yerelle karşılaştırılır, eksik/değişen kart id
// ile iner, geri çekilen kart yerelden silinir.
//
//   flutter test test/application/services/shared_entity_sync_test.dart

import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:dungeon_master_tool/application/services/cloud_pull_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FakePostgrest cloud;
  late CloudPullService svc;
  late List<Map<String, dynamic>> stamps;
  late Map<String, Map<String, dynamic>> bodies;
  final fetched = <List<String>>[];

  String iso(DateTime t) => t.toUtc().toIso8601String();
  final t1 = DateTime(2026, 10, 1, 12);
  final t2 = DateTime(2026, 10, 2, 12);

  Map<String, dynamic> body(String id, DateTime at, {bool linked = false}) => {
        'id': id,
        'world_id': 'w1',
        'category_slug': 'npc',
        'name': 'Kart $id',
        'source': '',
        'description': 'açıklama ${iso(at)}',
        'image_path': '',
        'images_json': '[]',
        'tags_json': '[]',
        'pdfs_json': '[]',
        'location_id': null,
        'fields_json': '{"public":"ok"}',
        'package_id': null,
        'package_entity_id': null,
        'linked': linked,
        'revision': 1,
        'updated_at': iso(at),
      };

  void cloudHas(List<Map<String, dynamic>> rows) {
    bodies = {for (final r in rows) r['id'] as String: r};
    stamps = [
      for (final r in rows)
        {'id': r['id'], 'updated_at': r['updated_at'], 'linked': r['linked']},
    ];
  }

  Future<Map<String, dynamic>?> local(String id) async =>
      (await db.customSelect('SELECT * FROM world_entities WHERE id = ?',
              variables: [Variable<String>(id)])
          .getSingleOrNull())
          ?.data;

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    await db.worldsDao
        .upsert(WorldsCompanion.insert(id: 'w1', worldName: 'Masa'));
    cloud = await FakePostgrest.start(
        uid: '22222222-2222-2222-2222-222222222222');
    svc = CloudPullService(db: db, client: cloud.client);
    fetched.clear();
    cloud.routes['/rest/v1/rpc/get_shared_entity_stamps'] =
        (_) => (200, stamps);
    cloud.routes['/rest/v1/rpc/get_shared_entities'] = (call) {
      final ids = [
        for (final id in (jsonDecode(call.body) as Map)['p_ids'] as List)
          id as String,
      ];
      fetched.add(ids);
      return (200, [for (final id in ids) if (bodies[id] != null) bodies[id]!]);
    };
  });

  tearDown(() async {
    await cloud.close();
    await db.close();
  });

  test('boş cihaz: yalnız homebrew kart iner, linked hiç istenmez', () async {
    cloudHas([body('e1', t1), body('e2', t1, linked: true)]);
    final res = await svc.syncSharedEntities('w1');
    expect(fetched, [
      ['e1']
    ]);
    expect(res.written.map((r) => r['id']), ['e1']);
    expect(res.visible, {'e1', 'e2'});
    final row = (await local('e1'))!;
    expect(row['dm_notes'], '');
    expect(row['world_id'], 'w1');
    expect(row['updated_at'], t1.millisecondsSinceEpoch ~/ 1000);
    expect(await local('e2'), isNull);
  });

  test('ikinci açılış: değişen yoksa hiçbir gövde inmez', () async {
    cloudHas([body('e1', t1)]);
    await svc.syncSharedEntities('w1');
    fetched.clear();
    expect((await svc.syncSharedEntities('w1')).written, isEmpty);
    expect(fetched, isEmpty);
  });

  test('DM düzeltti: yalnız o kart yeniden iner', () async {
    cloudHas([body('e1', t1), body('e3', t1)]);
    await svc.syncSharedEntities('w1');
    fetched.clear();
    cloudHas([body('e1', t2), body('e3', t1)]);
    final res = await svc.syncSharedEntities('w1');
    expect(fetched, [
      ['e1']
    ]);
    expect(res.written.single['id'], 'e1');
    expect((await local('e1'))!['description'], 'açıklama ${iso(t2)}');
  });

  test('geri çekilen kart silinir, linked kart kalır; yeniden paylaşılınca iner',
      () async {
    cloudHas([body('e1', t1), body('e3', t1)]);
    await svc.syncSharedEntities('w1');
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'p1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'paket',
      linked: const Value(true),
    ));
    // e1 geri çekildi ya da DM sildi: listede yok, gövde yerelden silinir.
    cloudHas([body('e3', t1)]);
    final res = await svc.syncSharedEntities('w1');
    expect(res.written, isEmpty);
    expect(res.visible, {'e3'});
    expect(await local('e1'), isNull);
    expect(await local('e3'), isNotNull);
    expect(await local('p1'), isNotNull);

    // Yeniden paylaşıldı: baştan iner.
    cloudHas([body('e1', t2), body('e3', t1)]);
    fetched.clear();
    await svc.syncSharedEntities('w1');
    expect(fetched, [
      ['e1']
    ]);
    expect((await local('e1'))!['description'], 'açıklama ${iso(t2)}');
  });

  test('yereldeki daha yeni satır ezilmez (LWW)', () async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'yerel',
      updatedAt: Value(t2),
    ));
    cloudHas([body('e1', t1)]);
    expect((await svc.syncSharedEntities('w1')).written, isEmpty);
    expect(fetched, isEmpty);
    expect((await local('e1'))!['name'], 'yerel');
  });

  test('aynı id oyuncunun başka dünyasında: o kart taşınmaz', () async {
    await db.worldsDao
        .upsert(WorldsCompanion.insert(id: 'w2', worldName: 'Kendi'));
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w2',
      categorySlug: 'npc',
      name: 'kendi',
      updatedAt: Value(t1),
    ));
    cloudHas([body('e1', t2)]);
    expect((await svc.syncSharedEntities('w1')).written, isEmpty);
    final row = (await local('e1'))!;
    expect(row['world_id'], 'w2');
    expect(row['name'], 'kendi');
  });
}
