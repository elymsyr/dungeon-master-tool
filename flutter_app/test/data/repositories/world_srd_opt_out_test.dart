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

  Future<int> linkCount(String name) async {
    final world = await db.worldsDao.getByName(name);
    return (await db.installedPackagesDao.getByWorld(world!.id)).length;
  }

  final template = generateBuiltinDnd5eV2Schema().schema;

  test('varsayılan: SRD paketi bağlanır', () async {
    await repo.create('Barovia', template: template);
    await repo.load('Barovia');
    expect(await linkCount('Barovia'), greaterThan(0));
  });

  test('includeSrd: false — ne create ne load bağlar', () async {
    await repo.create('Eberron', template: template, includeSrd: false);
    expect(await linkCount('Eberron'), 0);
    await repo.load('Eberron');
    expect(await linkCount('Eberron'), 0);
  });
}
