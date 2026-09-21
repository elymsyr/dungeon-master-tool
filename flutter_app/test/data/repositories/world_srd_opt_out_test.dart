// Dünya oluştururken "D&D 5e SRD içeriğini ekle" kapatılabiliyor mu.
//
// includeSrd: false ise built-in SRD paketi bağlanmamalı ve load()'daki
// self-heal de onu geri eklememeli.
//
//   cd flutter_app && flutter test test/data/repositories/world_srd_opt_out_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late WorldRepositoryImpl repo;

  setUp(() {
    db = openTestDatabase();
    repo = WorldRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<int> linkCount(String worldId) async =>
      (await db.installedPackagesDao.getByWorld(worldId)).length;

  final template = generateBuiltinDnd5eV2Schema().schema;

  test('varsayılan: SRD paketi bağlanır', () async {
    final id = await repo.create('Barovia', template: template);
    await repo.load(id);
    expect(await linkCount(id), greaterThan(0));
  });

  test('includeSrd: false — ne create ne load bağlar', () async {
    final id =
        await repo.create('Eberron', template: template, includeSrd: false);
    expect(await linkCount(id), 0);
    await repo.load(id);
    expect(await linkCount(id), 0);
  });

  test('aynı isimde iki dünya yan yana durabilir', () async {
    final a = await repo.create('Fırtına Vadisi', template: template);
    final b = await repo.create('Fırtına Vadisi', template: template);
    expect(a, isNot(b));
    expect((await repo.load(a))['world_id'], a);
    expect((await repo.load(b))['world_id'], b);
    expect(
      (await repo.listWorlds()).where((w) => w.name == 'Fırtına Vadisi').length,
      2,
    );
  });

  test('yeniden adlandırma kimliği değiştirmez', () async {
    final id = await repo.create('Eski Ad', template: template);
    await repo.saveSettingsPatch(id, {'metadata': {'description': 'kalsın'}});
    await repo.renameWorld(id, 'Yeni Ad');
    final data = await repo.load(id);
    expect(data['world_name'], 'Yeni Ad');
    expect((data['metadata'] as Map)['description'], 'kalsın');
    expect(await linkCount(id), greaterThan(0));
  });
}
