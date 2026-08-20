// Ham seçici yollarının veri kökü içine alınması.
//
// Kural: seçilen her medya kopyalanır — bulut yüklemesi başarılı olsun ya da
// olmasın. Ham bir yol (`.../Downloads/map.png`) LAN eşlemesinde taşınmıyor
// (`LanSyncSession._mediaFor` yalnız içeriğin kendi klasörünü tarıyor) ve
// kullanıcı dosyayı taşırsa büsbütün kayboluyor.
//
//   cd flutter_app && flutter test test/application/services/local_media_localizer_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late Directory outside;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('local_media_localizer');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);
    outside = Directory(p.join(tmp.path, 'disarida'));
    await outside.create(recursive: true);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows'ta açık handle kalabiliyor — test sonucunu etkilemesin.
    }
  });

  Future<String> writeFile(String name, [String body = 'x']) async {
    final f = File(p.join(outside.path, name));
    await f.writeAsString(body);
    return f.path;
  }

  group('dünya medyası', () {
    test('ham yol dünyanın media klasörüne kopyalanır', () async {
      final src = await writeFile('battle.png');

      final out = await LocalMediaLocalizer.localize(
        src,
        ownerDir: LocalMediaLocalizer.worldDir('Barovia'),
      );

      expect(
        out,
        p.join(AppPaths.worldsDir, 'Barovia', 'media', 'battle.png'),
      );
      expect(await File(out).readAsString(), 'x');
      // Orijinal silinmez — kullanıcının dosyasına dokunmuyoruz.
      expect(await File(src).exists(), isTrue);
    });

    test('zaten dünya klasöründeyse dokunulmaz', () async {
      final src = await writeFile('battle.png');
      final once = await LocalMediaLocalizer.localize(
        src,
        ownerDir: LocalMediaLocalizer.worldDir('Barovia'),
      );
      final twice = await LocalMediaLocalizer.localize(
        once,
        ownerDir: LocalMediaLocalizer.worldDir('Barovia'),
      );
      expect(twice, once);
    });

    test('bulut ref ve var olmayan yol olduğu gibi döner', () async {
      const cloud = 'dmt-asset://abc/def.png';
      expect(
        await LocalMediaLocalizer.localize(
          cloud,
          ownerDir: LocalMediaLocalizer.worldDir('Barovia'),
        ),
        cloud,
      );
      final missing = p.join(outside.path, 'yok.png');
      expect(
        await LocalMediaLocalizer.localize(
          missing,
          ownerDir: LocalMediaLocalizer.worldDir('Barovia'),
        ),
        missing,
      );
    });

    test('resim olmayan dosya varsayılanda atlanır, imagesOnly:false ile alınır',
        () async {
      final src = await writeFile('elkitabi.pdf');
      final owner = LocalMediaLocalizer.worldDir('Barovia');

      expect(await LocalMediaLocalizer.localize(src, ownerDir: owner), src);

      final out = await LocalMediaLocalizer.localize(
        src,
        ownerDir: owner,
        subDir: LocalMediaLocalizer.filesSubDir,
        imagesOnly: false,
      );
      expect(
        out,
        p.join(AppPaths.worldsDir, 'Barovia', 'files', 'elkitabi.pdf'),
      );
    });
  });

  group('karakter medyası', () {
    test('düz dizine {id}_ önekiyle kopyalanır', () async {
      final src = await writeFile('portre.png');

      final out = await LocalMediaLocalizer.localizeCharacterImage(
        src,
        characterId: 'char-1',
      );

      expect(out, p.join(AppPaths.charactersDir, 'char-1_portre.png'));
      expect(await File(out).exists(), isTrue);
    });

    test('doğru klasörde ama öneksiz duran dosya da kopyalanır', () async {
      // `_mediaFor` karakter dosyalarını `{id}_` önekiyle süzüyor; öneksiz bir
      // dosya doğru klasörde olsa bile eşlemeye girmez.
      final stray = File(p.join(AppPaths.charactersDir, 'portre.png'));
      await stray.create(recursive: true);
      await stray.writeAsString('x');

      final out = await LocalMediaLocalizer.localizeCharacterImage(
        stray.path,
        characterId: 'char-1',
      );

      expect(p.basename(out), 'char-1_portre.png');
    });

    test('idempotent — ikinci çağrı yeni kopya üretmez', () async {
      final src = await writeFile('portre.png');
      final once = await LocalMediaLocalizer.localizeCharacterImage(
        src,
        characterId: 'char-1',
      );
      final twice = await LocalMediaLocalizer.localizeCharacterImage(
        once,
        characterId: 'char-1',
      );
      expect(twice, once);
    });
  });

  test('payload taraması iç içe ham yolları düzeltir', () async {
    final battle = await writeFile('battle.png');
    final node = await writeFile('node.png');
    final payload = <String, dynamic>{
      'combat_state': {
        'encounters': [
          {'mapPath': battle},
        ],
      },
      'mind_maps': {
        'm1': {
          'nodes': [
            {'imageUrl': node},
          ],
        },
      },
    };

    expect(
      await LocalMediaLocalizer.localizeWorldPayload(payload, 'Barovia'),
      isTrue,
    );

    final mediaDir = p.join(AppPaths.worldsDir, 'Barovia', 'media');
    final mapPath = ((payload['combat_state'] as Map)['encounters'] as List)
        .first['mapPath'] as String;
    final nodePath = (((payload['mind_maps'] as Map)['m1'] as Map)['nodes']
        as List).first['imageUrl'] as String;
    expect(p.dirname(mapPath), mediaDir);
    expect(p.dirname(nodePath), mediaDir);

    // İkinci geçiş değişiklik bildirmemeli — gereksiz dünya kaydı olmasın.
    expect(
      await LocalMediaLocalizer.localizeWorldPayload(payload, 'Barovia'),
      isFalse,
    );
  });
}
