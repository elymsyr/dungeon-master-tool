// Faz 5c — ikinci cihaz: bulutta olup bu cihazda olmayan dünya ve paketin
// indirilmesi, paketin pull'u ve buluttan silinmiş paketin diriltilmemesi.
// Ağ yerine sahte PostgREST (`test/support/fake_postgrest.dart`): RPC, select
// ve update yolları gerçekten koşuyor.
//
//   flutter test test/application/services/cloud_download_test.dart
//
// Kapsam:
//   1. Dünya: `worlds` satırı EN SON yazılır — yarım inen dünya hiçbir
//      listede yok. Kabuk online, damga son sayfanın revizyonu, push damgası
//      indirmenin başı (inen satırlar ilk açılışta buluta geri gitmez).
//   2. Yarıda kalan indirme iz ve TOMBSTONE bırakmaz — bıraksaydı sonraki
//      push buluttaki gerçek satırları silerdi.
//   3. Liste: yerelde olan ve aynası hiç yazılmamış dünya listelenmez.
//   4. Paket: kendi satırı son yazılır; aynı adlı yerel paket varsa hiç
//      başlamaz; kart tombstone'u yerelde siler.
//   5. Buluttan silinmiş paketi öbür cihazın push'u DİRİLTMEZ, offline'a düşer.

import 'package:drift/drift.dart' show Value, Variable;
import 'package:dungeon_master_tool/application/services/cloud_pull_service.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FakePostgrest cloud;
  late CloudPullService svc;

  const uid = '11111111-1111-1111-1111-111111111111';
  const created = '2026-06-01T00:00:00Z';

  Map<String, dynamic> entity(String id) => {
        'id': id,
        'world_id': 'w9',
        'category_slug': 'npc',
        'name': 'Kart $id',
        'source': '',
        'description': '',
        'image_path': '',
        'images_json': '[]',
        'tags_json': '[]',
        'dm_notes': '',
        'pdfs_json': '[]',
        'location_id': null,
        'fields_json': '{}',
        'package_id': null,
        'package_entity_id': null,
        'linked': false,
        'revision': 1,
        'created_at': created,
        'updated_at': created,
      };

  Map<String, dynamic> pkgEntity(String id) => {
        'id': id,
        'package_id': 'p9',
        'owner_id': uid,
        'category_slug': 'npc',
        'name': 'Paket kartı $id',
        'source': '',
        'description': '',
        'image_path': '',
        'images_json': '[]',
        'tags_json': '[]',
        'dm_notes': '',
        'pdfs_json': '[]',
        'location_id': null,
        'fields_json': '{}',
        'revision': 1,
        'created_at': created,
        'updated_at': created,
      };

  Map<String, dynamic> page(
    int revision, {
    Map<String, List<Map<String, dynamic>>> tables = const {},
    List<Map<String, dynamic>> tombstones = const [],
    bool complete = true,
    int head = 8,
  }) =>
      {
        'revision': revision,
        'head': head,
        'complete': complete,
        'tables': tables,
        'tombstones': tombstones,
      };

  Future<int> count(String sql, [String arg = 'w9']) async => (await db
          .customSelect(sql, variables: [Variable<String>(arg)])
          .getSingle())
      .read<int>('n');

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    cloud = await FakePostgrest.start(uid: uid);
    svc = CloudPullService(db: db, client: cloud.client);
  });

  tearDown(() async {
    await cloud.close();
    await db.close();
  });

  group('dünya', () {
    const world = (
      id: 'w9',
      name: 'Fırtına Vadisi',
      templateId: 'builtin-dnd5e-v2',
      templateHash: 'h1',
    );

    test('iki sayfa iner; kabuk en son, damgalar doğru', () async {
      World? shellDuringPage2;
      var entitiesDuringPage2 = 0;
      cloud.replies.addAll([
        () => (
              200,
              page(5, complete: false, tables: {
                'world_entities': [entity('e1')],
              }),
            ),
        () async {
          // İkinci sayfa istenirken ilk sayfa yerelde — kabuk hâlâ yok.
          shellDuringPage2 = await db.worldsDao.getById('w9');
          entitiesDuringPage2 = await count(
              'SELECT count(*) AS n FROM world_entities WHERE world_id = ?');
          return (
            200,
            page(8, tables: {
              'world_entities': [entity('e2')],
            }),
          );
        },
      ]);
      final progress = <double>[];
      final before = DateTime.now();

      final res = await svc.downloadWorld(world, onProgress: progress.add);

      expect(res.ok, isTrue, reason: '${res.error}');
      expect(res.applied, 2);
      expect(entitiesDuringPage2, 1, reason: 'ilk sayfa o an yerelde');
      expect(shellDuringPage2, isNull,
          reason: 'yarım inen dünya listede görünmemeli');
      expect(progress, [5 / 8, 1.0]);

      final w = (await db.worldsDao.getById('w9'))!;
      expect(w.worldName, 'Fırtına Vadisi');
      expect(w.templateId, 'builtin-dnd5e-v2');
      expect(w.ownerId, uid);
      expect(w.isOnline, isTrue);
      expect(w.cloudRevision, 8, reason: 'bir sonraki pull buradan devam eder');
      // Push damgası indirmenin başı: inen satırlar (2026-06-01) ondan eski.
      expect(
          w.lastCloudPushAt!
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(
          await count(
              'SELECT count(*) AS n FROM world_entities WHERE world_id = ?'),
          2);
    });

    test('yarıda kalan indirme iz ve tombstone bırakmaz', () async {
      cloud.replies.addAll([
        () => (
              200,
              page(5, complete: false, tables: {
                'world_entities': [entity('e1')],
              }),
            ),
        () => (500, {'message': 'boom'}),
      ]);

      final res = await svc.downloadWorld(world);

      expect(res.ok, isFalse);
      expect(await db.worldsDao.getById('w9'), isNull);
      expect(
          await count(
              'SELECT count(*) AS n FROM world_entities WHERE world_id = ?'),
          0,
          reason: 'ilk sayfanın satırları silinmeli');
      expect(
          await count(
              'SELECT count(*) AS n FROM sync_tombstones WHERE world_id = ?'),
          0,
          reason: 'tombstone buluttaki gerçek satırları silerdi');
    });

    test('görünmeyen dünya (boş delta) kabuk yaratmaz', () async {
      cloud.replies.add(() => (200, page(0, head: 0)));

      final res = await svc.downloadWorld(world);

      expect(res.ok, isFalse);
      expect(await db.worldsDao.getById('w9'), isNull);
    });

    test('liste: yerelde olan ve aynası boş olan dünya çıkmaz', () async {
      await db.worldsDao.upsert(WorldsCompanion.insert(
          id: 'local', worldName: 'Burada', isOnline: const Value(true)));
      cloud.replies.add(() => (
            200,
            [
              {'id': 'local', 'world_name': 'Burada', 'world_revisions': {'revision': 3}},
              {'id': 'empty', 'world_name': 'Boş', 'world_revisions': {'revision': 0}},
              {'id': 'none', 'world_name': 'Sayaçsız', 'world_revisions': null},
              {
                'id': 'b',
                'world_name': 'beta',
                'world_revisions': [
                  {'revision': 2},
                ],
              },
              {'id': 'a', 'world_name': 'Alfa', 'world_revisions': {'revision': 7}},
            ],
          ));

      final list = await svc.listCloudOnlyWorlds();

      expect([for (final w in list) w.id], ['a', 'b'], reason: 'ada göre sıralı');
    });
  });

  group('paket', () {
    const package = (id: 'p9', name: 'Canavarlar');
    final pkgRow = {
      'id': 'p9',
      'owner_id': uid,
      'name': 'Canavarlar',
      'state_json': '{}',
      'revision': 8,
      'created_at': created,
      'updated_at': created,
    };

    test('iki sayfa iner; paketin kendi satırı en son', () async {
      Package? rowDuringPage2;
      cloud.replies.addAll([
        () => (
              200,
              page(5, complete: false, tables: {
                'user_package_entities': [pkgEntity('k1')],
                'user_packages': [],
              }),
            ),
        () async {
          rowDuringPage2 = await db.packagesDao.getById('p9');
          return (
            200,
            page(8, tables: {
              'user_package_entities': [pkgEntity('k2')],
              'user_packages': [pkgRow],
            }),
          );
        },
      ]);

      final res = await svc.downloadPackage(package);

      expect(res.ok, isTrue, reason: '${res.error}');
      expect(rowDuringPage2, isNull,
          reason: 'yarım inen paket hub listesinde görünmemeli');
      final p = (await db.packagesDao.getById('p9'))!;
      expect(p.name, 'Canavarlar');
      expect(p.isOnline, isTrue);
      expect(p.cloudRevision, 8);
      expect(p.lastCloudPushAt, isNotNull);
      expect((await db.packagesDao.getEntities('p9')).length, 2);
    });

    test('aynı adlı yerel paket varsa hiç başlamaz', () async {
      await db.packagesDao.upsertPackage(
          PackagesCompanion.insert(id: 'baska', name: 'Canavarlar'));

      final res = await svc.downloadPackage(package);

      expect(res.error, isA<CloudPackageNameTaken>());
      expect(cloud.requests, isEmpty, reason: 'ağa hiç çıkılmamalı');
    });

    test('pull: kart tombstone\'u yerelde siler, damga pakete yazılır',
        () async {
      await db.packagesDao.upsertPackage(PackagesCompanion.insert(
          id: 'p9', name: 'Canavarlar', isOnline: const Value(true)));
      await db.customStatement(
        'INSERT INTO package_entities (id, package_id, category_slug, name, '
        'updated_at) VALUES (?, ?, ?, ?, ?)',
        ['k1', 'p9', 'npc', 'Ejder', 1000],
      );
      cloud.replies.add(() => (
            200,
            page(9, tombstones: [
              {
                'table_name': 'user_package_entities',
                'row_id': 'k1',
                'deleted_at': '2026-06-02T00:00:00Z',
                'revision': 9,
              },
            ], tables: {
              'user_packages': [
                {...pkgRow, 'revision': 9},
              ],
            }),
          ));

      final res = await svc.pullPackage('p9');

      expect(res.ok, isTrue, reason: '${res.error}');
      expect(res.removed, 1);
      expect(await db.packagesDao.getEntities('p9'), isEmpty);
      expect((await db.packagesDao.getById('p9'))!.cloudRevision, 9);
      expect(
          await count(
              'SELECT count(*) AS n FROM sync_tombstones WHERE world_id = ?',
              'p9'),
          0,
          reason: 'pull silmesi buluta geri gönderilmemeli');
    });

    test('buluttan silinmiş paketi push diriltmez, offline\'a düşer',
        () async {
      await db.packagesDao.upsertPackage(PackagesCompanion.insert(
          id: 'p9', name: 'Canavarlar', isOnline: const Value(true)));
      // İlk yayın geçmişte kaldı: bu tur güncelleme turu.
      await db.packagesDao.setCloudPushAt('p9', DateTime(2026, 6, 1));
      cloud.replies.addAll([
        () => (200, []), // PATCH user_packages → hiçbir satır güncellenmedi
        () => (200, []), // select: satır gerçekten yok
      ]);

      final res = await CloudPushService(db: db, client: cloud.client)
          .pushPackage('p9');

      expect(res.skipped, isTrue);
      expect(cloud.requests, ['PATCH /rest/v1/user_packages',
          'GET /rest/v1/user_packages'],
          reason: 'upsert (POST) paketi yeniden yaratırdı');
      final p = (await db.packagesDao.getById('p9'))!;
      expect(p.isOnline, isFalse);
      expect(p.lastCloudPushAt, isNull);
    });

    test('LWW\'nin atladığı güncelleme silme sanılmaz', () async {
      await db.packagesDao.upsertPackage(PackagesCompanion.insert(
          id: 'p9', name: 'Canavarlar', isOnline: const Value(true)));
      await db.packagesDao.setCloudPushAt('p9', DateTime(2026, 6, 1));
      cloud.replies.addAll([
        () => (200, []), // 097: bulutta daha yeni düzenleme, satır atlandı
        () => (200, [
              {'id': 'p9'},
            ]),
      ]);

      final res = await CloudPushService(db: db, client: cloud.client)
          .pushPackage('p9');

      expect(res.ok, isTrue, reason: '${res.error}');
      expect((await db.packagesDao.getById('p9'))!.isOnline, isTrue);
    });
  });
}
