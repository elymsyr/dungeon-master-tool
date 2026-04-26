import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FieldSchema _schema(FieldType type, {String label = 'Test', String key = 'test'}) {
  final now = DateTime.now().toIso8601String();
  return FieldSchema(
    fieldId: 'f-1',
    categoryId: 'cat-1',
    fieldKey: key,
    label: label,
    fieldType: type,
    validation: const FieldValidation(),
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MediaQuery(
      data: const MediaQueryData(size: Size(2400, 1200)),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 2400,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Tests render Cards with multiple wrapped fields. Default Flutter test view
  // (800×600) is not wide enough; bump to 2400×1200 for the suite.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(2400, 1200)
      ..devicePixelRatio = 1.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  // ────────────────────────────────────────────────────────────
  // rangedSenseList
  // ────────────────────────────────────────────────────────────
  group('FieldType.rangedSenseList editor', () {
    testWidgets('renders empty state with label', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.rangedSenseList, label: 'Senses'),
        value: const [],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Senses (0)'), findsOneWidget);
      expect(find.text('No entries'), findsOneWidget);
    });

    testWidgets('add button appends an empty row', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.rangedSenseList, label: 'Senses'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(captured, isA<List>());
      expect((captured as List).length, 1);
      expect((captured.first as Map)['sense_ref'], isNull);
      expect((captured.first as Map)['range_ft'], isNull);
    });

    testWidgets('renders existing rows with relation field labels', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.rangedSenseList, label: 'Senses'),
        value: const [
          {'sense_ref': 'sense-1', 'range_ft': 60},
          {'sense_ref': null, 'range_ft': 120},
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Senses (2)'), findsOneWidget);
      expect(find.text('Sense'), findsNWidgets(2));
      expect(find.text('Range (ft)'), findsNWidgets(2));
    });

    testWidgets('readOnly hides add button', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.rangedSenseList, label: 'Senses'),
        value: const [],
        readOnly: true,
        onChanged: (_) {},
      )));
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  // ────────────────────────────────────────────────────────────
  // classFeatures
  // ────────────────────────────────────────────────────────────
  group('FieldType.classFeatures editor', () {
    testWidgets('renders empty state', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.classFeatures, label: 'Features'),
        value: const [],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Features (0)'), findsOneWidget);
      expect(find.text('No entries'), findsOneWidget);
    });

    testWidgets('add appends empty feature row with all keys', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.classFeatures, label: 'Features'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final row = (captured as List).first as Map;
      expect(row.keys, containsAll(<String>[
        'level', 'name', 'kind', 'dice', 'uses', 'recharge', 'description',
      ]));
    });

    testWidgets('shows row with name and dice fields', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.classFeatures, label: 'Features'),
        value: const [
          {'level': 1, 'name': 'Rage', 'kind': 'resource', 'dice': '', 'uses': 2, 'recharge': 'long-rest', 'description': ''},
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Kind'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  // spellEffectList
  // ────────────────────────────────────────────────────────────
  group('FieldType.spellEffectList editor', () {
    testWidgets('renders empty state', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.spellEffectList, label: 'Effects'),
        value: const [],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Effects (0)'), findsOneWidget);
    });

    testWidgets('add appends row with effect keys', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.spellEffectList, label: 'Effects'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final row = (captured as List).first as Map;
      expect(row.keys, containsAll(<String>[
        'kind', 'dice', 'type_ref', 'save_ability_ref',
        'save_effect', 'condition_refs', 'scaling_dice',
      ]));
      expect(row['condition_refs'], isA<List<String>>());
    });

    testWidgets('shows existing damage row', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.spellEffectList, label: 'Effects'),
        value: const [
          {
            'kind': 'damage',
            'dice': '8d6',
            'type_ref': null,
            'save_ability_ref': null,
            'save_effect': 'half',
            'condition_refs': <String>[],
            'scaling_dice': '+1d6',
          },
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Effects (1)'), findsOneWidget);
      expect(find.text('Save Effect'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  // grantedModifiers
  // ────────────────────────────────────────────────────────────
  group('FieldType.grantedModifiers editor', () {
    testWidgets('renders empty state', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.grantedModifiers, label: 'Modifiers'),
        value: const [],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Modifiers (0)'), findsOneWidget);
    });

    testWidgets('add appends row with full modifier shape', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.grantedModifiers, label: 'Modifiers'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final row = (captured as List).first as Map;
      expect(row.keys, containsAll(<String>[
        'kind', 'target_kind', 'target_ref', 'value',
        'scaling', 'condition_ref', 'notes',
      ]));
    });

    testWidgets('renders kind/target_kind dropdowns', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.grantedModifiers, label: 'Modifiers'),
        value: const [
          {
            'kind': 'ac_bonus',
            'target_kind': null,
            'target_ref': null,
            'value': 1,
            'scaling': 'flat',
            'condition_ref': null,
            'notes': '',
          },
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Modifiers (1)'), findsOneWidget);
      expect(find.text('Kind'), findsOneWidget);
      expect(find.text('Target Kind'), findsOneWidget);
    });

    testWidgets('removes row on close button tap', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.grantedModifiers, label: 'Modifiers'),
        value: const [
          {
            'kind': 'ac_bonus', 'target_kind': null, 'target_ref': null,
            'value': 1, 'scaling': '', 'condition_ref': null, 'notes': '',
          },
        ],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(captured, isA<List>());
      expect((captured as List).isEmpty, true);
    });
  });
}
