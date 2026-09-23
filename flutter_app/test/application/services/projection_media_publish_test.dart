import 'package:dungeon_master_tool/application/services/projection_output_online.dart';
import 'package:flutter_test/flutter_test.dart';

/// Projeksiyon manifesti buluta çıkmadan önce yerel medya yollarını ref'e
/// çeviriyor mu?
///
/// Bu yürüyüş kırılırsa hata sessiz: oyuncu `world_projection` satırını alır,
/// içindeki `C:\...\media\map.png` onun diskinde yok, battle map arka planı
/// ve token portreleri kırık ikon olarak görünür. DM tarafında hiçbir şey
/// belli olmaz.
void main() {
  Future<String?> fakePublish(String path) async =>
      'dmt-content://${path.hashCode.abs()}.png';

  test('ağaçtaki her yerel medya yolu ref ile değişir', () async {
    final out = await withPublishedMedia({
      'items': [
        {
          'type': 'battleMap',
          'snapshot': {
            'mapPath': r'C:\dmt\worlds\Aegis\media\dungeon.png',
            'fogDataBase64': 'iVBORw0KGgoAAAANSUhEUg/////AAAA',
            'gridSize': 50,
            'tokens': [
              {'id': 't1', 'imagePath': '/data/worlds/a/media/orc.jpg'},
              {'id': 't2', 'imagePath': null},
            ],
          },
        },
      ],
    }, fakePublish) as Map<String, dynamic>;

    final snap = (out['items'] as List).first['snapshot'] as Map;
    expect(snap['mapPath'], startsWith('dmt-content://'));
    expect((snap['tokens'] as List).first['imagePath'],
        startsWith('dmt-content://'));
    // Fog blob'u ve sayısal alanlar dokunulmadan geçmeli.
    expect(snap['fogDataBase64'], 'iVBORw0KGgoAAAANSUhEUg/////AAAA');
    expect(snap['gridSize'], 50);
    expect((snap['tokens'] as List)[1]['imagePath'], isNull);
  });

  test('zaten ref olan yollar publish edilmez', () async {
    final calls = <String>[];
    final out = await withPublishedMedia(
      {
        'a': 'dmt-content://abc.png',
        'b': 'dmt-asset://u/c/def.png',
        'c': 'dmt-public://u/ghi.png',
        'd': 'dmt-art://jkl.webp',
      },
      (p) async {
        calls.add(p);
        return 'dmt-content://x.png';
      },
    ) as Map<String, dynamic>;

    expect(calls, isEmpty);
    expect(out['a'], 'dmt-content://abc.png');
    expect(out['b'], 'dmt-asset://u/c/def.png');
  });

  test('publish başarısızsa yol olduğu gibi kalır', () async {
    final out = await withPublishedMedia(
      {'mapPath': '/data/worlds/a/media/map.png'},
      (_) async => null,
    ) as Map<String, dynamic>;

    expect(out['mapPath'], '/data/worlds/a/media/map.png');
  });

  test('isProjectableLocalMedia yalnızca yerel resim yollarını seçer', () {
    expect(isProjectableLocalMedia('/w/media/a.png'), isTrue);
    expect(isProjectableLocalMedia(r'C:\w\media\a.JPEG'), isTrue);
    expect(isProjectableLocalMedia('dmt-content://a.png'), isFalse);
    expect(isProjectableLocalMedia('Kara Şövalye'), isFalse);
    expect(isProjectableLocalMedia(''), isFalse);
    // Fog base64 blob'u: uzun, uzantısız — regex'e hiç girmemeli.
    expect(isProjectableLocalMedia('A' * 5000), isFalse);
  });
}
