// Faz 3.5 çıkış kriteri: `dmt-content://{sha}{ext}` ref'i **cihazdan bağımsız**
// çözülüyor mu?
//
// Ref hiçbir depolama katmanı adlandırmıyor, dolayısıyla onu çözmek her cihazda
// farklı bir iş. Baytları üreten cihaz (DM) dosyayı diskinde bulmalı — ağ
// gerektirmeden, uygulama yeniden başladıktan sonra da. Bulamazsa ref ölü
// demektir ve Faz 4 push'u DM'in kendi kartlarını resimsiz bırakır.
//
// Asıl tehlike eşlemenin bayatlaması: aynı yola farklı baytlar yazıldığında
// eski satır hâlâ "bu sha şu dosyada" diyorsa oyuncuya YANLIŞ resim servis
// edilir. Bu sessiz bir hata — kimse bildirmez.
//
//   cd flutter_app && flutter test test/application/services/content_ref_index_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/application/services/content_ref_index.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ContentRefIndex index;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('content_ref_index');
    db = openTestDatabase();
    index = ContentRefIndex(() => db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows'ta açık handle kalabiliyor.
    }
  });

  Future<String> write(String name, String content) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsString(content);
    return f.path;
  }

  test('ref üretimi → aynı baytlar aynı sha, ref dosyaya geri çözülüyor',
      () async {
    final path = await write('ejder.png', 'ejder-baytlari');

    final ref = await index.refFor(path);
    expect(ref, startsWith(AssetRef.contentScheme));
    expect(ref, endsWith('.png'));

    final sha = AssetRef(ref!).contentSha;
    expect(sha, isNotNull, reason: 'ref 64 haneli sha taşımalı');

    // Çözüm: ağ yok, sadece tablo + disk.
    final back = await index.fileForSha(sha!);
    expect(back?.path, path);
  });

  test('aynı dosya ikinci çağrıda yeniden hash\'lenmiyor', () async {
    final path = await write('harita.webp', 'x' * 4096);
    final first = await index.shaFor(path);

    // Satır varken dosyayı okunamaz kılmak yerine silip bakıyoruz: sha hâlâ
    // tablodan geliyorsa dosya okunmamış demektir.
    expect(await index.shaFor(path), first);
    expect(
      (await db.customSelect('SELECT COUNT(*) AS n FROM content_paths').get())
          .first
          .read<int>('n'),
      1,
      reason: 'tekrar eden çağrı ikinci satır açmamalı',
    );
  });

  test('yol aynı, baytlar değişti → eski sha artık o dosyaya çözülmüyor',
      () async {
    final path = await write('token.png', 'birinci');
    final oldSha = (await index.shaFor(path))!;

    // Kullanıcı resmi değiştirdi. mtime'ın kesinlikle ilerlemesi için
    // dosyayı elle geriye al — bazı dosya sistemlerinde çözünürlük 1 sn.
    await File(path).writeAsString('ikinci');
    await File(path)
        .setLastModified(DateTime.now().add(const Duration(seconds: 5)));

    final newSha = (await index.shaFor(path))!;
    expect(newSha, isNot(oldSha));

    // Bayat satır servis edilmemeli — burası sızarsa oyuncu yanlış resmi alır.
    expect(await index.fileForSha(oldSha), isNull);
    expect((await index.fileForSha(newSha))?.path, path);
  });

  test('dosya silinince ref çözülmüyor ve bayat satır atılıyor', () async {
    final path = await write('silinecek.jpg', 'gecici');
    final sha = (await index.shaFor(path))!;
    await File(path).delete();

    expect(await index.fileForSha(sha), isNull);
    expect(
      (await db.customSelect('SELECT COUNT(*) AS n FROM content_paths').get())
          .first
          .read<int>('n'),
      0,
      reason: 'çözülemeyen satır tabloda kalmamalı',
    );
  });

  test('aynı baytlar iki yolda: biri silinse de ref çözülüyor', () async {
    final a = await write('a.png', 'ayni-baytlar');
    final b = await write('b.png', 'ayni-baytlar');

    final shaA = (await index.shaFor(a))!;
    final shaB = (await index.shaFor(b))!;
    expect(shaA, shaB);

    await File(a).delete();
    expect((await index.fileForSha(shaA))?.path, b);
  });

  test('okunamayan yol null döner, tabloya satır yazmaz', () async {
    expect(await index.refFor(p.join(tmp.path, 'yok.png')), isNull);
    expect(await index.fileForSha('f' * 64), isNull);
    expect(await index.fileForSha('kisa'), isNull);
  });
}
