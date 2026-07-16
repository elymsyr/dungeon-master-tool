import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _legacyKindWarning =
    'This modifier kind is not applied to the character sheet.';

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

/// Wraps the editor with a real WidgetRef (via Consumer) so the catalog
/// provider resolves — the badge/warning paths are catalog-driven.
Widget _wrap(FieldType type, dynamic value) {
  return ProviderScope(
    overrides: [
      worldSchemaProvider.overrideWithValue(const WorldSchema(
        schemaId: 'test-schema',
        createdAt: '0',
        updatedAt: '0',
      )),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(2400, 1200)),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 2400,
            child: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) => FieldWidgetFactory.create(
                  schema: _schema(type),
                  value: value,
                  readOnly: false,
                  onChanged: (_) {},
                  ref: ref,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
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

  group('featEffectList deferred badge', () {
    testWidgets('deferred kind shows the play-time badge', (tester) async {
      await tester.pumpWidget(_wrap(FieldType.featEffectList, [
        {'kind': 'advantage_on'},
      ]));
      expect(find.text('play-time'), findsOneWidget);
    });

    testWidgets('applied kind shows no badge', (tester) async {
      await tester.pumpWidget(_wrap(FieldType.featEffectList, [
        {'kind': 'ac_bonus', 'value': 1},
      ]));
      expect(find.text('play-time'), findsNothing);
    });
  });

  group('grantedModifiers legacy-kind warning', () {
    testWidgets('unapplied legacy kind shows the warning icon', (tester) async {
      await tester.pumpWidget(_wrap(FieldType.grantedModifiers, [
        {'kind': 'save_bonus', 'value': 1},
      ]));
      expect(find.byTooltip(_legacyKindWarning), findsOneWidget);
      // The stored kind still renders in the dropdown despite being retired
      // from the offered options.
      expect(find.text('save_bonus'), findsWidgets);
    });

    testWidgets('aliased legacy kind (resistance_grant) is not flagged',
        (tester) async {
      await tester.pumpWidget(_wrap(FieldType.grantedModifiers, [
        {'kind': 'resistance_grant'},
      ]));
      expect(find.byTooltip(_legacyKindWarning), findsNothing);
    });

    testWidgets('feature_text is not flagged (narrative-only)', (tester) async {
      await tester.pumpWidget(_wrap(FieldType.grantedModifiers, [
        {'kind': 'feature_text', 'notes': 'Lore.'},
      ]));
      expect(find.byTooltip(_legacyKindWarning), findsNothing);
    });

    testWidgets('catalog-known kind is not flagged', (tester) async {
      await tester.pumpWidget(_wrap(FieldType.grantedModifiers, [
        {'kind': 'ac_bonus', 'value': 1},
      ]));
      expect(find.byTooltip(_legacyKindWarning), findsNothing);
    });
  });
}
