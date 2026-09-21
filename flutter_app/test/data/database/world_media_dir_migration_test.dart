// Dünya medya klasörü isimden id'ye (Faz 2.5).
//
// Klasör isimle anahtarlıyken iki dünya aynı adı taşıyamıyordu: taşısalardı
// aynı klasörü paylaşır, birini açıp kapatmak `UnusedMediaSweeper` üzerinden
// ötekinin dosyalarını silerdi. Migration `beforeOpen`'da bir kez çalışıp
// klasörleri `worlds/<id>`'ye taşıyor ve gövdedeki **mutlak** yolları
// yeniden yazıyor.
//
// Asıl tuzak önek eşleşmesi: "Ad" dünyasının klasör yolu "Ad2" dünyasının
// yollarının öneki. Ayıraç eşleştirmeye dahil edilmezse ikincisinin bütün
// resimleri bozuk bir yola çevrilir.
//
//   cd flutter_app && flutter test test/data/database/world_media_dir_migration_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late File dbFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_dir_mig');
    AppPaths.dataRoot = p.join(tmp.path, 'data');
    await AppPaths.setUser(null);
    dbFile = File(p.join(tmp.path, 'dmt.sqlite'));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// İsimle anahtarlı eski düzeni kurar: klasör + içindeki dosya + gövdede
  /// o dosyayı gösteren mutlak yol. Yazdığı dosyanın yolunu döndürür.
  Future<String> seedLegacyWorld(
    AppDatabase db, {
    required String id,
    required String name,
  }) async {
    final legacyDir = p.join(AppPaths.worldsDir, LocalMediaLocalizer.dirSafe(name));
    final img = File(p.join(legacyDir, 'media', 'kapak.png'));
    await img.create(recursive: true);
    await img.writeAsBytes(utf8.encode('bytes-of-$id'));

    await db.worldsDao.upsert(WorldsCompanion.insert(id: id, worldName: name));
    await db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
      id: 'e-$id',
      worldId: id,
      categorySlug: 'npc',
      name: 'Strahd',
      imagePath: Value(img.path),
    ));
    await db.worldSettingsDao.upsert(WorldSettingsCompanion.insert(
      worldId: id,
      settingsJson: Value(jsonEncode({
        'combat_state': {
          'encounters': [
            {'id': 'enc1', 'map_path': img.path},
          ],
        },
      })),
    ));
    return img.path;
  }

  /// Migration'ı yeniden çalıştırılabilir yapar — `beforeOpen` kapısı
  /// `migration_progress` satırında.
  Future<void> reopenUnmigrated(AppDatabase db) async {
    await db.customStatement(
      "DELETE FROM migration_progress "
      "WHERE migration_name = 'world_media_dir_by_id_v1'",
    );
    await db.close();
  }

  test('klasör id ile yeniden adlandırılır ve gövdedeki yollar çevrilir',
      () async {
    var db = openTestDatabaseAt(dbFile);
    final legacyPath =
        await seedLegacyWorld(db, id: 'w-1', name: 'Fırtına Vadisi');
    await reopenUnmigrated(db);

    db = openTestDatabaseAt(dbFile);
    // `beforeOpen` ilk sorguda çalışır.
    final row = await db.worldEntitiesDao.getById('e-w-1');
    await db.close();

    final newDir = LocalMediaLocalizer.worldDir('w-1');
    expect(Directory(newDir).existsSync(), isTrue, reason: 'klasör taşınmadı');
    expect(Directory(p.dirname(legacyPath)).existsSync(), isFalse,
        reason: 'eski klasör duruyor');
    expect(row!.imagePath, p.join(newDir, 'media', 'kapak.png'),
        reason: 'entity yolu çevrilmedi');
    expect(File(row.imagePath).readAsBytesSync(), utf8.encode('bytes-of-w-1'),
        reason: 'baytlar taşınmadı');
  });

  test('JSON blob içindeki yollar da çevrilir', () async {
    var db = openTestDatabaseAt(dbFile);
    await seedLegacyWorld(db, id: 'w-2', name: 'Barovia');
    await reopenUnmigrated(db);

    db = openTestDatabaseAt(dbFile);
    final settings = await db.worldSettingsDao.get('w-2');
    await db.close();

    final decoded = jsonDecode(settings!.settingsJson) as Map<String, dynamic>;
    final mapPath = ((decoded['combat_state'] as Map)['encounters'] as List)
        .first['map_path'] as String;
    expect(mapPath, p.join(LocalMediaLocalizer.worldDir('w-2'), 'media',
        'kapak.png'));
    expect(File(mapPath).existsSync(), isTrue);
  });

  test('önek çakışması: "Ad" dünyası "Ad2"nin yollarını bozmaz', () async {
    var db = openTestDatabaseAt(dbFile);
    await seedLegacyWorld(db, id: 'w-a', name: 'Ad');
    await seedLegacyWorld(db, id: 'w-ab', name: 'Ad2');
    await reopenUnmigrated(db);

    db = openTestDatabaseAt(dbFile);
    final a = await db.worldEntitiesDao.getById('e-w-a');
    final ab = await db.worldEntitiesDao.getById('e-w-ab');
    await db.close();

    expect(a!.imagePath,
        p.join(LocalMediaLocalizer.worldDir('w-a'), 'media', 'kapak.png'));
    expect(ab!.imagePath,
        p.join(LocalMediaLocalizer.worldDir('w-ab'), 'media', 'kapak.png'));
    expect(File(a.imagePath).readAsBytesSync(), utf8.encode('bytes-of-w-a'));
    expect(File(ab.imagePath).readAsBytesSync(), utf8.encode('bytes-of-w-ab'));
  });

  test('ikinci açılışta tekrar çalışmaz', () async {
    var db = openTestDatabaseAt(dbFile);
    await seedLegacyWorld(db, id: 'w-3', name: 'Eberron');
    await reopenUnmigrated(db);

    db = openTestDatabaseAt(dbFile);
    await db.worldsDao.getById('w-3');
    await db.close();

    // Taşınmış klasöre bir dosya daha koy; ikinci açılış onu kaybetmemeli.
    final marker = File(
        p.join(LocalMediaLocalizer.worldDir('w-3'), 'media', 'ikinci.png'));
    await marker.writeAsBytes(utf8.encode('x'));

    db = openTestDatabaseAt(dbFile);
    final row = await db.worldEntitiesDao.getById('e-w-3');
    await db.close();

    expect(marker.existsSync(), isTrue);
    expect(row!.imagePath,
        p.join(LocalMediaLocalizer.worldDir('w-3'), 'media', 'kapak.png'));
  });
}
