import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/services/first_party_art_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

/// Paket/dünya silindikten sonra sahipsiz kalan kart görselleri gitmeli,
/// hâlâ bir kartın gösterdiği görsel kalmalı.
void main() {
  late Directory tmp;
  late AppDatabase db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('art_sweep_test');
    AppPaths.cacheDir = p.join(tmp.path, 'cache');
    db = openTestDatabase();
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('referanssız görseller silinir, referanslı olan kalır', () async {
    final artDir = Directory(p.join(AppPaths.cacheDir, 'art'))
      ..createSync(recursive: true);
    for (final n in ['keep.webp', 'gone.webp', 'orphan.webp']) {
      File(p.join(artDir.path, n)).writeAsBytesSync([1]);
    }

    await db.into(db.packages).insert(PackagesCompanion.insert(
        id: 'pkg1', name: 'Pack'));
    await db.into(db.packageEntities).insert(PackageEntitiesCompanion.insert(
          id: 'e1',
          packageId: 'pkg1',
          categorySlug: 'monster',
          name: 'Kobold',
          imagePath: const Value('dmt-art://keep.webp'),
        ));

    final removed = await FirstPartyArtService.sweepUnreferenced(db);

    expect(removed, 2);
    expect(File(p.join(artDir.path, 'keep.webp')).existsSync(), isTrue);
    expect(File(p.join(artDir.path, 'gone.webp')).existsSync(), isFalse);
  });

  test('cope giden paketin gorselleri durur (geri al kartsiz gelmesin)',
      () async {
    final artDir = Directory(p.join(AppPaths.cacheDir, 'art'))
      ..createSync(recursive: true);
    File(p.join(artDir.path, 'trashed.webp')).writeAsBytesSync([1]);
    File(p.join(artDir.path, 'orphan.webp')).writeAsBytesSync([1]);

    await db.into(db.trashItems).insert(TrashItemsCompanion.insert(
          id: 't1',
          kind: 'package',
          sourceId: 'pkg1',
          payloadJson: '{"entities":{"e1":{"image_path":'
              '"dmt-art://trashed.webp"}}}',
        ));

    expect(await FirstPartyArtService.sweepUnreferenced(db), 1);
    expect(File(p.join(artDir.path, 'trashed.webp')).existsSync(), isTrue);
  });

  test('kopyalanan dunya ayni gorseli paylasir, biri silinince durur',
      () async {
    final artDir = Directory(p.join(AppPaths.cacheDir, 'art'))
      ..createSync(recursive: true);
    File(p.join(artDir.path, 'shared.webp')).writeAsBytesSync([1]);

    // Iki dunya, ayni art ref'i (kopyalama ref'i aynen tasir).
    for (final w in ['w1', 'w2']) {
      await db.into(db.worlds).insert(
          WorldsCompanion.insert(id: w, worldName: 'W $w'));
      await db.into(db.worldEntities).insert(WorldEntitiesCompanion.insert(
            id: 'e_$w',
            worldId: w,
            categorySlug: 'monster',
            name: 'Kobold',
            imagePath: const Value('dmt-art://shared.webp'),
          ));
    }

    // w1 silindi -> gorsel w2'de duruyor, kalmali.
    await (db.delete(db.worldEntities)
          ..where((t) => t.worldId.equals('w1')))
        .go();
    expect(await FirstPartyArtService.sweepUnreferenced(db), 0);
    expect(File(p.join(artDir.path, 'shared.webp')).existsSync(), isTrue);

    // w2 de gitti -> artik sahipsiz.
    await (db.delete(db.worldEntities)
          ..where((t) => t.worldId.equals('w2')))
        .go();
    expect(await FirstPartyArtService.sweepUnreferenced(db), 1);
  });
}
