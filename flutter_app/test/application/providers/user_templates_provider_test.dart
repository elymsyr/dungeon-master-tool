import 'dart:io';

import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('user_templates_');
    file = File('${dir.path}/dmt.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Opens the file database in a fresh container, like an app start.
  Future<(ProviderContainer, Future<void> Function())> open() async {
    final db = openTestDatabaseAt(file);
    final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)]);
    return (
      c,
      () async {
        c.dispose();
        await db.close();
      },
    );
  }

  test('copy, settings, create empty and delete persist across reopen',
      () async {
    var (c, close) = await open();
    final n = c.read(userTemplatesProvider.notifier);
    // Only the ready-made SRD free template, which can't be changed.
    expect(await c.read(userTemplatesProvider.future), [srdFreeTemplate]);
    await n.save(srdFreeTemplate.copyWith(name: 'x'));
    await n.delete(srdFreeTemplateId);

    final builtin = generateBuiltinDnd5eV2Schema().schema;
    final a = await n.copy(builtin, 'SRD copy');
    final b = await n.copy(a, 'Second');
    final e = await n.createEmpty('Empty', playerCardName: 'Player');
    await n.saveInfo(a.schemaId,
        name: 'My SRD',
        description: 'mine',
        tags: const ['homebrew'],
        coverImagePath: '/covers/srd.png');
    await n.delete(b.schemaId);
    await close();

    (c, close) = await open();
    final list = (await c.read(userTemplatesProvider.future)).skip(1);
    expect(list.map((t) => t.name), ['My SRD', 'Empty']);
    expect(list.map((t) => t.schemaId), [a.schemaId, e.schemaId]);
    expect(list.first.categories, hasLength(builtin.categories.length));
    expect(list.every(isFreeTemplate), isTrue);
    expect(list.first.originalHash, a.originalHash);
    expect(list.first.description, 'mine');
    expect(list.first.metadata['tags'], ['homebrew']);
    expect(list.first.metadata['cover_image_path'], '/covers/srd.png');
    await close();
  });

  test('built-in flows never see free templates', () async {
    final (c, close) = await open();
    await c
        .read(userTemplatesProvider.notifier)
        .createEmpty('Empty', playerCardName: 'Player');
    final offered = await c.read(allTemplatesProvider.future);
    expect(offered.map((t) => t.schemaId), [builtinDnd5eV2SchemaId]);
    expect(offered.any(isFreeTemplate), isFalse);
    await close();
  });
}
