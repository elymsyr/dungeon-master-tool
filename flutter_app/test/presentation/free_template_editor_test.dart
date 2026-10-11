// The free template editor at phone, medium and desktop widths
// (docs/free-template/ROADMAP.md Faz 2): it opens without overflow, the main
// flows work, edits save on their own.
//
//   cd flutter_app && flutter test test/presentation/free_template_editor_test.dart

import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_card_preview.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_editor_screen.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_settings_forms.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_styles.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00.000Z';

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

final _srdCopy = copyAsFreeTemplate(
  generateBuiltinDnd5eV2Schema().schema,
  id: 'c1',
  name: 'SRD copy',
  now: _now,
);
final _empty = emptyFreeTemplate(
  id: 'e1',
  name: 'Empty',
  playerCardName: 'Hero',
  now: _now,
);

late _Store _store;

Widget _app(WorldSchema t, {Locale locale = const Locale('en')}) {
  _store = _Store([t]);
  return ProviderScope(
    overrides: [userTemplatesProvider.overrideWith(() => _store)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: buildThemeData('dark'),
      home: TemplateEditorScreen(initial: t),
    ),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The [n] pill of the settings' number pills ([last]: the field width
/// ones when both show).
Finder _segment(String n) => find.descendant(
  of: find.byType(TemplatePills<int>),
  matching: find.text(n),
);

/// A style in the desktop palette strip.
Finder _palette(String style) => find.descendant(
  of: find.byType(TemplatePaletteStrip),
  matching: find.text(style),
);

/// Scrolls the settings list to [f]: the desktop panel, else the last list
/// (the open sheet or page).
Future<void> _scrollTo(WidgetTester tester, Finder f) {
  final panel = find.byType(TemplateSettingsPanel);
  final list = panel.evaluate().isNotEmpty ? panel : find.byType(ListView).last;
  return tester.scrollUntilVisible(
    f,
    120,
    scrollable: find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first,
  );
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Waits out the autosave delay.
Future<void> _autosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

WorldSchema get _saved => _store.saves.last;

void main() {
  for (final locale in const [Locale('en'), Locale('tr')]) {
    for (final (label, size, wide) in const [
      ('phone', Size(360, 780), false),
      ('medium', Size(900, 800), false),
      ('desktop', Size(1280, 800), true),
    ]) {
      testWidgets('$label ${locale.languageCode}: SRD copy opens', (
        tester,
      ) async {
        await _size(tester, size);
        await tester.pumpWidget(_app(_srdCopy, locale: locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The palette strip is the desktop's; narrow widths use "+ Add".
        expect(
          find.byType(TemplatePaletteStrip),
          wide ? findsOneWidget : findsNothing,
        );
        if (!wide) {
          final pc = _srdCopy.categories.firstWhere(
            (c) => c.isPlayerCard == true,
          );
          await _tap(tester, find.text(pc.name));
          expect(tester.takeException(), isNull);
          expect(find.byType(FloatingActionButton), findsOneWidget);
        }
      });
    }
  }

  testWidgets('phone tr: large text still lays out', (tester) async {
    await _size(tester, const Size(360, 780));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(_srdCopy, locale: const Locale('tr')));
    await tester.pumpAndSettle();
    final pc = _srdCopy.categories.firstWhere((c) => c.isPlayerCard == true);
    await _tap(tester, find.text(pc.name));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: add a field, rename it, the key stays, it saves', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();

    await _tap(tester, _palette('Text'));
    await tester.enterText(find.byType(TextField).last, 'Faction');
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
    expect(tester.takeException(), isNull);
    // The new field is selected: its settings show the key.
    expect(find.text('faction'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Faction').last,
      'Fraksiyon',
    );
    await _autosave(tester);
    final f = _saved.categories.single.fields.single;
    expect(
      (f.label, f.fieldKey, f.fieldType),
      ('Fraksiyon', 'faction', FieldType.text),
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('desktop: groups, columns, width and moving a field', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Add group'));
    await tester.enterText(find.byType(TextField).last, 'Identity');
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
    // The new group is selected: palette clicks land in it.
    await _tap(tester, _segment('3').first);
    for (final name in ['Species', 'Class']) {
      await _tap(tester, _palette('Text'));
      await tester.enterText(find.byType(TextField).last, name);
      await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
      // Back to the group so the next one lands there too.
      await _tap(tester, find.text('Identity').first);
    }
    await _autosave(tester);
    var cat = _saved.categories.single;
    final g = cat.fieldGroups.single;
    expect(g.gridColumns, 3);
    expect(fieldsIn(cat, g.groupId).map((f) => f.label), ['Species', 'Class']);

    // Width 2 for Class.
    await _tap(tester, find.text('Class').first);
    await _tap(tester, _segment('2').last);
    // Out of the group, through the settings.
    await _tap(tester, find.text('Identity').last);
    await _tap(tester, find.text('Properties').last);
    await _autosave(tester);
    cat = _saved.categories.single;
    final cls = cat.fields.firstWhere((f) => f.label == 'Class');
    expect(cls.gridColumnSpan, 2);
    expect(cls.groupId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: drag a field by its handle into a group', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    var t = _empty;
    var pc = t.categories.single;
    pc = addGroup(pc, id: 'g', name: 'Combat');
    pc = addField(pc, id: 'f', label: 'AC', type: FieldType.integer, now: _now);
    t = t.copyWith(categories: [pc]);
    await tester.pumpWidget(_app(t));
    await tester.pumpAndSettle();

    final handle = find.descendant(
      of: find.ancestor(of: find.text('AC'), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.drag_indicator),
    );
    final target = tester.getCenter(find.text('Combat'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(target, timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(target + const Offset(0, 4));
    await tester.pump();
    await gesture.up();
    await _autosave(tester);
    expect(_saved.categories.single.fields.single.groupId, 'g');
  });

  testWidgets('desktop: move up / down reorders without dragging', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    var pc = _empty.categories.single;
    for (final (id, label) in [('a', 'First'), ('b', 'Second')]) {
      pc = addField(pc, id: id, label: label, type: FieldType.text, now: _now);
    }
    await tester.pumpWidget(_app(_empty.copyWith(categories: [pc])));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Second').first);
    await _scrollTo(tester, find.byTooltip('Move up'));
    await _tap(tester, find.byTooltip('Move up'));
    await _autosave(tester);
    expect(fieldsIn(_saved.categories.single, null).map((f) => f.label), [
      'Second',
      'First',
    ]);
  });

  testWidgets('desktop: an incompatible style change makes a new key', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    var pc = _empty.categories.single;
    pc = addField(pc, id: 'f', label: 'Size', type: FieldType.enum_, now: _now);
    await tester.pumpWidget(_app(_empty.copyWith(categories: [pc])));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Size').first);
    await _tap(tester, find.byType(DropdownButton<FieldType>));
    await _tap(tester, find.text('Whole number').last);
    expect(find.text('Change style?'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Change'));
    await _autosave(tester);
    final f = _saved.categories.single.fields.single;
    expect((f.fieldKey, f.fieldType), ('size_2', FieldType.integer));
    // The new field stays selected.
    expect(find.text('size_2'), findsOneWidget);
  });

  testWidgets('desktop: the player card cannot be deleted', (tester) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.textContaining("can't be deleted"));
    expect(find.textContaining("can't be deleted"), findsOneWidget);
    expect(find.text('Delete category'), findsNothing);
  });

  testWidgets('desktop: tier, and the map icon only with the world map', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();

    // Not in the built-in lists: the sidebar rule gives tier 2.
    expect(find.text('Tier 2 — DM'), findsOneWidget);
    await _tap(tester, find.byType(DropdownButton<int>));
    await _tap(tester, find.text('Tier 1 — Content').last);

    expect(find.byTooltip('Map icon'), findsNothing);
    await _tap(tester, find.text('World map'));
    expect(find.byTooltip('Map icon'), findsOneWidget);
    await _tap(tester, find.byTooltip('Map icon'));
    await _tap(tester, find.byTooltip('castle'));
    await _autosave(tester);
    final pc = _saved.categories.single;
    expect(pc.tier, 1);
    expect(pc.allowedInSections, contains('worldmap'));
    expect(pc.icon, 'castle');
  });

  testWidgets('desktop: deleting a group keeps its fields', (tester) async {
    await _size(tester, const Size(1280, 800));
    var pc = _empty.categories.single;
    pc = addGroup(pc, id: 'g', name: 'Combat');
    pc = addField(
      pc,
      id: 'f',
      label: 'AC',
      type: FieldType.integer,
      groupId: 'g',
      now: _now,
    );
    await tester.pumpWidget(_app(_empty.copyWith(categories: [pc])));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Combat'));
    await _tap(tester, find.text('Delete group'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    await _autosave(tester);
    final cat = _saved.categories.single;
    expect(cat.fieldGroups, isEmpty);
    expect(cat.fields.single.groupId, isNull);
  });

  testWidgets('desktop: preview of the SRD player card', (tester) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_srdCopy));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Preview'));
    expect(find.text('Sample card'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Layout'));
    expect(find.text('Sample card'), findsNothing);
  });

  testWidgets('every SRD copy category previews without errors', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    for (final cat in _srdCopy.categories) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            theme: buildThemeData('dark'),
            home: Scaffold(body: TemplateCardPreview(category: cat)),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: cat.slug);
    }
  });

  testWidgets('phone: field settings sheet, delete closes it', (tester) async {
    await _size(tester, const Size(360, 780));
    var pc = _empty.categories.single;
    pc = addField(pc, id: 'f', label: 'Notes', type: FieldType.text, now: _now);
    await tester.pumpWidget(_app(_empty.copyWith(categories: [pc])));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Hero'));
    await _tap(tester, find.text('Notes'));
    expect(find.text('notes'), findsOneWidget);
    await _scrollTo(tester, find.text('Delete field'));
    await _tap(tester, find.text('Delete field'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(tester.takeException(), isNull);
    expect(find.text('Delete field'), findsNothing);
    await _autosave(tester);
    expect(_saved.categories.single.fields, isEmpty);
  });

  testWidgets('phone: add a field from the style sheet', (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Hero'));
    await _tap(tester, find.byType(FloatingActionButton));
    await _scrollTo(tester, find.text('Dice'));
    await _tap(tester, find.text('Dice'));
    await tester.enterText(find.byType(TextField).last, 'Damage');
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
    expect(tester.takeException(), isNull);
    expect(find.text('Damage'), findsOneWidget);
    await _autosave(tester);
    expect(_saved.categories.single.fields.single.fieldType, FieldType.dice);
  });

  testWidgets('closing with a pending edit still saves', (tester) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Details'));
    await tester.enterText(find.widgetWithText(TextField, 'Empty'), 'Mine');
    await tester.pump();
    expect(_store.saves, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(_saved.name, 'Mine');
  });
}
