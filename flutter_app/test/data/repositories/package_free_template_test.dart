// Free şablonlu paket (docs/free-template/ROADMAP.md Faz 5): paket kendi
// şablonuyla açılır, yerleşik paket bugünkü gibi yerleşik şemayla.
//
//   cd flutter_app && flutter test test/data/repositories/package_free_template_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

const _now = '2026-10-12T00:00:00.000Z';

void main() {
  late AppDatabase db;
  late PackageRepositoryImpl repo;

  setUp(() {
    db = openTestDatabase();
    repo = PackageRepositoryImpl(db);
  });
  tearDown(() => db.close());

  final builtin = generateBuiltinDnd5eV2Schema().schema;
  final srdCopy = copyAsFreeTemplate(
    builtin,
    id: 'free-srd',
    name: 'SRD kopyam 2',
    now: _now,
  );

  WorldSchema schemaOf(Map<String, dynamic> data) =>
      WorldSchema.fromJson(Map<String, dynamic>.from(data['world_schema'] as Map));

  test('yerleşik paket yerleşik şemayla açılır', () async {
    await repo.create('Yerleşik', template: builtin);
    final data = await repo.load('Yerleşik');
    expect(data['template_id'], builtinDnd5eV2SchemaId);
    expect(isFreeTemplate(schemaOf(data)), isFalse);
    expect(data.containsKey('_world_schema'), isFalse);
  });

  test('free paket kendi şablonuyla açılır; hazır içerikler dahil', () async {
    await repo.create('Paketim', template: srdCopy);
    final data = await repo.load('Paketim');
    final schema = schemaOf(data);
    expect(data['template_id'], 'free-srd');
    expect(schema.freeRootId, builtinDnd5eV2SchemaId);
    expect(schema.presets, isNotEmpty);
    expect(schema.categories.length, srdCopy.categories.length);
    // Yan kayıt dışarı sızmaz.
    expect(data.containsKey('_world_schema'), isFalse);
  });

  test('kaydet / metadata kaydı / kopya sonrası şablon kalır', () async {
    await repo.create('Paketim', template: srdCopy);
    final data = await repo.load('Paketim');
    (data['entities'] as Map)['e1'] = {
      'name': 'Kızıl Pençe',
      'type': 'quest',
      'attributes': <String, dynamic>{},
    };
    await repo.save('Paketim', data);
    expect(schemaOf(await repo.load('Paketim')).schemaId, 'free-srd');

    // `world_schema`'sız kayıt (sadece metadata) şablonu silmez.
    await repo.save('Paketim', {'metadata': {'description': 'x'}});
    final after = await repo.load('Paketim');
    expect(schemaOf(after).schemaId, 'free-srd');
    expect(after['metadata'], {'description': 'x'});
    expect((after['entities'] as Map).length, 1);

    await repo.copy(sourceName: 'Paketim', destinationName: 'Kopya');
    expect(schemaOf(await repo.load('Kopya')).freeRootId,
        builtinDnd5eV2SchemaId);
  });

  test('aynı şablondan iki paket birbirinin şema satırını almaz', () async {
    await repo.create('A', template: srdCopy);
    await repo.create('B', template: srdCopy);
    await repo.save('A', await repo.load('A'));
    await repo.save('B', await repo.load('B'));
    final names = {
      for (final p in await repo.getPackageInfoList()) p.name: p.templateName,
    };
    expect(names['A'], 'SRD kopyam 2');
    expect(names['B'], 'SRD kopyam 2');
  });

  test('isFreePackageState', () async {
    await repo.create('Free', template: srdCopy);
    await repo.create('Yerleşik', template: builtin);
    final free = await db.packagesDao.getByName('Free');
    final built = await db.packagesDao.getByName('Yerleşik');
    expect(isFreePackageState(free!.stateJson), isTrue);
    expect(isFreePackageState(built!.stateJson), isFalse);
  });
}
