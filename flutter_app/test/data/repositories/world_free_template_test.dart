// Free şablonlu dünya (docs/free-template/ROADMAP.md Faz 3): SRD soyu kapısı
// (V28), yerleşik kategori overlay'inin free'de çalışmaması ve şemada
// olmayan kart anahtarlarının kayıtta kalması (D17).
//
//   cd flutter_app && flutter test test/data/repositories/world_free_template_test.dart

import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

const _now = '2026-10-11T00:00:00.000Z';

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

  final srdCopy = copyAsFreeTemplate(
    generateBuiltinDnd5eV2Schema().schema,
    id: 'free-srd',
    name: 'SRD kopyam',
    now: _now,
  );

  test('SRD kopyası: SRD paketi bağlanır, kartlar gelir', () async {
    final id = await repo.create('Deneme', template: srdCopy);
    final data = await repo.load(id);
    expect(await linkCount(id), greaterThan(0));
    expect((data['entities'] as Map), isNotEmpty);
    expect(data['template_id'], 'free-srd');
  });

  test('SRD kopyası, SRD kapalı: ne create ne load bağlar', () async {
    final id = await repo.create(
      'Deneme',
      template: srdCopy,
      includeSrd: false,
    );
    await repo.load(id);
    expect(await linkCount(id), 0);
  });

  test('boş şablon: SRD bağlanmaz', () async {
    final empty = emptyFreeTemplate(
      id: 'free-empty',
      name: 'Boş',
      playerCardName: 'Oyuncu',
      now: _now,
    );
    final id = await repo.create('Boş dünya', template: empty);
    final data = await repo.load(id);
    expect(await linkCount(id), 0);
    expect((data['world_schema'] as Map)['categories'], hasLength(1));
  });

  test('kopyada silinen SRD kategorisi load ile geri gelmez', () async {
    final noSpell = srdCopy.copyWith(
      categories: [
        for (final c in srdCopy.categories)
          if (c.slug != 'spell') c,
      ],
    );
    final id = await repo.create('Büyüsüz', template: noSpell);
    final data = await repo.load(id);
    final slugs = [
      for (final c in (data['world_schema'] as Map)['categories'] as List)
        (c as Map)['slug'],
    ];
    expect(slugs, isNot(contains('spell')));
    expect(slugs, hasLength(srdCopy.categories.length - 1));
  });

  test(
    'şemada olmayan kart anahtarı kayıtta ve şema değişince kalır',
    () async {
      final id = await repo.create('Deneme', template: srdCopy);
      await repo.saveEntity(id, 'faction-1', {
        'name': 'Harpers',
        'type': 'npc',
        'attributes': {'gone_field': 'eski değer'},
      });
      // Şablon güncellemesi (applyTemplateUpdate) tüm gövdeyi yazar.
      final data = await repo.load(id);
      data['world_schema'] = srdCopy
          .copyWith(categories: srdCopy.categories.take(3).toList())
          .toJson();
      await repo.save(id, data);
      final after = await repo.load(id);
      final card = (after['entities'] as Map)['faction-1'] as Map;
      expect((card['attributes'] as Map)['gone_field'], 'eski değer');
    },
  );
}
