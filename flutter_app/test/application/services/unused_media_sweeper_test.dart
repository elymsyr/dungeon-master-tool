// Dünyanın `media/` + `files/` klasörlerindeki referanssız dosyaların
// temizlenmesi.
//
// Seçilen her dosya artık dünyanın kendi klasörüne kopyalanıyor
// (`LocalMediaLocalizer`), ama resmi kaldırma yolları yalnız bulut nesnesini
// siliyor. Süpürge olmadan yerel kopya sonsuza kadar kalır ve LAN eşlemesi
// dünya klasörünün tamamını taşıdığı için her cihaza yayılır.
//
//   cd flutter_app && flutter test test/application/services/unused_media_sweeper_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';
import 'package:dungeon_master_tool/application/services/unused_media_sweeper.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

void main() {
  late Directory tmp;
  late AppDatabase db;
  late UnusedMediaSweeper sweeper;

  const worldName = 'Barovia';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('unused_media_sweeper');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);
    db = openTestDatabase();
    sweeper = UnusedMediaSweeper(db);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {
      // Windows'ta açık handle kalabiliyor.
    }
  });

  /// [fresh] false ise dosya grace window'un dışına taşınır (süpürülebilir).
  Future<String> media(String name, {bool fresh = false, String sub = 'media'}) async {
    final f = File(
      p.join(LocalMediaLocalizer.worldDir(worldName), sub, name),
    );
    await f.create(recursive: true);
    await f.writeAsString('x');
    if (!fresh) {
      await f.setLastModified(
        DateTime.now().subtract(UnusedMediaSweeper.graceWindow * 2),
      );
    }
    return f.path;
  }

  Future<int> sweep(Map<String, dynamic> payload) =>
      sweeper.sweepWorld(worldName: worldName, payload: payload);

  test('referanssız dosya silinir, referanslı kalır', () async {
    final used = await media('kullanilan.png');
    final orphan = await media('sahipsiz.png');

    final removed = await sweep({
      'combat_state': {
        'encounters': [
          {'mapPath': used},
        ],
      },
    });

    expect(removed, 1);
    expect(await File(used).exists(), isTrue);
    expect(await File(orphan).exists(), isFalse);
  });

  test('iç içe her yerdeki referans sayılır (mindmap, entity, files/)',
      () async {
    final node = await media('node.png');
    final portrait = await media('portre.png');
    final attachment = await media('elkitabi.pdf', sub: 'files');
    final orphan = await media('sahipsiz.png');

    final removed = await sweep({
      'mind_maps': {
        'm1': {
          'nodes': [
            {'imageUrl': node},
          ],
        },
      },
      'entities': {
        'e1': {
          'images': [portrait],
          'fields': {
            'attachments': [attachment],
          },
        },
      },
    });

    expect(removed, 1);
    expect(await File(node).exists(), isTrue);
    expect(await File(portrait).exists(), isTrue);
    expect(await File(attachment).exists(), isTrue);
    expect(await File(orphan).exists(), isFalse);
  });

  test('yeni yazılmış dosyaya dokunulmaz', () async {
    // LAN eşlemesi dosyayı payload'dan önce yazabiliyor; grace window bunu
    // yanlışlıkla silmemek için.
    final fresh = await media('yeni.png', fresh: true);

    expect(await sweep(const {}), 0);
    expect(await File(fresh).exists(), isTrue);
  });

  test('çöp kutusundaki entity referansı korunur', () async {
    // Silinen entity geri alındığında resmi yerinde durmalı.
    final trashed = await media('cop.png');
    await db.trashDao.upsert(TrashItemsCompanion.insert(
      id: 't1',
      kind: 'entity',
      sourceId: 'e1',
      payloadJson: jsonEncode({
        'id': 'e1',
        'images': [trashed],
      }),
      deletedAt: Value(DateTime.now()),
    ));

    expect(await sweep(const {}), 0);
    expect(await File(trashed).exists(), isTrue);
  });

  test('pdfs/ klasörüne dokunulmaz', () async {
    // PDF kütüphanesi kendi klasörünü yönetiyor; süpürge kapsamı dışında.
    final pdf = await media('kutuphane.pdf', sub: 'pdfs');

    expect(await sweep(const {}), 0);
    expect(await File(pdf).exists(), isTrue);
  });

  test('klasör yoksa hata vermez', () async {
    expect(
      await sweeper.sweepWorld(worldName: 'Yok', payload: const {}),
      0,
    );
  });
}
