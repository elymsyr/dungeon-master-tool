// Dünya kopyalamanın kaynağı boşaltmaması.
//
// Regresyon: `copy()` kaynağın payload'ını id'leri değiştirmeden yazıyordu.
// `world_entities` ve `world_sessions`'ın birincil anahtarı yalnız `{id}`
// olduğu için upsert satırı eklemiyor, `world_id`'sini yeni dünyaya
// güncelliyordu — kartlar ve oturumlar kaynaktan kopyaya taşınıyordu.
//
//   cd flutter_app && flutter test test/data/repositories/world_copy_test.dart

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';
import 'package:dungeon_master_tool/application/services/mention_text.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/util/builtin_synth.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late WorldRepositoryImpl repo;
  late Directory tmp;
  late String src;
  late String forkId;
  late String portrait;
  late String pdf;
  late String mapImage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('world_copy');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);
    db = openTestDatabase();
    repo = WorldRepositoryImpl(db);

    src = '6f1c2a3e-4b5d-4e6f-8a7b-9c0d1e2f3a4b';
    forkId = synthBuiltinEntityId(src, 'pe-goblin');
    final dir = LocalMediaLocalizer.worldDir(src);
    portrait = p.join(dir, 'media', 'strahd.png');
    pdf = p.join(dir, 'files', 'kitap.pdf');
    mapImage = p.join(dir, 'media', 'harita.png');
    for (final f in [portrait, pdf, mapImage]) {
      await File(f).create(recursive: true);
      await File(f).writeAsBytes([1, 2, 3]);
    }

    await repo.save(src, {
      'world_name': 'Barovia',
      'entities': {
        'e-castle': {'name': 'Ravenloft', 'type': 'location'},
        'e-strahd': {
          'name': 'Strahd',
          'type': 'npc',
          'location_id': 'e-castle',
          'image_path': portrait,
          'description': '@[Ireena](entity:e-ireena) ile evlenmek istiyor.\n'
              '${markdownImage(mapImage, 'harita')}',
          'pdfs': [pdf],
          'attributes': {
            'ally_ref': 'e-ireena',
            'minions': ['e-castle', forkId],
          },
        },
        'e-ireena': {'name': 'Ireena', 'type': 'npc'},
        // SRD kartının dünyaya forklanmış hâli — synth id'sini taşır.
        forkId: {
          'name': 'Goblin (homebrew)',
          'type': 'monster',
          'package_id': 'pkg-srd',
          'package_entity_id': 'pe-goblin',
          'linked': true,
        },
      },
      'sessions': [
        {
          'id': 's-1',
          'name': 'Oturum 1',
          'combatants': [
            {'entity_id': 'e-strahd'},
          ],
        },
      ],
      'map_data': {
        'pins': [
          {'id': 'pin-1', 'entity_id': 'e-castle'},
        ],
      },
      'mind_maps': [
        {
          'nodes': [
            {'id': 'n-1', 'entityId': 'e-ireena'},
          ],
        },
      ],
    });
    await db.installedPackagesDao.upsert(InstalledPackagesCompanion.insert(
      worldId: src,
      packageId: 'pkg-srd',
    ));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('kaynak dünya kartlarını ve oturumlarını korur', () async {
    final dst = await repo.copy(sourceId: src, destinationName: 'Kopya');

    expect(await db.worldEntitiesDao.getByWorld(src), hasLength(4));
    expect(await db.worldSessionsDao.getByWorld(src), hasLength(1));
    expect(await db.worldEntitiesDao.getByWorld(dst), hasLength(4));
    expect(await db.worldSessionsDao.getByWorld(dst), hasLength(1));

    final source = await repo.load(src);
    expect((source['entities'] as Map)['e-strahd']['location_id'], 'e-castle');
  });

  test('kopyadaki ref\'ler kopyanın kartlarını gösterir', () async {
    final dst = await repo.copy(sourceId: src, destinationName: 'Kopya');
    final copy = await repo.load(dst);
    final entities = copy['entities'] as Map<String, dynamic>;
    String idOf(String name) =>
        entities.entries.firstWhere((e) => e.value['name'] == name).key;

    final castle = idOf('Ravenloft');
    final ireena = idOf('Ireena');
    final strahdId = idOf('Strahd');
    for (final id in [castle, ireena, strahdId]) {
      expect(id, isNot(startsWith('e-')));
    }

    final strahd = entities[strahdId] as Map;
    expect(strahd['location_id'], castle);
    expect(strahd['attributes']['ally_ref'], ireena);
    expect(strahd['description'], startsWith('@[Ireena](entity:$ireena) '));

    // Fork, kopyanın kendi synth id'sine geçer — SRD sentezi onu örter.
    final fork = synthBuiltinEntityId(dst, 'pe-goblin');
    expect(entities[fork]?['name'], 'Goblin (homebrew)');
    expect(strahd['attributes']['minions'], [castle, fork]);

    final session = (copy['sessions'] as List).single as Map;
    expect(session['id'], isNot('s-1'));
    expect(session['combatants'][0]['entity_id'], strahdId);
    expect(copy['map_data']['pins'][0]['entity_id'], castle);
    expect(copy['mind_maps'][0]['nodes'][0]['entityId'], ireena);

    final links = await db.installedPackagesDao.getByWorld(dst);
    expect(links.map((l) => l.packageId), ['pkg-srd']);
  });

  test('kopyanın dosyaları kendi klasöründe', () async {
    final dst = await repo.copy(sourceId: src, destinationName: 'Kopya');
    final copy = await repo.load(dst);
    final strahd = (copy['entities'] as Map)
        .values
        .firstWhere((e) => e['name'] == 'Strahd') as Map;
    final paths = [
      strahd['image_path'] as String,
      (strahd['pdfs'] as List).single as String,
      markdownImageRefs(strahd['description'] as String).single,
    ];

    for (final path in paths) {
      expect(p.isWithin(LocalMediaLocalizer.worldDir(dst), path), isTrue,
          reason: path);
      expect(await File(path).exists(), isTrue, reason: path);
    }
    // Kaynağınkiler yerinde.
    for (final path in [portrait, pdf, mapImage]) {
      expect(await File(path).exists(), isTrue, reason: path);
    }
  });

  // Marketplace ve katalog indirmesi: aynı içerik (aynı id'ler) ikinci kez
  // yeni bir dünyaya yazılıyor.
  test('aynı içerikle yeni dünya açmak ilkini boşaltmaz', () async {
    const dst = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
    final claimed = await repo.claimIds(dst, await repo.load(src));
    await repo.save(dst, claimed.data);

    expect(claimed.ids.keys,
        containsAll(['e-castle', 'e-strahd', 'e-ireena', 's-1', src]));
    expect(await db.worldEntitiesDao.getByWorld(src), hasLength(4));
    expect(await db.worldSessionsDao.getByWorld(src), hasLength(1));
    expect(await db.worldEntitiesDao.getByWorld(dst), hasLength(4));
    expect(await db.worldSessionsDao.getByWorld(dst), hasLength(1));
  });

  test('çakışma yoksa claimIds payload\'a dokunmaz', () async {
    final payload = <String, dynamic>{
      'entities': {
        'e-yeni': {'name': 'Yeni', 'type': 'npc'},
      },
    };
    final claimed = await repo.claimIds('baska-dunya', payload);

    expect(claimed.ids, isEmpty);
    expect(identical(claimed.data, payload), isTrue);
    // Dünyanın kendi id'leri de çakışma sayılmaz (yeniden kurulum).
    final own = await repo.claimIds(src, await repo.load(src));
    expect(own.ids, isEmpty);
  });

  // Kalan yollar için ağ: başka dünyanın id'siyle yazılan satır taşınmaz.
  test('başka dünyanın id\'siyle yazım satırı taşımaz', () async {
    await db.worldEntitiesDao.upsertAll([
      WorldEntitiesCompanion.insert(
        id: 'e-castle',
        worldId: 'baska-dunya',
        categorySlug: 'location',
        name: 'Sahte',
      ),
    ]);
    await db.worldSessionsDao.upsert(
      WorldSessionsCompanion.insert(id: 's-1', worldId: 'baska-dunya'),
    );

    final castle = (await db.worldEntitiesDao.getById('e-castle'))!;
    expect(castle.worldId, src);
    expect(castle.name, 'Ravenloft');
    expect((await db.worldSessionsDao.getById('s-1'))!.worldId, src);

    // Kendi dünyasında güncelleme eskisi gibi.
    await db.worldEntitiesDao.upsert(
      castle.toCompanion(false).copyWith(name: const Value('Castle Ravenloft')),
    );
    expect((await db.worldEntitiesDao.getById('e-castle'))!.name,
        'Castle Ravenloft');
  });
}
