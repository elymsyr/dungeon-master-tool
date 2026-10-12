// Faz 7a+ (docs/free-template/ROADMAP.md): outside edit mode a free
// template's checkboxes, resources and HP still change; names, text, maxima
// and built-in fields stay read-only.
//
//   cd flutter_app && flutter test test/presentation/free_play_fields_test.dart

import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FieldSchema _field(String key, FieldType type, [Map<String, dynamic>? cfg]) =>
    FieldSchema(
      fieldId: key,
      categoryId: 'c',
      fieldKey: key,
      label: key,
      fieldType: type,
      styleConfig: cfg,
      createdAt: '2026-10-12T00:00:00.000Z',
      updatedAt: '2026-10-12T00:00:00.000Z',
    );

Future<List<dynamic>> _pump(
  WidgetTester tester,
  FieldSchema f,
  dynamic value, {
  required bool play,
}) async {
  final changes = <dynamic>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: buildThemeData('dark'),
      home: Scaffold(
        body: FieldWidgetFactory.create(
          schema: f,
          value: value,
          readOnly: true,
          play: play,
          onChanged: changes.add,
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('a free checkbox ticks in view mode', (tester) async {
    final changes = await _pump(
      tester,
      _field('inspired', FieldType.boolean_),
      false,
      play: true,
    );
    await tester.tap(find.byType(Checkbox));
    expect(changes, [true]);
  });

  testWidgets('a built-in checkbox stays read-only (hidden unchecked)', (
    tester,
  ) async {
    await _pump(
      tester,
      _field('inspired', FieldType.boolean_),
      false,
      play: false,
    );
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('a resource: current − / + live, max read-only', (tester) async {
    final changes = await _pump(
      tester,
      _field('ki', FieldType.resource),
      {'current': 2, 'max': 4},
      play: true,
    );
    await tester.tap(find.byIcon(Icons.remove));
    expect(changes.single, {'current': 1, 'max': 4});
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('res_ki_max')),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
  });

  testWidgets('resource boxes spend in view mode', (tester) async {
    final changes = await _pump(
      tester,
      _field('rage', FieldType.resource, {'display': 'boxes'}),
      {'current': 2, 'max': 3},
      play: true,
    );
    await tester.tap(find.byKey(const ValueKey('res_rage_1')));
    expect(changes.single, {'current': 1, 'max': 3});
  });

  testWidgets('a text field stays read-only', (tester) async {
    await _pump(tester, _field('notes', FieldType.text), 'x', play: true);
    expect(find.byType(TextField), findsNothing);
  });
}
