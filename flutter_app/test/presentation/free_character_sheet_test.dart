// Faz 6 (docs/free-template/ROADMAP.md): a free world's character is a
// blank sheet on the world's own copy (no wizard), and rests update it.
//
//   cd flutter_app && flutter test test/presentation/free_character_sheet_test.dart

import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/character_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/providers/free_character_provider.dart';
import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/application/services/pending_write_buffer.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_grants.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/character_editor_screen.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/free_character_sheet.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

const _now = '2026-10-12T00:00:00.000Z';

// The guide auto-opens and scrolls; the Faz 8 test covers it.
final _srdCopy = _unguided(
  copyAsFreeTemplate(
    generateBuiltinDnd5eV2Schema().schema,
    id: 'free-srd',
    name: 'SRD copy',
    now: _now,
  ),
);

/// [s] without its creation guide, for tests about something else.
WorldSchema _unguided(WorldSchema s) => s.copyWith(
  categories: [for (final c in s.categories) c.copyWith(guide: null)],
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> freeWorld() =>
      WorldRepositoryImpl(db).create('Free', template: _srdCopy);

  test('a free world\'s character: level 1, the world\'s own schema', () async {
    final worldId = await freeWorld();
    final schema = await readWorldSchema(db, worldId);
    expect(isFreeTemplate(schema!), isTrue);
    final c = await createFreeCharacter(
      container.read(characterListProvider.notifier),
      schema: schema,
      name: 'Aria',
      worldId: worldId,
    );
    expect(c.templateId, 'free-srd');
    expect(c.entity.fields['level'], 1);
    expect(c.entity.fields['combat_stats'], <String, dynamic>{});

    final drawn = await container.read(
      freeCharacterSchemaProvider((
        worldId: worldId,
        templateId: c.templateId,
      )).future,
    );
    expect(drawn?.schemaId, 'free-srd');
  });

  test('a built-in world\'s character is not free', () async {
    final worldId = await WorldRepositoryImpl(
      db,
    ).create('Built-in', template: generateBuiltinDnd5eV2Schema().schema);
    final drawn = await container.read(
      freeCharacterSchemaProvider((
        worldId: worldId,
        templateId: builtinDnd5eV2SchemaId,
      )).future,
    );
    expect(drawn, isNull);
  });

  test('a worldless character reads its free template', () async {
    final t = await container
        .read(userTemplatesProvider.notifier)
        .copy(generateBuiltinDnd5eV2Schema().schema, 'Mine');
    final drawn = await container.read(
      freeCharacterSchemaProvider((
        worldId: null,
        templateId: t.schemaId,
      )).future,
    );
    expect(drawn?.schemaId, t.schemaId);
  });

  testWidgets('the editor routes to the free sheet; a long rest fills HP', (
    tester,
  ) async {
    late String id;
    await tester.runAsync(() async {
      final worldId = await freeWorld();
      final schema = (await readWorldSchema(db, worldId))!;
      final c = await createFreeCharacter(
        container.read(characterListProvider.notifier),
        schema: schema,
        name: 'Aria',
        worldId: worldId,
      );
      id = c.id;
      await container
          .read(characterListProvider.notifier)
          .update(
            c.copyWith(
              entity: c.entity.copyWith(
                fields: {
                  ...c.entity.fields,
                  'combat_stats': {'hp': 31, 'max_hp': 38},
                },
              ),
            ),
          );
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: buildThemeData('dark'),
          home: CharacterEditorScreen(characterId: id),
        ),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byType(FreeCharacterSheet).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(FreeCharacterSheet), findsOneWidget);
    expect(_chip('Level', '1'), findsOneWidget);
    expect(_chip('HP', '31 / 38'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('free_short_rest')));
    await tester.pump();
    Map<String, dynamic> stats() => Map<String, dynamic>.from(
      container.read(characterByIdProvider(id))!.entity.fields['combat_stats']
          as Map,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(stats()['hp'], 31, reason: 'short rest: HP left as is');

    await tester.tap(find.byKey(const ValueKey('free_long_rest')));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(stats()['hp'], 38);

    // Faz 7a+: the sheet opens in view mode; HP still changes and saves.
    expect(find.byIcon(Icons.edit), findsWidgets, reason: 'view mode');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('cb_combat_stats_hp')),
        matching: find.byType(TextField),
      ),
      '20',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(stats()['hp'], 20);
    expect(stats()['max_hp'], 38);
  });

  testWidgets('Faz 7a: level up grants Action Surge, labelled with its '
      'giver', (tester) async {
    late String id;
    late WorldSchema schema;
    await tester.runAsync(() async {
      schema = _levelTemplate();
      final worldId = await WorldRepositoryImpl(
        db,
      ).create('Levels', template: schema);
      await container.read(activeCampaignProvider.notifier).load(worldId);
      schema = container.read(worldSchemaProvider);
      Entity e(String id, String slug, [Map<String, dynamic> f = const {}]) =>
          Entity(id: id, name: _title(id), categorySlug: slug, fields: f);
      container.read(entityProvider.notifier).addEntities({
        for (final x in [
          e('fighter', 'class', {
            'levels': [
              {
                '_id': 'r1',
                'level': 1,
                'items': [
                  {'_id': 'g1', 'kind': 'card', 'card': 'second_wind'},
                ],
              },
              {
                '_id': 'r2',
                'level': 2,
                'items': [
                  {'_id': 'g2', 'kind': 'card', 'card': 'action_surge'},
                ],
              },
            ],
          }),
          e('second_wind', 'feature'),
          e('action_surge', 'feature'),
        ])
          x.id: x,
      });
      final c = await createFreeCharacter(
        container.read(characterListProvider.notifier),
        schema: schema,
        name: 'Aria',
        worldId: worldId,
      );
      id = c.id;
      await container
          .read(characterListProvider.notifier)
          .update(
            c.copyWith(
              entity: c.entity.copyWith(
                fields: {
                  ...c.entity.fields,
                  'classes': ['fighter'],
                  'features': ['second_wind'],
                  cardLevelsKey: {'fighter': 1},
                  grantedKey: {
                    'second_wind': {'from': 'fighter', 'level': 1},
                  },
                },
              ),
            ),
          );
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: buildThemeData('dark'),
          home: FreeCharacterSheet(characterId: id, schema: schema),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('From Fighter · level 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('free_level_up')));
    await tester.pumpAndSettle();
    expect(find.text('Level 1 → 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lu_continue')));
    await tester.pumpAndSettle();
    // The preview: nothing changed yet.
    expect(find.text('• Action Surge → features'), findsOneWidget);
    expect(_chip('Level', '1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('summary_confirm')));
    await tester.pumpAndSettle();
    // Applied; the same dialog stays with only Close.
    expect(find.text('Level 1 → 2'), findsOneWidget);
    expect(find.text('• Action Surge → features'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary_confirm')), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('summary_done')));
    await tester.pumpAndSettle();

    expect(_chip('Level', '2'), findsOneWidget);
    expect(find.textContaining('From Fighter · level 2'), findsOneWidget);
    await tester.runAsync(
      () => container.read(pendingWriteBufferProvider).flush(),
    );
    final fields = container.read(characterByIdProvider(id))!.entity.fields;
    expect(cardLevelsOf(fields), {'fighter': 2});
    expect(fields['features'], ['second_wind', 'action_surge']);
  });

  testWidgets('Faz 8: a new character opens on the guide, which walks its '
      'steps and remembers where it stopped', (tester) async {
    late String id;
    late WorldSchema schema;
    await tester.runAsync(() async {
      final worldId = await WorldRepositoryImpl(
        db,
      ).create('Guide', template: _guideTemplate());
      schema = (await readWorldSchema(db, worldId))!;
      final c = await createFreeCharacter(
        container.read(characterListProvider.notifier),
        schema: schema,
        name: 'Aria',
        worldId: worldId,
      );
      id = c.id;
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> open() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            theme: buildThemeData('dark'),
            home: FreeCharacterSheet(
              key: UniqueKey(),
              characterId: id,
              schema: schema,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The debounced save fires, then its write runs (the rest test's way).
    Future<Object?> stored() async {
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      return container.read(characterByIdProvider(id))!.entity.fields[guideKey];
    }

    Finder text(String t) => find.text(t, findRichText: true);

    await open();
    // Step 1: its field's collapsed group opened, in edit mode.
    expect(text('Step 1 / 3'), findsOneWidget);
    expect(text('Write a backstory.'), findsOneWidget);
    expect(find.text('Backstory'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget, reason: 'edit mode');

    await tester.tap(find.byKey(const ValueKey('guide_back')));
    await tester.pumpAndSettle();
    expect(text('Step 1 / 3'), findsOneWidget, reason: 'no step before 1');

    // Step 2 has no field: only its text.
    await tester.tap(find.byKey(const ValueKey('guide_next')));
    await tester.pumpAndSettle();
    expect(text('Step 2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guide_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free_guide_panel')), findsNothing);
    expect(await stored(), {'step': 1, 'open': false});

    // Reopened, a paused guide stays closed; the button resumes it.
    await open();
    expect(find.byKey(const ValueKey('free_guide_panel')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('free_sheet_guide')));
    await tester.pumpAndSettle();
    expect(text('Step 2 / 3'), findsOneWidget);

    // Step 3's field is gone: its text, no crash; Done ends the guide.
    await tester.tap(find.byKey(const ValueKey('guide_next')));
    await tester.pumpAndSettle();
    expect(text('Step 3 / 3'), findsOneWidget);
    expect(text('Old step.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guide_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free_guide_panel')), findsNothing);
    expect(await stored(), {'step': 0, 'open': false});
  });
}

/// The summary chip labelled [label] showing [value].
Finder _chip(String label, String value) =>
    find.descendant(of: find.byTooltip(label), matching: find.text(value));

String _title(String id) => [
  for (final w in id.split('_')) '${w[0].toUpperCase()}${w.substring(1)}',
].join(' ');

/// A template with a separate Class category whose cards hold a Level
/// table, and the player card's Class and Features lists.
WorldSchema _levelTemplate() {
  var t = emptyFreeTemplate(
    id: 'lv',
    name: 'Levels',
    playerCardName: 'Hero',
    now: _now,
  );
  t = addCategory(t, id: 'cls', name: 'Class', now: _now);
  t = addCategory(t, id: 'feat', name: 'Feature', now: _now);
  final cls = t.categories.firstWhere((c) => c.categoryId == 'cls');
  t = replaceCategory(
    t,
    addField(
      cls,
      id: 'levels',
      label: 'Levels',
      type: FieldType.progressionTable,
      now: _now,
    ).copyWith(levelMode: LevelMode.separate.name),
  );
  var card = t.categories.first;
  for (final (key, target) in [('classes', 'class'), ('features', 'feature')]) {
    card = addField(
      card,
      id: key,
      label: key,
      type: FieldType.relation,
      isList: true,
      now: _now,
    );
    card = replaceField(
      card,
      card.fields
          .firstWhere((f) => f.fieldId == key)
          .copyWith(validation: FieldValidation(allowedTypes: [target])),
    );
  }
  return replaceCategory(t, card);
}

/// A player card with a collapsed Story group and a three-step guide: a
/// field in that group, no field, a field that is gone.
WorldSchema _guideTemplate() {
  final t = emptyFreeTemplate(
    id: 'guide',
    name: 'Guide',
    playerCardName: 'Hero',
    now: _now,
  );
  var card = addGroup(t.categories.first, id: 'story', name: 'Story');
  card = replaceGroup(
    card,
    card.fieldGroups
        .firstWhere((g) => g.groupId == 'story')
        .copyWith(isCollapsed: true),
  );
  card = addField(
    card,
    id: 'backstory',
    label: 'Backstory',
    key: 'backstory',
    type: FieldType.markdown,
    groupId: 'story',
    now: _now,
  ).copyWith(
    guide: [
      {'id': 'a', 'field': 'backstory', 'text': 'Write a backstory.'},
      {'id': 'b', 'text': 'Think it over.'},
      {'id': 'c', 'field': 'gone', 'text': 'Old step.'},
    ],
  );
  return replaceCategory(t, card);
}
