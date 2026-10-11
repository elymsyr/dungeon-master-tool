// `.dmtz` for free templates: exported on one data root, imported on another,
// the template comes back with its cover image (path rebased to the new root).
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_archive.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_codec.dart';
import 'package:dungeon_master_tool/application/services/content_transfer/content_item.dart';
import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String zipPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dmtz_template_test');
    zipPath = p.join(tmp.path, 'out', 'template.dmtz');
    await Directory(p.dirname(zipPath)).create(recursive: true);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<(ProviderContainer, AppDatabase)> openRoot(String name) async {
    AppPaths.dataRoot = p.join(tmp.path, name);
    await AppPaths.setUser(null);
    final db = openTestDatabase();
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    return (c, db);
  }

  test('a free template round-trips with its cover', () async {
    final (a, dbA) = await openRoot('a');
    final n = a.read(userTemplatesProvider.notifier);
    await a.read(userTemplatesProvider.future);
    final t = await n.copy(generateBuiltinDnd5eV2Schema().schema, 'Mine');
    final cover = File(
      p.join(LocalMediaLocalizer.templateDir(t.schemaId), 'media', 'c.png'),
    );
    await cover.create(recursive: true);
    await cover.writeAsBytes(utf8.encode('cover'));
    await n.saveInfo(
      t.schemaId,
      name: 'Mine',
      description: 'd',
      tags: const ['x'],
      coverImagePath: cover.path,
    );

    expect(
      await exportContentArchive(
        codec: a.read(contentCodecProvider),
        type: ContentItemType.template,
        id: t.schemaId,
        path: zipPath,
      ),
      isTrue,
    );
    // The built-in template is not an exportable item.
    expect(
      await exportContentArchive(
        codec: a.read(contentCodecProvider),
        type: ContentItemType.template,
        id: builtinDnd5eV2SchemaId,
        path: p.join(tmp.path, 'out', 'builtin.dmtz'),
      ),
      isFalse,
    );
    a.dispose();
    await dbA.close();

    final (b, dbB) = await openRoot('b');
    addTearDown(() async {
      b.dispose();
      await dbB.close();
    });
    final archive = await ContentArchive.open(zipPath);
    try {
      final result = await archive.applyTo(b.read(contentCodecProvider));
      expect(result.ref.type, ContentItemType.template);
    } finally {
      await archive.close();
    }

    final list = await b.read(userTemplatesProvider.future);
    expect(list.map((x) => x.schemaId), [t.schemaId]);
    expect(list.single.name, 'Mine');
    expect(list.single.categories, hasLength(t.categories.length));
    final newCover = list.single.metadata['cover_image_path'] as String;
    expect(p.isWithin(AppPaths.dataRoot, newCover), isTrue);
    expect(await File(newCover).readAsString(), 'cover');
  });
}
