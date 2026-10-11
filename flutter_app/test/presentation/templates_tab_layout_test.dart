// Templates tab and template inspector at phone and desktop widths
// (docs/free-template/ROADMAP.md E1.8): no overflow, actions reachable.
//
//   cd flutter_app && flutter test test/presentation/templates_tab_layout_test.dart

import 'package:dungeon_master_tool/application/providers/global_tags_provider.dart';
import 'package:dungeon_master_tool/application/providers/template_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_template.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/hub/templates_tab.dart';
import 'package:dungeon_master_tool/presentation/screens/templates/template_editor_screen.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-10-11T00:00:00.000Z';

/// In-memory stand-in: the tab's flows without a database.
class _Fixed extends UserTemplatesNotifier {
  _Fixed(this.list);
  final List<WorldSchema> list;
  @override
  Future<List<WorldSchema>> build() async => list;

  @override
  Future<WorldSchema> copy(WorldSchema source, String name) async {
    final t = copyAsFreeTemplate(source, id: 'new', name: name, now: _now);
    state = AsyncData([...state.requireValue, t]);
    return t;
  }

  @override
  Future<void> saveInfo(
    String id, {
    required String name,
    required String description,
    required List<String> tags,
    required String coverImagePath,
  }) async {
    state = AsyncData([
      for (final t in state.requireValue)
        t.schemaId == id ? t.copyWith(name: name, description: description) : t,
    ]);
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData([
      for (final t in state.requireValue)
        if (t.schemaId != id) t,
    ]);
  }
}

final _builtin = generateBuiltinDnd5eV2Schema().schema;
final _mine = [
  copyAsFreeTemplate(_builtin,
      id: 'c1',
      name: 'D&D 5e (SRD 5.2.1) (kopya) with a rather long name to wrap',
      now: _now),
  emptyFreeTemplate(id: 'e1', name: 'Boş', playerCardName: 'Oyuncu', now: _now),
];

Widget _app(Widget home, Locale locale, {List<WorldSchema>? mine}) =>
    ProviderScope(
      overrides: [
        userTemplatesProvider.overrideWith(() => _Fixed(mine ?? _mine)),
        // The settings dialog's tag field reads it; the real one opens a DB.
        globalTagsProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildThemeData('dark'),
        home: home,
      ),
    );

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (label, size) in const [
    ('phone', Size(360, 780)),
    ('desktop', Size(1280, 800)),
  ]) {
    for (final locale in const [Locale('en'), Locale('tr')]) {
      testWidgets('$label ${locale.languageCode}: templates tab lays out',
          (tester) async {
        await _size(tester, size);
        await tester.pumpWidget(
            _app(const Scaffold(body: TemplatesTab()), locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Three cards, the gear only on own ones; one action row.
        expect(find.byIcon(Icons.settings), findsNWidgets(2));
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        expect(find.byIcon(Icons.content_copy), findsOneWidget);
        expect(find.byIcon(Icons.import_export), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });
    }
  }

  testWidgets('phone tr: large system text still lays out', (tester) async {
    await _size(tester, const Size(360, 780));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
        _app(const Scaffold(body: TemplatesTab()), const Locale('tr')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: select, copy, settings, delete', (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(_app(const Scaffold(body: TemplatesTab()),
        const Locale('en'),
        mine: const []));
    await tester.pumpAndSettle();

    ButtonStyleButton button(IconData icon) => tester.widget<ButtonStyleButton>(
        find.ancestor(
            of: find.byIcon(icon),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    Future<void> tapAndSettle(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      // Cards also take double taps, so a single tap lands after the timeout.
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
    }

    // Nothing selected: the row is disabled.
    expect(button(Icons.content_copy).onPressed, isNull);

    // The built-in template: copy yes, delete no.
    await tapAndSettle(find.text(_builtin.name));
    expect(button(Icons.content_copy).onPressed, isNotNull);
    expect(button(Icons.delete_outline).onPressed, isNull);

    await tapAndSettle(find.byIcon(Icons.content_copy));
    final copyName = '${_builtin.name} (copy)';
    expect(find.widgetWithText(TextField, copyName), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'Copy'));
    expect(tester.takeException(), isNull);
    expect(find.text('Created "$copyName"'), findsOneWidget);

    await tapAndSettle(find.byIcon(Icons.settings));
    await tester.enterText(find.widgetWithText(TextField, copyName), 'My SRD');
    await tapAndSettle(find.widgetWithText(FilledButton, 'Save'));
    expect(tester.takeException(), isNull);
    expect(find.text('My SRD'), findsOneWidget);

    await tapAndSettle(find.text('My SRD'));
    expect(button(Icons.delete_outline).onPressed, isNotNull);
    await tapAndSettle(find.byIcon(Icons.delete_outline));
    expect(find.text('Delete template?'), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'Delete'));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.textContaining('No templates of your own yet'), findsOneWidget);
  });

  testWidgets('phone: delete from the settings dialog', (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(
        _app(const Scaffold(body: TemplatesTab()), const Locale('en')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.settings).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings).last);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete template'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('phone: empty list shows the hint', (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(_app(const Scaffold(body: TemplatesTab()),
        const Locale('en'),
        mine: const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('No templates of your own yet'), findsOneWidget);
  });

  testWidgets('phone: inspector goes list → category → back to list',
      (tester) async {
    await _size(tester, const Size(360, 780));
    await tester.pumpWidget(_app(
        TemplateEditorScreen(initial: _mine.first), const Locale('en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final first = _mine.first.categories.first;
    await tester.tap(find.text(first.name));
    await tester.pumpAndSettle();
    expect(find.text('slug: ${first.slug}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('slug: ${first.slug}'), findsNothing);
    expect(find.text(first.name), findsOneWidget);
  });

  testWidgets('desktop: inspector shows list and detail side by side',
      (tester) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(
        TemplateEditorScreen(initial: _mine.first), const Locale('en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('slug: ${_mine.first.categories.first.slug}'),
        findsOneWidget);
  });
}
