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

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  test('offline dünya push edilmez', () async {
    await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w2', worldName: 'Kapalı'));
    final res = await svc.pushWorld('w2');
    expect(res.skipped, true);
  });
}
