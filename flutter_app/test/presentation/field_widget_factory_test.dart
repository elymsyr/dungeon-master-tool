import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:dungeon_master_tool/presentation/widgets/markdown_text_area.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';

FieldSchema _makeSchema(
  FieldType type, {
  String label = 'Test',
  String key = 'test',
  FieldValidation? validation,
}) {
  final now = DateTime.now().toIso8601String();
  return FieldSchema(
    fieldId: 'f-1',
    categoryId: 'cat-1',
    fieldKey: key,
    label: label,
    fieldType: type,
    validation: validation ?? const FieldValidation(),
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  // ─────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────
  group('FieldType.text', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.text, label: 'Character Name');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Character Name:'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows initial value', (tester) async {
      final schema = _makeSchema(FieldType.text, label: 'Name');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'Gandalf',
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Gandalf'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      dynamic captured;
      final schema = _makeSchema(FieldType.text, label: 'Name');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '',
          readOnly: false,
          onChanged: (v) => captured = v,
        ),
      ));
      await tester.enterText(find.byType(TextFormField), 'Frodo');
      expect(captured, 'Frodo');
    });

    testWidgets('readOnly mode shows static text', (tester) async {
      final schema = _makeSchema(FieldType.text, label: 'Name');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'Locked',
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // TEXTAREA
  // ─────────────────────────────────────────────
  group('FieldType.textarea', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.textarea, label: 'Description');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Description'), findsOneWidget);
      expect(find.byType(MarkdownTextArea), findsOneWidget);
    });

    testWidgets('has maxLines set to 4', (tester) async {
      final schema = _makeSchema(FieldType.textarea, label: 'Bio');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '',
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      final area =
          tester.widget<MarkdownTextArea>(find.byType(MarkdownTextArea));
      expect(area.maxLines, 4);
    });

    testWidgets('shows initial value', (tester) async {
      final schema = _makeSchema(FieldType.textarea, label: 'Bio');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'A brave warrior',
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('A brave warrior'), findsOneWidget);
    });

    testWidgets('readOnly mode prevents editing', (tester) async {
      final schema = _makeSchema(FieldType.textarea, label: 'Bio');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'Locked text',
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      final area =
          tester.widget<MarkdownTextArea>(find.byType(MarkdownTextArea));
      expect(area.readOnly, isTrue);
      expect(find.byType(TextField), findsNothing);
    });
  });

  // ─────────────────────────────────────────────
  // INTEGER
  // ─────────────────────────────────────────────
  group('FieldType.integer', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.integer, label: 'Level');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Level:'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows initial numeric value', (tester) async {
      final schema = _makeSchema(FieldType.integer, label: 'Level');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 5,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('uses number keyboard type', (tester) async {
      final schema = _makeSchema(FieldType.integer, label: 'HP');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 0,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('calls onChanged with parsed int', (tester) async {
      dynamic captured;
      final schema = _makeSchema(FieldType.integer, label: 'HP');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '',
          readOnly: false,
          onChanged: (v) => captured = v,
        ),
      ));
      await tester.enterText(find.byType(TextFormField), '42');
      expect(captured, 42);
    });

    testWidgets('readOnly mode shows static text', (tester) async {
      final schema = _makeSchema(FieldType.integer, label: 'HP');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 10,
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('10'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // BOOLEAN
  // ─────────────────────────────────────────────
  group('FieldType.boolean_', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.boolean_, label: 'Is Active');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: false,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Is Active:'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('shows initial true value', (tester) async {
      final schema = _makeSchema(FieldType.boolean_, label: 'Active');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: true,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
    });

    testWidgets('shows initial false value', (tester) async {
      final schema = _makeSchema(FieldType.boolean_, label: 'Active');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: false,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isFalse);
    });

    testWidgets('toggle calls onChanged', (tester) async {
      dynamic captured;
      final schema = _makeSchema(FieldType.boolean_, label: 'Active');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: false,
          readOnly: false,
          onChanged: (v) => captured = v,
        ),
      ));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(captured, isTrue);
    });

    testWidgets('readOnly true value still renders disabled checkbox', (tester) async {
      final schema = _makeSchema(FieldType.boolean_, label: 'Active');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: true,
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.onChanged, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // ENUM
  // ─────────────────────────────────────────────
  group('FieldType.enum_', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(
        FieldType.enum_,
        label: 'Alignment',
        validation: const FieldValidation(
          allowedValues: ['Good', 'Neutral', 'Evil'],
        ),
      );
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Alignment:'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('shows allowed values in dropdown', (tester) async {
      final schema = _makeSchema(
        FieldType.enum_,
        label: 'Size',
        validation: const FieldValidation(
          allowedValues: ['Small', 'Medium', 'Large'],
        ),
      );
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      // Tap the dropdown to open the menu
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Small'), findsWidgets);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('Large'), findsWidgets);
    });

    testWidgets('shows initial value', (tester) async {
      final schema = _makeSchema(
        FieldType.enum_,
        label: 'Size',
        validation: const FieldValidation(
          allowedValues: ['Small', 'Medium', 'Large'],
        ),
      );
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'Medium',
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      // The selected value is shown in the dropdown button
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('readOnly mode shows static text', (tester) async {
      final schema = _makeSchema(
        FieldType.enum_,
        label: 'Size',
        validation: const FieldValidation(
          allowedValues: ['Small', 'Medium', 'Large'],
        ),
      );
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: 'Small',
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Small'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // STAT BLOCK
  // ─────────────────────────────────────────────
  group('FieldType.statBlock', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Ability Scores');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Ability Scores'), findsOneWidget);
    });

    testWidgets('shows all 6 ability score labels', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Stats');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('DEX'), findsOneWidget);
      expect(find.text('CON'), findsOneWidget);
      expect(find.text('INT'), findsOneWidget);
      expect(find.text('WIS'), findsOneWidget);
      expect(find.text('CHA'), findsOneWidget);
    });

    testWidgets('shows initial stat values', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Stats');
      final statValues = {
        'STR': 18,
        'DEX': 14,
        'CON': 12,
        'INT': 8,
        'WIS': 10,
        'CHA': 16,
      };
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: statValues,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('18'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // 10 is both the value for WIS and the default, find at least one
      expect(find.text('10'), findsWidgets);
      expect(find.text('16'), findsOneWidget);
    });

    testWidgets('defaults to 10 when no value provided', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Stats');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: <String, dynamic>{},
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      // All 6 fields should show default value of 10
      expect(find.text('10'), findsNWidgets(6));
    });

    testWidgets('shows modifier text', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Stats');
      // STR 14 -> mod +2, DEX 8 -> mod -1
      final statValues = {
        'STR': 14,
        'DEX': 8,
        'CON': 10,
        'INT': 10,
        'WIS': 10,
        'CHA': 10,
      };
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: statValues,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      // +0 for the four stats at 10
      expect(find.text('+0'), findsNWidgets(4));
    });

    testWidgets('renders inside a Card', (tester) async {
      final schema = _makeSchema(FieldType.statBlock, label: 'Stats');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(Card), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────
  // DICE
  // ─────────────────────────────────────────────
  group('FieldType.dice', () {
    testWidgets('renders without errors and shows label', (tester) async {
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Damage'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows hint text for dice notation', (tester) async {
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('e.g. 2d6+3'), findsOneWidget);
    });

    testWidgets('shows dice icon', (tester) async {
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: null,
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.byIcon(Icons.casino), findsOneWidget);
    });

    testWidgets('shows initial value', (tester) async {
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '2d6+3',
          readOnly: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('2d6+3'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      dynamic captured;
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '',
          readOnly: false,
          onChanged: (v) => captured = v,
        ),
      ));
      await tester.enterText(find.byType(TextFormField), '1d20+5');
      expect(captured, '1d20+5');
    });

    testWidgets('readOnly mode prevents editing', (tester) async {
      final schema = _makeSchema(FieldType.dice, label: 'Damage');
      await tester.pumpWidget(_wrap(
        FieldWidgetFactory.create(
          schema: schema,
          value: '3d8',
          readOnly: true,
          onChanged: (_) {},
        ),
      ));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isTrue);
    });
  });
}
