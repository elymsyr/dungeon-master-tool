// Free template Table, Stat table and Skill table (docs/free-template/
// ROADMAP.md Faz 4a) and presets (Faz 4b): the card shows SRD data in them
// with computed modifiers and totals at phone and desktop widths, and the
// editor sets them up and binds them.
//
//   cd flutter_app && flutter test test/presentation/free_field_styles_widget_test.dart

import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_card_preview.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_editor_screen.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_layout_canvas.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_settings_forms.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_styles.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00.000Z';

final _srd = copyAsFreeTemplate(
  generateBuiltinDnd5eV2Schema().schema,
  id: 'c1',
  name: 'SRD copy',
  now: _now,
);

EntityCategorySchema _cat(String slug) =>
    _srd.categories.firstWhere((c) => c.slug == slug);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    theme: buildThemeData('dark'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// [keys] of a [slug] card drawn through the field factory, edits kept.
Widget _card(String slug, Map<String, dynamic> start, List<String> keys) {
  final cat = _cat(slug);
  final fields = {...start};
  return _host(
    StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          for (final k in keys)
            FieldWidgetFactory.create(
              schema: cat.fields.firstWhere((f) => f.fieldKey == k),
              value: fields[k],
              readOnly: false,
              onChanged: (v) => setState(() => fields[k] = v),
              entities: const {},
              entityFields: fields,
              categoryFields: cat.fields,
            ),
        ],
      ),
    ),
  );
}

/// The Goblin Warrior's SRD attributes.
Map<String, dynamic> get _goblin => Map<String, dynamic>.from(
  (srdRawRowsBySlug()['monster']!.firstWhere(
            (r) => r['name'] == 'Goblin Warrior',
          )
          as Map)['attributes']
      as Map,
);

/// The row of [table] whose first cell reads [name].
Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Row)).first;

String _totalIn(WidgetTester tester, String name) {
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: _row(name), matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .toList();
  return texts.last;
}

void main() {
  for (final (label, size) in const [
    ('phone', Size(360, 780)),
    ('desktop', Size(1280, 800)),
  ]) {
    testWidgets('$label: Goblin Warrior stats, skills and senses', (
      tester,
    ) async {
      await _size(tester, size);
      await tester.pumpWidget(
        _card('monster', _goblin, ['stat_block', 'skill_bonuses', 'senses']),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // DEX 14 → +2; STR 8 → −1.
      expect(find.text('+2'), findsWidgets);
      expect(find.text('−1'), findsWidgets);
      expect(_totalIn(tester, 'Stealth'), '+6');
      expect(_totalIn(tester, 'Athletics'), '−1');
      expect(find.text('Darkvision'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
    });
  }

  testWidgets('a new score moves the modifier and the totals', (tester) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _card('monster', _goblin, ['stat_block', 'skill_bonuses']),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('stat_stat_block_STR')),
      '15',
    );
    await tester.pumpAndSettle();
    expect(_totalIn(tester, 'Athletics'), '+2');

    // E4.4: 7, 9, 10, 15 → −2, −1, 0, +2.
    for (final (score, mod) in const [
      ('7', '−2'),
      ('9', '−1'),
      ('10', '+0'),
      ('15', '+2'),
    ]) {
      await tester.enterText(
        find.byKey(const ValueKey('stat_stat_block_DEX')),
        score,
      );
      await tester.pumpAndSettle();
      expect(_totalIn(tester, 'Acrobatics'), mod, reason: score);
    }
  });

  testWidgets('a free table adds and removes its rows', (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(_card('monster', const {}, ['senses']));
    await tester.pumpAndSettle();
    expect(find.text('No rows'), findsOneWidget);

    await tester.tap(find.byTooltip('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '30');
    await tester.pumpAndSettle();
    expect(find.text('No rows'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No rows'), findsOneWidget);
  });

  testWidgets('starting equipment reads as text', (tester) async {
    final fighter = Map<String, dynamic>.from(
      (srdRawRowsBySlug()['class']!.firstWhere((r) => r['name'] == 'Fighter')
              as Map)['attributes']
          as Map,
    );
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _card('class', fighter, ['equipment_choice_groups']),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Studded Leather', findRichText: true),
      findsWidgets,
    );
  });

  group('editor', () {
    late WorldSchema saved;
    Widget app(WorldSchema t) => ProviderScope(
      overrides: [
        userTemplatesProvider.overrideWith(() => _Store([t], (s) => saved = s)),
      ],
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildThemeData('dark'),
        home: TemplateEditorScreen(initial: t),
      ),
    );
    final empty = emptyFreeTemplate(
      id: 'e1',
      name: 'Empty',
      playerCardName: 'Hero',
      now: _now,
    );

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> addStyle(
      WidgetTester tester,
      String style,
      String label,
    ) async {
      // The strip is a lazy sideways list: the combined styles sit last.
      final button = find.descendant(
        of: find.byType(TemplatePaletteStrip),
        matching: find.text(style),
      );
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.descendant(
          of: find.byType(TemplatePaletteStrip),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, button);
      await tester.enterText(find.byType(TextField).last, label);
      await tap(tester, find.widgetWithText(FilledButton, 'Add'));
    }

    Future<void> addLine(WidgetTester tester, String label, String text) async {
      final f = find.widgetWithText(TextField, label);
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    Future<void> autosave(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    FieldSchema savedField(String key) =>
        saved.categories.single.fields.firstWhere((f) => f.fieldKey == key);

    testWidgets('desktop: a stat table with base 0 and step 3 (E4.5)', (
      tester,
    ) async {
      await _size(tester, const Size(1280, 900));
      await tester.pumpWidget(app(empty));
      await tester.pumpAndSettle();

      await addStyle(tester, 'Stat table', 'Abilities');
      await addLine(tester, 'Add stat', 'Might');
      await addLine(tester, 'Add stat', 'Wits');
      await tester.enterText(find.widgetWithText(TextField, 'Base value'), '0');
      await tester.enterText(find.widgetWithText(TextField, 'Step'), '3');
      await autosave(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('-1 → −1   ·   0 → +0   ·   3 → +1'), findsOneWidget);

      final spec = StatTableSpec.of(savedField('abilities'));
      expect(spec.stats, [
        (key: 'might', label: 'Might'),
        (key: 'wits', label: 'Wits'),
      ]);
      expect((spec.base, spec.step), (0, 3));
      expect([spec.modifier(7), spec.modifier(20)], [2, 6]);
    });

    testWidgets('desktop: a fixed-row table with a template row', (
      tester,
    ) async {
      await _size(tester, const Size(1280, 900));
      await tester.pumpWidget(app(empty));
      await tester.pumpAndSettle();

      await addStyle(tester, 'Table', 'Skills');
      await addLine(tester, 'Add column', 'Skill');
      await addLine(tester, 'Add column', 'Bonus');
      await tap(tester, find.text('Fixed'));
      await tap(tester, find.text('From the template').first);
      await tap(tester, find.text('Add row'));
      await tester.enterText(
        find.byKey(const ValueKey('trow-r1-skill')),
        'Athletics',
      );
      await autosave(tester);
      expect(tester.takeException(), isNull);

      final spec = TableSpec.of(savedField('skills'));
      expect(spec.fixedRows, isTrue);
      expect(spec.columns.map((c) => (c.key, c.locked)), [
        ('skill', true),
        ('bonus', false),
      ]);
      expect(spec.rows, [
        {'_id': 'r1', 'skill': 'Athletics'},
      ]);

      await tap(tester, find.text('Preview'));
      expect(
        find.descendant(
          of: find.byType(TemplateCardPreview),
          matching: find.text('Athletics'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: the SRD player card skills open in the sheet', (
      tester,
    ) async {
      await _size(tester, const Size(360, 780));
      await tester.pumpWidget(app(_srd));
      await tester.pumpAndSettle();
      await tap(tester, find.text(_cat('player-character').name).first);
      final skills = find.text('Skills');
      await tester.scrollUntilVisible(
        skills,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, skills);
      expect(tester.takeException(), isNull);
      // Bound to the SRD Skills preset: its rows are edited there.
      expect(find.text('Preset: Skills'), findsOneWidget);
      expect(find.text('Break link'), findsOneWidget);
    });

    Finder navPreset(String kind) =>
        find.byKey(ValueKey('nav-preset-c1-preset-$kind'));

    Future<void> scrollTo(WidgetTester tester, Finder f, Type within) =>
        tester.scrollUntilVisible(
          f,
          200,
          scrollable: find
              .descendant(
                of: find.byType(within),
                matching: find.byType(Scrollable),
              )
              .first,
        );

    testWidgets('desktop: a row added to a preset reaches every bound field '
        '(E4.6)', (tester) async {
      await _size(tester, const Size(1280, 900));
      await tester.pumpWidget(app(_srd));
      await tester.pumpAndSettle();

      await tap(tester, navPreset('skills'));
      final add = find.widgetWithText(TextField, 'Add row');
      await scrollTo(tester, add, TemplatePresetForm);
      await addLine(tester, 'Add row', 'Sailing');
      await autosave(tester);
      expect(tester.takeException(), isNull);

      for (final (slug, key) in const [
        ('player-character', 'skills'),
        ('npc', 'skills'),
        ('monster', 'skill_bonuses'),
      ]) {
        final f = saved.categories
            .firstWhere((c) => c.slug == slug)
            .fields
            .firstWhere((f) => f.fieldKey == key);
        expect(SkillTableSpec.of(f).rows.last['name'], 'Sailing', reason: slug);
      }
    });

    testWidgets('desktop: break link stops a field following (E4.7)', (
      tester,
    ) async {
      await _size(tester, const Size(1280, 900));
      await tester.pumpWidget(app(_srd));
      await tester.pumpAndSettle();

      final tile = find.descendant(
        of: find.byType(TemplateLayoutCanvas),
        matching: find.text('Skills'),
      );
      await scrollTo(tester, tile, TemplateLayoutCanvas);
      await tap(tester, tile);
      await tap(tester, find.text('Break link'));
      await autosave(tester);
      expect(tester.takeException(), isNull);
      final pcSkills = saved.categories
          .firstWhere((c) => c.isPlayerCard == true)
          .fields
          .firstWhere((f) => f.fieldKey == 'skills');
      expect(pcSkills.presetId, isNull);
      expect(pcSkills.fieldType, FieldType.skillTable);
    });

    testWidgets('desktop: a new preset goes in bound, once (V8)', (
      tester,
    ) async {
      await _size(tester, const Size(1280, 900));
      await tester.pumpWidget(app(empty));
      await tester.pumpAndSettle();

      await tap(tester, find.byTooltip('New preset'));
      final style = find.widgetWithText(ListTile, 'Skill table');
      await scrollTo(tester, style, DraggableScrollableSheet);
      await tap(tester, style);
      await tester.enterText(find.byType(TextField).last, 'Skills');
      await tap(tester, find.widgetWithText(FilledButton, 'Add'));
      expect(find.byType(TemplatePresetForm), findsOneWidget);

      final button = find.descendant(
        of: find.byType(TemplatePaletteStrip),
        matching: find.text('Skills'),
      );
      await scrollTo(tester, button, TemplatePaletteStrip);
      await tap(tester, button);
      await tap(tester, button);
      expect(find.textContaining('already has'), findsOneWidget);
      await autosave(tester);

      final preset = saved.presets!.single;
      final field = saved.categories.single.fields.single;
      expect(field.presetId, preset.fieldId);
      expect(
        (field.fieldKey, field.fieldType),
        ('skills', FieldType.skillTable),
      );
    });
  });

  testWidgets('a skill row: a mark adds the bonus, the stat can change', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _card('monster', _goblin, ['stat_block', 'skill_bonuses']),
    );
    await tester.pumpAndSettle();
    expect(_totalIn(tester, 'Athletics'), '−1'); // STR 8

    await tester.tap(
      find
          .descendant(
            of: _row('Athletics'),
            matching: find.byType(ProficiencyDot),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(_totalIn(tester, 'Athletics'), '+1'); // + PB 2

    await tester.tap(
      find.descendant(of: _row('Athletics'), matching: find.text('STR')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEX').last);
    await tester.pumpAndSettle();
    expect(_totalIn(tester, 'Athletics'), '+4'); // DEX 14 + PB 2
  });

  testWidgets('a row with no stat counts 0; the template sets what a card '
      'may change', (tester) async {
    await _size(tester, const Size(1280, 800));
    final cat = _cat('monster');
    FieldSchema skills(SkillTableSpec s) => cat.fields
        .firstWhere((f) => f.fieldKey == 'skill_bonuses')
        .copyWith(styleConfig: s.toConfig());
    Widget host(FieldSchema f, Object? value, ValueChanged<dynamic> set) =>
        _host(
          FieldWidgetFactory.create(
            schema: f,
            value: value,
            readOnly: false,
            onChanged: set,
            entities: const {},
            entityFields: _goblin,
            categoryFields: cat.fields,
          ),
        );
    const row = {'_id': 'x', 'name': 'Sailing'};

    // No stat: the stat counts 0, the row still totals.
    await tester.pumpWidget(
      host(skills(const SkillTableSpec(rows: [row])), null, (_) {}),
    );
    expect(_totalIn(tester, 'Sailing'), '+0');
    expect(
      find.descendant(of: _row('Sailing'), matching: find.byType(TextFormField)),
      findsOneWidget, // misc only
    );

    // Name editable, stat locked.
    Object? stored;
    await tester.pumpWidget(
      host(
        skills(const SkillTableSpec(
          rows: [{...row, 'ability': 'DEX'}],
          nameEditable: true,
          statEditable: false,
        )),
        null,
        (v) => stored = v,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Denizcilik');
    expect(stored, [
      {'_id': 'x', 'label': 'Denizcilik'},
    ]);
  });
}

/// In memory; reports every save.
class _Store extends UserTemplatesNotifier {
  _Store(this.list, this.onSave);
  final List<WorldSchema> list;
  final void Function(WorldSchema) onSave;

  @override
  Future<List<WorldSchema>> build() async => list;

  @override
  Future<void> save(WorldSchema t) async {
    onSave(t);
    state = AsyncData([
      for (final x in state.requireValue) x.schemaId == t.schemaId ? t : x,
    ]);
  }
}
