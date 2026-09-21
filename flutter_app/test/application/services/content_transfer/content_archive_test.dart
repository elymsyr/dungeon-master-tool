// `.dmtz` round-trip: bir makinede export edilen dünya, **başka bir veri
// kökünde** import edildiğinde kartlarıyla ve resimleriyle birlikte geri
// gelmeli. İki `AppPaths.dataRoot` kullanılıyor çünkü asıl risk burada:
// payload'daki mutlak yollar alıcının köküne çevrilmezse "kartlar geldi,
// resimler gelmedi" olur.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_archive.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_codec.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_item.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String zipPath;
  const worldId = 'w-barovia';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dmtz_test');
    zipPath = p.join(tmp.path, 'out', 'barovia.dmtz');
    await Directory(p.dirname(zipPath)).create(recursive: true);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Verilen kökü aktif eder ve o kök için taze bir container döndürür.
  Future<(ProviderContainer, AppDatabase)> openRoot(String name) async {
    AppPaths.dataRoot = p.join(tmp.path, name);
    await AppPaths.setUser(null);
    final db = openTestDatabase();
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    return (c, db);
  }

  test('dünya export edilip başka bir veri kökünde geri açılır', () async {
    // ── Makine A ────────────────────────────────────────────────────────
    final (a, dbA) = await openRoot('makine_a');
    final artwork = File(p.join(tmp.path, 'indirilenler', 'strahd.png'));
    await artwork.parent.create(recursive: true);
    await artwork.writeAsBytes(utf8.encode('strahd-portresi'));

    await a.read(campaignRepositoryProvider).save(worldId, {
      'world_name': 'Barovia',
      'entities': {
        'e1': {
          'id': 'e1',
          'name': 'Strahd',
          'type': 'npc',
          // Veri kökünün dışında: export sırasında dünya klasörüne alınmalı.
          'attributes': {'imagePath': artwork.path},
        },
      },
      'sessions': [
        {'id': 's1', 'name': 'Birinci Oturum', 'sort_order': 0},
      ],
    });

    expect(
      await exportContentArchive(
        codec: a.read(contentCodecProvider),
        type: ContentItemType.world,
        id: worldId,
        path: zipPath,
      ),
      isTrue,
    );
    expect(await File(zipPath).exists(), isTrue);
    a.dispose();
    await dbA.close();

    // ── Makine B — hiç ortak dosyası yok ────────────────────────────────
    final (b, dbB) = await openRoot('makine_b');
    addTearDown(() async {
      b.dispose();
      await dbB.close();
    });

    final archive = await ContentArchive.open(zipPath);
    expect(archive.item.ref.name, 'Barovia');
    expect(archive.item.ref.id, worldId);
    final result = await archive.applyTo(b.read(contentCodecProvider));
    await archive.close();

    expect(result.mediaSkipped, 0, reason: 'medya kaybı: $result');
    expect(result.mediaWritten, greaterThan(0));

    final got = await b.read(campaignRepositoryProvider).load(worldId);
    expect((got['sessions'] as List).single['name'], 'Birinci Oturum');

    final imagePath = ((got['entities'] as Map)['e1'] as Map)['attributes']
        ['imagePath'] as String;
    expect(p.isWithin(AppPaths.worldsDir, imagePath), isTrue,
        reason: 'yol B makinesinin köküne çevrilmedi: $imagePath');
    expect(await File(imagePath).readAsBytes(), await artwork.readAsBytes(),
        reason: 'resim baytları taşınmadı');
  });

  test('bilinmeyen format sessizce kabul edilmez', () async {
    final (a, dbA) = await openRoot('makine_a');
    addTearDown(() async {
      a.dispose();
      await dbA.close();
    });
    await a.read(campaignRepositoryProvider).save(worldId, {
      'world_name': 'Barovia',
      'entities': <String, dynamic>{},
    });
    await exportContentArchive(
      codec: a.read(contentCodecProvider),
      type: ContentItemType.world,
      id: worldId,
      path: zipPath,
    );

    // Gelecek sürümün yazdığı bir zip'i taklit et: aynı içerik, daha büyük
    // format numarası.
    final open = await ContentArchive.open(zipPath);
    final item = open.item;
    await open.close();
    final bumped = p.join(tmp.path, 'out', 'v99.dmtz');
    final enc = ZipFileEncoder()..create(bumped);
    enc.addArchiveFile(ArchiveFile.string(
      'manifest.json',
      jsonEncode({...item.ref.toJson(), 'format': 99, 'data_root': '/x'}),
    ));
    enc.addArchiveFile(
        ArchiveFile.string('payload.json', jsonEncode(item.payload)));
    await enc.close();

    await expectLater(
      ContentArchive.open(bumped),
      throwsA(isA<ContentArchiveException>().having(
          (e) => e.error, 'error', ContentArchiveError.unsupportedFormat)),
    );
  });

  test('zip olmayan dosya net hata verir', () async {
    final junk = File(p.join(tmp.path, 'out', 'sahte.dmtz'));
    await junk.writeAsString('bu bir zip değil');
    await expectLater(
      ContentArchive.open(junk.path),
      throwsA(isA<ContentArchiveException>()),
    );
  });
}
