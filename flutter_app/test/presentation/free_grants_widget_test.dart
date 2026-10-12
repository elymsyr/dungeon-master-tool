// Faz 7a (docs/free-template/ROADMAP.md): the level system's widgets — the
// Pool, the Level table, a card's Grants, the level up pick and the
// editor's dependency warning (D34).
//
//   cd flutter_app && flutter test test/presentation/free_grants_widget_test.dart

import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_grants.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/free_level_dialogs.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_editor_screen.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/class_resources_card.dart'
    show UsePip;
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-12T00:00:00.000Z';

FieldSchema _field(String key, FieldType type) => FieldSchema(
  fieldId: key,
  categoryId: 'c',
  fieldKey: key,
  label: key,
  fieldType: type,
  createdAt: _now,
  updatedAt: _now,
);

final _template = emptyFreeTemplate(
  id: 't',
  name: 'T',
  playerCardName: 'Hero',
  now: _now,
);

Widget _host(Widget child) => ProviderScope(
  overrides: [worldSchemaProvider.overrideWithValue(_template)],
  child: MaterialApp(
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    theme: buildThemeData('dark'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// [type] drawn through the field factory; edits land in [store].
Widget _fieldHost(
  FieldType type,
  Map<String, dynamic> store, {
  bool readOnly = false,
  GrantResult? grants,
  int? reachedLevel,
  Map<String, Entity> entities = const {},
}) => _host(
  StatefulBuilder(
    builder: (context, setState) => Consumer(
      builder: (context, ref, _) => FieldWidgetFactory.create(
        schema: _field('f', type),
        value: store['f'],
        readOnly: readOnly,
        onChanged: (v) => setState(() => store['f'] = v),
        entities: entities,
        ref: ref,
        grants: grants,
        reachedLevel: reachedLevel,
      ),
    ),
  ),
);

void main() {
  testWidgets('the Pool: boxes per resource, the rest under its giver', (
    tester,
  ) async {
    const grants = GrantResult(
      resources: [PoolResource(name: 'Rage', fromId: 'barb', max: 3)],
      entries: [
        PoolEntry(
          fromId: 'feat',
          item: GrantItem(
            id: 'n',
            kind: GrantKind.style,
            style: FieldType.text,
            label: 'Note',
            value: 'A d8.',
          ),
        ),
      ],
    );
    final store = <String, dynamic>{};
    await tester.pumpWidget(
      _fieldHost(
        FieldType.autoResources,
        store,
        grants: grants,
        entities: {
          'feat': const Entity(id: 'feat', name: 'Superiority', categorySlug: 'feat'),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rage'), findsOneWidget);
    expect(find.byType(UsePip), findsNWidgets(3));
    expect(find.text('From Superiority'), findsOneWidget);
    expect(find.text('A d8.'), findsOneWidget);

    // New: full (V32). The last box spends one.
    await tester.tap(find.byKey(const ValueKey('pool_Rage_2')));
    await tester.pump();
    expect(store['f'], {
      'Rage': {'current': 2},
    });
  });

  testWidgets('the Pool says so when nothing is granted', (tester) async {
    await tester.pumpWidget(_fieldHost(FieldType.autoResources, {}));
    await tester.pumpAndSettle();
    expect(find.text('Nothing granted yet.'), findsOneWidget);
  });

  testWidgets('a Level table marks the rows reached (DESIGN §11.8)', (
    tester,
  ) async {
    final store = <String, dynamic>{
      'f': [
        {'_id': 'a', 'level': 1, 'text': 'One'},
        {'_id': 'b', 'level': 2, 'text': 'Two'},
        {'_id': 'c', 'level': 3, 'text': 'Three'},
      ],
    };
    await tester.pumpWidget(
      _fieldHost(
        FieldType.progressionTable,
        store,
        readOnly: true,
        reachedLevel: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('Three'), findsOneWidget);
  });

  testWidgets('a Level table: a new row is one level up', (tester) async {
    final store = <String, dynamic>{
      'f': [
        {'_id': 'a', 'level': 4},
      ],
    };
    await tester.pumpWidget(_fieldHost(FieldType.progressionTable, store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lt_add_row')));
    await tester.pumpAndSettle();
    expect(levelRowsOf(store['f']).map((r) => r.level), [4, 5]);
  });

  testWidgets('a card\'s Grants: add a resource (D39)', (tester) async {
    final store = <String, dynamic>{};
    await tester.pumpWidget(_fieldHost(FieldType.grantHolder, store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gi_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resource').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gi_res_name')), 'Rage');
    await tester.enterText(find.byKey(const ValueKey('gi_res_max')), '2');
    await tester.tap(find.byKey(const ValueKey('gi_save')));
    await tester.pumpAndSettle();
    final item = grantItemsOf(store['f']).single;
    expect((item.kind, item.name, item.max), (GrantKind.resource, 'Rage', 2));
    expect(find.textContaining('Rage · Max 2'), findsOneWidget);
  });

  testWidgets('level up: the only card is picked (V13)', (tester) async {
    ({Map<String, String> picked, Map<String, String> added})? result;
    final cls = _template.categories.first.copyWith(slug: 'class', name: 'Class');
    await tester.pumpWidget(
      _host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => result = await showFreeLevelUpDialog(
              context,
              ref,
              from: 2,
              groups: [
                LevelUpGroup(
                  category: cls,
                  listKey: 'class_refs',
                  cards: const [(id: 'fighter', level: 2)],
                ),
              ],
              entities: const {
                'fighter': Entity(
                  id: 'fighter',
                  name: 'Fighter',
                  categorySlug: 'class',
                ),
              },
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Level 2 → 3'), findsOneWidget);
    expect(find.text('2 → 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lu_continue')));
    await tester.pumpAndSettle();
    expect(result?.picked, {'class': 'fighter'});
    expect(result?.added, isEmpty);
  });

  testWidgets('the editor warns until the player card has a Level (D34)', (
    tester,
  ) async {
    // A template whose player card lost its Level, with a Level table.
    final card = _template.categories.first;
    var t = replaceCategory(
      _template,
      card.copyWith(
        fields: [
          for (final f in card.fields)
            if (f.fieldType != FieldType.characterLevel) f,
        ],
      ),
    );
    t = addCategory(t, id: 'cls', name: 'Class', now: _now);
    t = replaceCategory(
      t,
      addField(
        t.categories.last,
        id: 'tbl',
        label: 'Levels',
        type: FieldType.progressionTable,
        now: _now,
      ),
    );
    final store = _Store([t]);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userTemplatesProvider.overrideWith(() => store)],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: buildThemeData('dark'),
          home: TemplateEditorScreen(initial: t),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This template needs a "Level" field on the player card.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('own_field_add_characterLevel')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('needs a "Level"'), findsNothing);
    expect(
      store.saves.last.categories.first.fields.any(
        (f) => f.fieldType == FieldType.characterLevel,
      ),
      isTrue,
    );
  });
}

/// In memory; remembers every save.
class _Store extends UserTemplatesNotifier {
  _Store(this.list);
  final List<WorldSchema> list;
  final saves = <WorldSchema>[];

  @override
  Future<List<WorldSchema>> build() async => list;

  @override
  Future<void> save(WorldSchema t) async {
    saves.add(t);
    state = AsyncData([
      for (final x in state.requireValue) x.schemaId == t.schemaId ? t : x,
    ]);
  }
}
