// Bölüm bazlı dünya birleştirmesi — saf fonksiyon, I/O yok.
//
// Eşleme daha önce item seviyesinde LWW'ydi: aynı dünya iki cihazda
// düzenlendiğinde kazanan tarafın payload'ı diğerini olduğu gibi eziyordu
// (A'da savaş notu, B'de mindmap → biri kayboluyor). Buradaki tablo o
// davranışın geri gelmemesini bekliyor.
//
//   cd flutter_app && flutter test test/application/services/lan_sync/world_merge_test.dart

import 'package:dungeon_master_tool/application/services/lan_sync/world_merge.dart';
import 'package:dungeon_master_tool/domain/value_objects/world_section_stamps.dart';
import 'package:flutter_test/flutter_test.dart';

final _old = DateTime.utc(2026, 1, 1);
final _new = DateTime.utc(2026, 6, 1);

Map<String, dynamic> _merge({
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
  WorldSectionStamps localStamps = WorldSectionStamps.empty,
  WorldSectionStamps remoteStamps = WorldSectionStamps.empty,
  DateTime? localFallback,
  DateTime? remoteFallback,
}) =>
    mergeWorldPayloads(
      local: local,
      remote: remote,
      localStamps: localStamps,
      remoteStamps: remoteStamps,
      localFallback: localFallback ?? _old,
      remoteFallback: remoteFallback ?? _old,
    );

void main() {
  group('settings bölümleri', () {
    test('her anahtar kendi damgasıyla yarışır', () {
      final out = _merge(
        local: {
          'combat_state': {'session_notes': 'YEREL NOT'},
          'mind_maps': {'m1': 'yerel-eski'},
        },
        remote: {
          'combat_state': {'session_notes': 'UZAK NOT'},
          'mind_maps': {'m1': 'uzak-eski'},
        },
        localStamps: WorldSectionStamps(
          settings: {'combat_state': _new, 'mind_maps': _old},
        ),
        remoteStamps: WorldSectionStamps(
          settings: {'combat_state': _old, 'mind_maps': _new},
        ),
      );
      // Asıl vaat: iki tarafın da işi duruyor.
      expect((out['combat_state'] as Map)['session_notes'], 'YEREL NOT');
      expect((out['mind_maps'] as Map)['m1'], 'uzak-eski');
    });

    test('kazanan tarafın damgası çıktıya yazılır', () {
      final out = _merge(
        local: {'mind_maps': 1},
        remote: {'mind_maps': 2},
        localStamps: WorldSectionStamps(settings: {'mind_maps': _old}),
        remoteStamps: WorldSectionStamps(settings: {'mind_maps': _new}),
      );
      expect(readSectionStamps(out)['mind_maps'], _new);
    });

    test('yalnız tek tarafta olan anahtar korunur', () {
      final out = _merge(
        local: {'pdf_library': ['yerel.pdf']},
        remote: {'soundpad': ['uzak.mp3']},
      );
      expect(out['pdf_library'], ['yerel.pdf']);
      expect(out['soundpad'], ['uzak.mp3']);
    });

    test('damga yoksa item seviyesindeki updatedAt kullanılır', () {
      final out = _merge(
        local: {'combat_state': 'yerel'},
        remote: {'combat_state': 'uzak'},
        localFallback: _old,
        remoteFallback: _new,
      );
      expect(out['combat_state'], 'uzak');
    });

    test('eşitlikte yerel kazanır — ping-pong olmasın', () {
      final out = _merge(
        local: {'combat_state': 'yerel'},
        remote: {'combat_state': 'uzak'},
        localStamps: WorldSectionStamps(settings: {'combat_state': _new}),
        remoteStamps: WorldSectionStamps(settings: {'combat_state': _new}),
      );
      expect(out['combat_state'], 'yerel');
    });
  });

  group('entities', () {
    test('id birleşimi alınır, çakışanda yeni damga kazanır', () {
      final out = _merge(
        local: {
          'entities': {
            'e1': {'name': 'Yerel Strahd'},
            'e2': {'name': 'Yalnız yerelde'},
          },
        },
        remote: {
          'entities': {
            'e1': {'name': 'Uzak Strahd'},
            'e3': {'name': 'Yalnız uzakta'},
          },
        },
        localStamps: WorldSectionStamps(entities: {'e1': _old}),
        remoteStamps: WorldSectionStamps(entities: {'e1': _new}),
      );
      final entities = out['entities'] as Map;
      expect(entities.keys, containsAll(['e1', 'e2', 'e3']));
      expect((entities['e1'] as Map)['name'], 'Uzak Strahd');
      expect((entities['e2'] as Map)['name'], 'Yalnız yerelde');
      expect((entities['e3'] as Map)['name'], 'Yalnız uzakta');
    });

    test('iki taraf da anahtarı taşımıyorsa entities üretilmez', () {
      final out = _merge(local: {'combat_state': 1}, remote: {});
      // "metadata-only save" koruması: boş `entities` yazmak dünyayı siler.
      expect(out.containsKey('entities'), isFalse);
    });
  });

  group('sessions', () {
    test('id ile eşlenir, yerel sıra korunur', () {
      final out = _merge(
        local: {
          'sessions': [
            {'id': 's1', 'name': 'Yerel 1'},
            {'id': 's2', 'name': 'Yalnız yerelde'},
          ],
        },
        remote: {
          'sessions': [
            {'id': 's1', 'name': 'Uzak 1'},
            {'id': 's3', 'name': 'Yalnız uzakta'},
          ],
        },
        localStamps: WorldSectionStamps(sessions: {'s1': _new}),
        remoteStamps: WorldSectionStamps(sessions: {'s1': _old}),
      );
      final names =
          (out['sessions'] as List).map((s) => (s as Map)['name']).toList();
      expect(names, ['Yerel 1', 'Yalnız yerelde', 'Yalnız uzakta']);
    });
  });

  group('map_data', () {
    test('kendi damgasına göre seçilir', () {
      final out = _merge(
        local: {
          'map_data': {'image_path': 'yerel.png'}
        },
        remote: {
          'map_data': {'image_path': 'uzak.png'}
        },
        localStamps: WorldSectionStamps(mapData: _old),
        remoteStamps: WorldSectionStamps(mapData: _new),
      );
      expect((out['map_data'] as Map)['image_path'], 'uzak.png');
    });
  });

  group('kimlik alanları', () {
    test('created_at en eski olanda kalır', () {
      final out = _merge(
        local: {'created_at': '2026-01-01T00:00:00.000Z'},
        remote: {'created_at': '2026-06-01T00:00:00.000Z'},
        remoteFallback: _new,
      );
      expect(out['created_at'], '2026-01-01T00:00:00.000Z');
    });

    test('şema item seviyesi LWW ile gelir', () {
      final out = _merge(
        local: {'world_schema': 'yerel'},
        remote: {'world_schema': 'uzak'},
        localFallback: _old,
        remoteFallback: _new,
      );
      expect(out['world_schema'], 'uzak');
    });
  });

  test('girdiler mutate edilmez ve çıktı derin kopyadır', () {
    final local = <String, dynamic>{
      'entities': {
        'e1': {'name': 'Yerel'}
      },
    };
    final remote = <String, dynamic>{'entities': <String, dynamic>{}};
    final out = _merge(local: local, remote: remote);
    (out['entities'] as Map)['e1']['name'] = 'DEĞİŞTİ';
    expect(((local['entities'] as Map)['e1'] as Map)['name'], 'Yerel');
  });

  test('idempotent: birleşim tekrar birleştirilince değişmez', () {
    final local = <String, dynamic>{
      'combat_state': 'yerel',
      'entities': {
        'e1': {'name': 'A'}
      },
    };
    final remote = <String, dynamic>{
      'mind_maps': 'uzak',
      'entities': {
        'e2': {'name': 'B'}
      },
    };
    final stampsLocal = WorldSectionStamps(
      settings: {'combat_state': _new},
      entities: {'e1': _new},
    );
    final stampsRemote = WorldSectionStamps(
      settings: {'mind_maps': _new},
      entities: {'e2': _new},
    );
    final once = _merge(
      local: local,
      remote: remote,
      localStamps: stampsLocal,
      remoteStamps: stampsRemote,
    );
    final merged = mergeSectionStamps(local: stampsLocal, remote: stampsRemote);
    final twice = _merge(
      local: once,
      remote: remote,
      localStamps: merged,
      remoteStamps: stampsRemote,
    );
    expect(twice['combat_state'], once['combat_state']);
    expect(twice['mind_maps'], once['mind_maps']);
    expect((twice['entities'] as Map).keys, (once['entities'] as Map).keys);
  });
}
