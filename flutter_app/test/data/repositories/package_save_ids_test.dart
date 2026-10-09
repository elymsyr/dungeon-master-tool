import 'package:dungeon_master_tool/core/utils/deep_copy.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Aynı paket payload'ını (aynı `package_id`, aynı kart id'leri) ikinci bir
/// adla kaydetmek — marketplace'ten aynı ilanı iki kez indirmek ya da
/// katalogdan kopya kurmak — ilk paketi boşaltmamalı.
void main() {
  late AppDatabase db;
  late PackageRepositoryImpl repo;

  setUp(() {
    db = openTestDatabase();
    repo = PackageRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Map<String, dynamic> payload() => {
        'package_id': 'pkg-publisher',
        'package_name': 'Yayıncı',
        'entities': {
          'e-sword': {
            'name': 'Kılıç',
            'type': 'equipment',
            'description': '@[Kalkan](entity:e-shield) ile iyi gider.',
            'attributes': <String, dynamic>{},
          },
          'e-shield': {
            'name': 'Kalkan',
            'type': 'equipment',
            'attributes': {'pair_ref': 'e-sword'},
          },
        },
      };

  test('ikinci indirme ilk paketin satırlarını ve adını almaz', () async {
    await repo.save('Paket', deepCopyJson(payload()) as Map<String, dynamic>);
    await repo.save(
        'Paket (imported)', deepCopyJson(payload()) as Map<String, dynamic>);

    final first = await repo.load('Paket');
    final second = await repo.load('Paket (imported)');
    expect(first['package_id'], 'pkg-publisher');
    expect((first['entities'] as Map).keys, {'e-sword', 'e-shield'});
    expect(second['package_id'], isNot('pkg-publisher'));

    final ents = second['entities'] as Map<String, dynamic>;
    expect(ents.length, 2);
    expect(ents.keys.toSet().intersection({'e-sword', 'e-shield'}), isEmpty);
    final sword = ents.values.firstWhere((e) => e['name'] == 'Kılıç') as Map;
    final shield = ents.entries.firstWhere((e) => e.value['name'] == 'Kalkan');
    final swordId = ents.entries.firstWhere((e) => e.value['name'] == 'Kılıç').key;
    // Paket içi ref ve bahsetme kopyanın kartını gösterir.
    expect(sword['description'], '@[Kalkan](entity:${shield.key}) ile iyi gider.');
    expect((shield.value['attributes'] as Map)['pair_ref'], swordId);
  });

  test('kendi paketini yeniden kaydetmek id değiştirmez', () async {
    await repo.save('Paket', deepCopyJson(payload()) as Map<String, dynamic>);
    final again = await repo.load('Paket');
    await repo.save('Paket', again);
    final reloaded = await repo.load('Paket');
    expect(reloaded['package_id'], 'pkg-publisher');
    expect((reloaded['entities'] as Map).keys, {'e-sword', 'e-shield'});
  });
}
