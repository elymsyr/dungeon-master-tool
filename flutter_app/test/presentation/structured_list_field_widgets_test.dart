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

    testWidgets('add appends empty feature row with level + description', (tester) async {
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
      expect(row.keys, containsAll(<String>['level', 'description']));
    });

    testWidgets('shows row with level + summary fields only', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.classFeatures, label: 'Features'),
        value: const [
          {'level': 1, 'description': 'Rage etc.'},
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Feat'), findsNothing);
      expect(find.text('Trait'), findsNothing);
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
  // resourcePoolGrants + playerChoices
  // ────────────────────────────────────────────────────────────
  group('FieldType.resourcePoolGrants editor', () {
    testWidgets('renders empty state', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.resourcePoolGrants, label: 'Resource Pools'),
        value: const [],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Resource Pools (0)'), findsOneWidget);
    });

    testWidgets('add appends a pool row defaulting to long rest',
        (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.resourcePoolGrants, label: 'Resource Pools'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final row = (captured as List).first as Map;
      expect(row['recharge'], 'long_rest');
    });

    testWidgets('renders count-by-level chips', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.resourcePoolGrants, label: 'Resource Pools'),
        value: const [
          {
            'pool_ref': {'slug': 'resource-pool', 'name': 'pool:rage_uses'},
            'recharge': 'long_rest',
            'count_by_level': {'1': 2, '3': 3},
          },
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Resource Pools (1)'), findsOneWidget);
      expect(find.text('L1 → 2'), findsOneWidget);
      expect(find.text('L3 → 3'), findsOneWidget);
    });
  });

  group('FieldType.playerChoices editor', () {
    testWidgets('add appends an enum row with one pick', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.playerChoices, label: 'Player Choices'),
        value: const [],
        readOnly: false,
        onChanged: (v) => captured = v,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final row = (captured as List).first as Map;
      expect(row['pick_kind'], 'enum');
      expect(row['pick'], 1);
    });

    testWidgets('renders option chips for enum rows', (tester) async {
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.playerChoices, label: 'Player Choices'),
        value: const [
          {
            'group_id': 'list',
            'label': 'Spell List',
            'pick_kind': 'enum',
            'pick': 1,
            'options': [
              {'id': 'Cleric', 'label': 'Cleric'},
              {'id': 'Druid', 'label': 'Druid'},
            ],
          },
        ],
        readOnly: false,
        onChanged: (_) {},
      )));
      expect(find.text('Player Choices (1)'), findsOneWidget);
      expect(find.text('Cleric'), findsOneWidget);
      expect(find.text('Druid'), findsOneWidget);
    });

    testWidgets('removes row on close button tap', (tester) async {
      dynamic captured;
      await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
        schema: _schema(FieldType.playerChoices, label: 'Player Choices'),
        value: const [
          {'group_id': 'g', 'label': 'G', 'pick_kind': 'enum', 'pick': 1},
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