// Kart düzenlemesinin `world_entities.updated_at`'i ilerletip ilerletmediği.
//
// Regresyon: DAO upsert'ü damgalamıyordu; ON CONFLICT satırın eski
// `updated_at`'ini bırakıyordu. Push "damgadan sonra değişen satırları"
// taradığı için var olan kartın düzenlemesi buluta hiç çıkmıyordu — öbür
// cihaza yalnız silmeler (tombstone) ve yeni kartlar gidiyordu.
//
//   cd flutter_app && flutter test test/data/repositories/world_entity_stamp_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late WorldRepositoryImpl repo;
  late String worldId;

  setUp(() async {
    db = openTestDatabase();
    repo = WorldRepositoryImpl(db);
    await repo.save('Barovia', {'entities': <String, dynamic>{}});
    worldId = (await db.worldsDao.getByName('Barovia'))!.id;
    await repo.saveEntity(worldId, 'e1', {'name': 'Eski', 'type': 'npc'});
  });

  tearDown(() => db.close());

  Future<DateTime> stamp() async =>
      (await db.worldEntitiesDao.getById('e1'))!.updatedAt;

  test('düzenleme damgayı ilerletir', () async {
    final before = await stamp();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.saveEntity(worldId, 'e1', {'name': 'Yeni', 'type': 'npc'});
    expect((await db.worldEntitiesDao.getById('e1'))!.name, 'Yeni');
    expect((await stamp()).isAfter(before), isTrue);
  });

  test('aynı içerik damgaya dokunmaz', () async {
    final before = await stamp();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.saveEntity(worldId, 'e1', {'name': 'Eski', 'type': 'npc'});
    expect(await stamp(), before);
  });
}
