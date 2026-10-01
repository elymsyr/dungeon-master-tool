// Faz 4 — push turunun satır üretimi. Ağ yok: [CloudPushService.collect]
// yereli okuyup gönderilecek gövdeleri üretir, test onu doğrular.
//
//   flutter test test/application/services/cloud_push_collect_test.dart
//
// Kapsam:
//   1. Watermark: damgadan eski satır gönderilmez, yeni satır gönderilir.
//   2. Tip dönüşümü: SQLite 0/1 → bool, unix saniye → ISO.
//   3. Redaksiyon anahtarı: bilinmeyen kategori NULL ("sır yok" DEĞİL).
//   4. Combatant: dünya encounter'dan gelir, koşullar JSON kolona iner.
//   5. Tombstone: DAO silme yolunda yazılır.
//   6. Faz 4b — paket (kullanıcı kapsamlı) ve karakter satırları.
//   7. Faz 5g — karakter turu: kapı sahiplik, tombstone karakter kapsamına,
//      medya satırlardan önce (ilk kez gidende bir kez daha sonra); yetim
//      temizliği bulut satırının andığını da korur.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late CloudPushService svc;

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> seedWorld() async {
    await db.worldsDao.upsert(WorldsCompanion.insert(
      id: 'w1',
      worldName: 'Aegis',
      isOnline: const Value(true),
    ));
  }

  Future<void> putEntity(String id, DateTime updatedAt,
      {String slug = 'npc', bool linked = false}) async {
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: id,
      worldId: 'w1',
      categorySlug: slug,
      name: id,
      linked: Value(linked),
      updatedAt: Value(updatedAt),
    ));
  }

  setUp(() async {
    db = openTestDatabase();
    // Yan tablolar `beforeOpen`'da kuruluyor; testte ilk sorguyla tetiklenir.
    await db.customSelect('SELECT 1').get();
    // `collect` ağa çıkmaz; istemci yalnızca kurucuyu karşılamak için.
    svc = CloudPushService(
        db: db, client: SupabaseClient('http://localhost:1', 'test-key'));
    await seedWorld();
  });

  tearDown(() async => db.close());

  test('watermark: yalnızca damgadan sonra değişen satır gider', () async {
    final old = DateTime(2026, 1, 1);
    final fresh = DateTime(2026, 6, 1);
    await putEntity('e-old', old);
    await putEntity('e-new', fresh);

    final batches = await svc.collect('w1', DateTime(2026, 3, 1), const {});
    final rows = batches.firstWhere((b) => b.table == 'world_entities').rows;
    expect(rows.map((r) => r['id']), ['e-new']);

    // Damga sıfırlanınca (full / ilk yayın) ikisi de gider.
    final all = await svc.collect('w1', epoch, const {});
    expect(
      all.firstWhere((b) => b.table == 'world_entities').rows.length,
      2,
    );
  });

  test('bool ve tarih kolonları Postgres tipine çevrilir', () async {
    await putEntity('e1', DateTime(2026, 6, 1), linked: true);
    final rows = (await svc.collect('w1', epoch, const {}))
        .firstWhere((b) => b.table == 'world_entities')
        .rows
        .single;
    expect(rows['linked'], isA<bool>());
    expect(rows['linked'], true);
    expect(rows['updated_at'], isA<String>());
    expect(DateTime.parse(rows['updated_at'] as String).toLocal(),
        DateTime(2026, 6, 1));
  });

  test('dm_only_keys: bilinmeyen kategori NULL kalır', () async {
    await putEntity('e1', DateTime(2026, 6, 1), slug: 'npc');
    await putEntity('e2', DateTime(2026, 6, 1), slug: 'spell');
    final rows = (await svc.collect('w1', epoch, const {
      'npc': ['secrets'],
    }))
        .firstWhere((b) => b.table == 'world_entities')
        .rows;
    final byId = {for (final r in rows) r['id']: r};
    expect(byId['e1']!['dm_only_keys'], ['secrets']);
    // "bilinmiyor" ≠ "sır yok": şemada olmayan kategori NULL gider ve
    // get_shared_entities o kartı oyuncuya HİÇ döndürmez.
    expect(byId['e2']!['dm_only_keys'], isNull);
  });

  test('combatant: dünya encounter\'dan, koşullar JSON kolondan', () async {
    await db.worldSessionsDao.upsert(WorldSessionsCompanion.insert(
        id: 's1', worldId: 'w1', name: const Value('S1')));
    await db.combatDao.upsertEncounter(EncountersCompanion.insert(
        id: 'enc1', sessionId: 's1', worldId: 'w1', name: 'Kapı'));
    await db.combatDao.upsertCombatant(CombatantsCompanion.insert(
        id: 'c1', encounterId: 'enc1', name: 'Goblin'));
    await db.combatDao.insertCondition(CombatConditionsCompanion.insert(
        combatantId: 'c1', name: 'prone', duration: const Value(2)));

    final rows = (await svc.collect('w1', epoch, const {}))
        .firstWhere((b) => b.table == 'world_combatants')
        .rows
        .single;
    expect(rows['world_id'], 'w1');
    final conds = jsonDecode(rows['conditions_json'] as String) as List;
    expect(conds.single['name'], 'prone');
    expect(conds.single['duration'], 2);
  });

  test('koşul değişimi combatant satırını damgalar', () async {
    await db.worldSessionsDao.upsert(WorldSessionsCompanion.insert(
        id: 's1', worldId: 'w1', name: const Value('S1')));
    await db.combatDao.upsertEncounter(EncountersCompanion.insert(
        id: 'enc1', sessionId: 's1', worldId: 'w1', name: 'Kapı'));
    await db.combatDao.upsertCombatant(CombatantsCompanion.insert(
        id: 'c1', encounterId: 'enc1', name: 'Goblin'));
    // Damgayı geriye al: koşul eklenmezse bu satır artık gönderilmemeli.
    await db.customStatement(
        'UPDATE combatants SET updated_at = 0 WHERE id = ?', ['c1']);
    var batches = await svc.collect('w1', DateTime(2020), const {});
    expect(batches.where((b) => b.table == 'world_combatants'), isEmpty);

    await db.combatDao.insertCondition(CombatConditionsCompanion.insert(
        combatantId: 'c1', name: 'stunned'));
    batches = await svc.collect('w1', DateTime(2020), const {});
    expect(
      batches.firstWhere((b) => b.table == 'world_combatants').rows.single['id'],
      'c1',
    );
  });

  test('silme tombstone bırakır, dünya silinince temizlenir', () async {
    await putEntity('e1', DateTime(2026, 6, 1));
    await db.worldEntitiesDao.deleteById('e1');
    final rows = await db
        .customSelect('SELECT table_name, row_id, world_id '
            'FROM sync_tombstones')
        .get();
    expect(rows.single.read<String>('table_name'), 'world_entities');
    expect(rows.single.read<String>('row_id'), 'e1');
    expect(rows.single.read<String>('world_id'), 'w1');
  });

  test('geri gelen satırın tombstone\'u satırı öldürmez, damgalar', () async {
    // Sil + eski damgayla yeniden yarat (import / full-replace yolu).
    await putEntity('e1', DateTime(2026, 6, 1));
    await db.worldEntitiesDao.deleteById('e1');
    await putEntity('e1', DateTime(2020, 1, 1));

    final res = await svc.pushWorld('w1');
    // Ağ yok → tur hata ile bitiyor ama tombstone adımı ondan önce koşuyor.
    expect(res.deleted, 0, reason: 'canlı satır bulutta silinmemeli');
    final left = await db
        .customSelect('SELECT row_id FROM sync_tombstones')
        .get();
    expect(left, isEmpty, reason: 'yalan söyleyen tombstone düşmeli');
    // Damga tazelendi → satır bu turun taramasına giriyor.
    final rows = (await svc.collect('w1', DateTime(2025), const {}))
        .firstWhere((b) => b.table == 'world_entities')
        .rows;
    expect(rows.single['id'], 'e1');
  });

  test('medya satırlardan önce: beforeRows upsert\'ten önce, turun ref\'leriyle',
      () async {
    final sha = 'a' * 64;
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e1',
      worldId: 'w1',
      categorySlug: 'npc',
      name: 'e1',
      imagePath: Value('dmt-content://$sha.webp'),
      updatedAt: Value(DateTime(2026, 6, 1)),
    ));
    final cloud = await FakePostgrest.start(uid: 'u1');
    addTearDown(cloud.close);
    final remote = CloudPushService(db: db, client: cloud.client);
    for (var i = 0; i < 5; i++) {
      cloud.replies.add(() => (200, <Object>[]));
    }

    Map<String, Object>? seen;
    var upsertsBefore = -1;
    await remote.pushWorld('w1', beforeRows: (refs) async {
      seen = {for (final e in refs.entries) e.key: e.value.ext};
      upsertsBefore = cloud.calls.where((c) => c.method == 'POST').length;
    });
    expect(seen, {sha: '.webp'});
    expect(upsertsBefore, 0, reason: 'satır, andığı bayt buluta çıkmadan gitmez');
    expect(cloud.requests, contains('POST /rest/v1/world_entities'));
  });

  test('offline dünya push edilmez', () async {
    await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w2', worldName: 'Kapalı'));
    final res = await svc.pushWorld('w2');
    expect(res.skipped, true);
  });
  // ── Faz 4b ────────────────────────────────────────────────────────────

  test('karakter: referans listesi jsonb olur, kolon adı değişir', () async {
    await db.worldCharactersDao.upsert(WorldCharactersCompanion.insert(
      id: 'ch1',
      worldId: 'w1',
      ownerId: const Value('u1'),
      templateId: 'dnd5e',
      templateName: 'Fighter',
      payloadJson: const Value('{"name":"Kael"}'),
      referencedEntityIdsJson: const Value('["e1","e2"]'),
      isOnline: const Value(true),
      updatedAt: Value(DateTime(2026, 6, 1)),
    ));
    final row = (await svc.collectCharacters('u1', const {}, epoch)).single;
    expect(row['referenced_entity_ids'], ['e1', 'e2']);
    expect(row.containsKey('referenced_entity_ids_json'), false);
    expect(row['payload_json'], '{"name":"Kael"}');
    // Dünya turundan çıktı (Faz 5g): tek yol karakter turu.
    expect(
        (await svc.collect('w1', epoch, const {}))
            .any((b) => b.table == 'world_characters'),
        false);
  });

  // ── Faz 5g ────────────────────────────────────────────────────────────

  Future<void> putChar(String id,
      {String world = '',
      String? owner = 'u1',
      bool online = false,
      DateTime? at}) async {
    await db.worldCharactersDao.upsert(WorldCharactersCompanion.insert(
      id: id,
      worldId: world,
      ownerId: Value(owner),
      templateId: 'dnd5e',
      templateName: 'Fighter',
      isOnline: Value(online),
      updatedAt: Value(at ?? DateTime(2026, 6, 1)),
    ));
  }

  test('watermark: damgayla aynı saniyede düzenlenen satır kaçmaz', () async {
    // Damga tur başındaki an (ms), `updated_at` saniye: tur sürerken aynı
    // saniyede düzenlenen satır sonraki turda da gitmeli.
    final mark = DateTime(2026, 3, 1, 12, 0, 5, 100);
    await putEntity('e-same', DateTime(2026, 3, 1, 12, 0, 5, 900));
    final rows = (await svc.collect('w1', mark, const {}))
        .firstWhere((b) => b.table == 'world_entities')
        .rows;
    expect(rows.map((r) => r['id']), ['e-same']);
    await putChar('c-same', online: true, at: DateTime(2026, 3, 1, 12, 0, 5, 900));
    expect((await svc.collectCharacters('u1', const {}, mark)).map((r) => r['id']),
        ['c-same']);
  });

  test('karakter turu: kapı sahiplik ve anahtar, ya da DM\'in online dünyası',
      () async {
    await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w-off', worldName: 'Kapalı'));
    await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w-player', worldName: 'Oyuncu olduğum'));
    await putChar('own-online', online: true);
    await putChar('own-local');
    await putChar('own-offline-world', world: 'w-off');
    await putChar('own-member-world', world: 'w-player');
    await putChar('dm-unowned', world: 'w1', owner: null);
    await putChar('dm-player', world: 'w1', owner: 'u2');
    await putChar('other-elsewhere', world: 'w-off', owner: 'u2', online: true);
    await putChar('own-old', online: true, at: DateTime(2020));

    final rows =
        await svc.collectCharacters('u1', {'w-player'}, DateTime(2025));
    expect(rows.map((r) => r['id']).toSet(), {
      'own-online',
      'own-member-world',
      'dm-unowned',
      'dm-player',
    });
    // Yerelde dünyasız boş dize; bulutta NULL.
    expect(rows.firstWhere((r) => r['id'] == 'own-online')['world_id'], isNull);
  });

  test('karakter silinince tombstone karakter kapsamına, yalnız bulutta duranın',
      () async {
    await putChar('on', online: true);
    await putChar('local');
    await putChar('dropped', online: true);
    await db.worldCharactersDao.deleteById('on');
    await db.worldCharactersDao.deleteById('local');
    // Sahiplik başkasına geçti (dropMirror): satır yalnız bu cihazdan kalkar.
    await db.worldCharactersDao.deleteById('dropped', tombstone: false);
    final rows = await db
        .customSelect('SELECT row_id, world_id FROM sync_tombstones')
        .get();
    expect(rows.map((r) => r.read<String>('row_id')), ['on']);
    expect(rows.single.read<String>('world_id'), '@characters');
  });

  test('dünya yerelden silinince karakterlerine tombstone yazılmaz', () async {
    await putChar('dm-player', world: 'w1', owner: 'u2', online: true);
    await db.worldCharactersDao.deleteByWorld('w1');
    expect(await db.customSelect('SELECT * FROM sync_tombstones').get(),
        isEmpty, reason: 'oyuncunun karakteri DM\'in cihazından silinmemeli');
  });

  test('karakter turu: medya satırlardan önce, yazılan satır online işaretlenir',
      () async {
    final sha = 'b' * 64;
    await db.worldCharactersDao.upsert(WorldCharactersCompanion.insert(
      id: 'ch1',
      worldId: '',
      ownerId: const Value('u1'),
      templateId: 'dnd5e',
      templateName: 'Fighter',
      payloadJson: Value('{"entity":{"imagePath":"dmt-content://$sha.png"}}'),
      updatedAt: Value(DateTime(2026, 6, 1)),
    ));
    await db.worldCharactersDao.setOnline('ch1', true);
    await db.worldCharactersDao.setOnline('ch1', false);
    // Anahtar açık ama satır henüz bulutta değil.
    await (db.update(db.worldCharacters)..where((t) => t.id.equals('ch1')))
        .write(const WorldCharactersCompanion(isOnline: Value(true)));

    final cloud = await FakePostgrest.start(uid: 'u1');
    addTearDown(cloud.close);
    final remote = CloudPushService(db: db, client: cloud.client);
    cloud.replies.add(() => (
          200,
          [
            {'owner_revision': 1, 'owner_id': 'u1'}
          ]
        ));

    final calls = <Map<String, Set<String>>>[];
    var upsertsBefore = -1;
    final res = await remote.pushCharacters(
        ownerId: 'u1',
        media: (refs) async {
          calls.add({for (final e in refs.entries) e.key: e.value.keys.toSet()});
          if (calls.length == 1) {
            upsertsBefore =
                cloud.calls.where((c) => c.method == 'POST').length;
          }
          // İlk kez giden karakter: rezervasyon satırı bulamaz.
          return {'ch1'};
        });
    expect(res.error, isNull);
    expect(calls.first, {
      'ch1': {sha}
    });
    expect(upsertsBefore, 0);
    expect(calls.length, 2, reason: 'yüklenemeyen satırdan sonra yeniden');
    expect(cloud.requests, contains('POST /rest/v1/world_characters'));
    expect((await db.worldCharactersDao.getById('ch1'))!.isOnline, true);
    final mark = await db.worldCharactersDao.cloudMark();
    expect(mark.pushedAt, isNotNull);
    expect(mark.revision, 1, reason: 'boşluksuz kendi dizimiz');

    // Damga ilerledi: sınır saniyesinden sonraki tur aynı satırı göndermez.
    expect(
        await remote.collectCharacters(
            'u1', const {}, mark.pushedAt!.add(const Duration(seconds: 1))),
        isEmpty);
  });

  test('yetim temizliği bulut satırının andığı medyayı da korur', () async {
    // Bu cihazın satırı bayat olabilir: bulutta öbür cihazın yeni portresi.
    final fresh = 'c' * 64;
    final cloud = await FakePostgrest.start(uid: 'u1');
    addTearDown(cloud.close);
    final remote = CloudPushService(db: db, client: cloud.client);
    cloud.replies.addAll([
      () => (
            200,
            [
              {
                'payload_json': jsonEncode({
                  'entity': {
                    'imagePath': 'dmt-content://$fresh.png',
                    'images': ['dmt-content://${'d' * 64}.jpg'],
                  },
                }),
              }
            ]
          ),
      () => (200, <Object>[]), // satır bulutta yok
    ]);

    expect(await remote.cloudCharacterShas('ch1'), {fresh, 'd' * 64});
    expect(cloud.calls.first.uri.queryParameters['id'], 'eq.ch1');
    expect(await remote.cloudCharacterShas('ch2'), isEmpty);
  });

  test('paket: ebeveyn her tur gider, çocuklar damgaya bakar', () async {
    await db.packagesDao.upsertPackage(PackagesCompanion.insert(
      id: 'p1',
      name: 'Kanun Kitabı',
      isOnline: const Value(true),
      updatedAt: Value(DateTime(2026, 1, 1)),
    ));
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: 'pe-old',
      packageId: 'p1',
      categorySlug: 'spell',
      name: 'Eski',
      updatedAt: Value(DateTime(2026, 1, 1)),
    ));
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: 'pe-new',
      packageId: 'p1',
      categorySlug: 'spell',
      name: 'Yeni',
      updatedAt: Value(DateTime(2026, 6, 1)),
    ));

    final batches =
        await svc.collectPackage('p1', DateTime(2026, 3, 1), 'u-1');
    final parent =
        batches.firstWhere((b) => b.table == 'user_packages').rows.single;
    // Damgadan eski olmasına rağmen gidiyor: çocukların FK hedefi.
    expect(parent['id'], 'p1');
    expect(parent['owner_id'], 'u-1');

    final kids =
        batches.firstWhere((b) => b.table == 'user_package_entities').rows;
    expect(kids.map((r) => r['id']), ['pe-new']);
    expect(kids.single['owner_id'], 'u-1');
  });

  test('paket kartı silinince tombstone paket kapsamına yazılır', () async {
    await db.packagesDao
        .upsertPackage(PackagesCompanion.insert(id: 'p1', name: 'K'));
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: 'pe1',
      packageId: 'p1',
      categorySlug: 'spell',
      name: 'Ateş Topu',
    ));
    await db.packagesDao.deleteEntity('pe1');
    final row = (await db
            .customSelect('SELECT table_name, row_id, world_id '
                'FROM sync_tombstones')
            .get())
        .single;
    expect(row.read<String>('table_name'), 'user_package_entities');
    expect(row.read<String>('row_id'), 'pe1');
    // Kapsam kolonunun adı `world_id` ama paket turunda paketin id'si durur.
    expect(row.read<String>('world_id'), 'p1');
  });

  test('paket silinince bekleyen tombstone kalmaz', () async {
    await db.packagesDao
        .upsertPackage(PackagesCompanion.insert(id: 'p1', name: 'K'));
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: 'pe1',
      packageId: 'p1',
      categorySlug: 'spell',
      name: 'Ateş Topu',
    ));
    await db.packagesDao.deleteEntity('pe1');
    await db.packagesDao.deletePackage('p1');
    // Paket satırı gidince `pushPackage` koşamaz; kayıtlar birikmemeli.
    expect(
        await db.customSelect('SELECT 1 FROM sync_tombstones').get(), isEmpty);
  });

  test('offline paket push edilmez', () async {
    await db.packagesDao
        .upsertPackage(PackagesCompanion.insert(id: 'p2', name: 'Kapalı'));
    expect((await svc.pushPackage('p2')).skipped, true);
  });

  test('paket damgası: offline alınca sıfırlanır', () async {
    await db.packagesDao.upsertPackage(PackagesCompanion.insert(
        id: 'p1', name: 'K', isOnline: const Value(true)));
    await db.packagesDao.setCloudPushAt('p1', DateTime(2026, 6, 1));
    expect((await db.packagesDao.getById('p1'))!.lastCloudPushAt,
        DateTime(2026, 6, 1));
    // Yeniden açılırsa her şey bir kez daha gitsin.
    await db.packagesDao.setOnline('p1', false);
    final row = (await db.packagesDao.getById('p1'))!;
    expect(row.isOnline, false);
    expect(row.lastCloudPushAt, isNull);
  });

  // Faz 5b — kendi push'umuzun sinyali bize de geliyor. Damga yalnız dönen
  // revizyonlar damganın hemen ardından BOŞLUKSUZ ise ilerler; tek bir boşluk
  // başka bir yazar demek ve onu pull getirmeli — yanlış ilerleme o satırı
  // bir daha hiç indirmez.
  test('ownRunEnd: yalnız boşluksuz kendi dizimiz damgayı ilerletir', () {
    expect(CloudPushService.ownRunEnd(10, [11, 12, 13]), 13);
    expect(CloudPushService.ownRunEnd(10, [13, 11, 12]), 13, reason: 'sıra');
    // Echo guard'ın yazmadığı satır eski revizyonunu döner — sayılmaz.
    expect(CloudPushService.ownRunEnd(10, [4, 11, 12]), 12);
    // Araya başka biri girdi (12 bizim değil).
    expect(CloudPushService.ownRunEnd(10, [11, 13]), isNull);
    // Damgadan sonraki ilk revizyon başkasının (11).
    expect(CloudPushService.ownRunEnd(10, [12, 13]), isNull);
    expect(CloudPushService.ownRunEnd(10, const []), isNull);
    expect(CloudPushService.ownRunEnd(10, [3, 7]), isNull);
  });
}

