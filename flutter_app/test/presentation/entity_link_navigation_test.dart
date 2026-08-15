import 'package:dungeon_master_tool/application/providers/ui_state_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/entity_link.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase U3 — every ref on a card is a link.**
///
/// The bug this closes was reported from use: tapping a spell in a spell list
/// did not open that spell's card. Two separate causes, and the tests below
/// pin both — a soft ref `{slug, name}` was not read at all by the
/// presentation layer's private envelope reader (so a packaged spell rendered
/// as nothing), and the structured-list mini fields carried no gesture.
///
/// The harness is deliberately not a screen. What both real screens do with
/// [entityNavigationProvider] is: listen, set their local selection, clear the
/// provider. `_FakeScreen` does exactly that and renders the selected card's
/// name, so "the target card is shown" is asserted through the same single
/// entry point `main_screen` and (since U3) `package_screen` use — not through
/// a test-only callback, which would prove nothing about either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(2400, 1200)
      ..devicePixelRatio = 1.0;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  final entities = <String, Entity>{
    'id-fireball': const Entity(
      id: 'id-fireball',
      categorySlug: 'spell',
      name: 'Fireball',
      fields: {},
    ),
    'id-darkvision': const Entity(
      id: 'id-darkvision',
      categorySlug: 'sense',
      name: 'Darkvision',
      fields: {},
    ),
  };

  FieldSchema schema(
    FieldType type, {
    String label = 'Test',
    bool isList = false,
    List<String>? allowedTypes,
  }) {
    final now = DateTime.now().toIso8601String();
    return FieldSchema(
      fieldId: 'f-1',
      categoryId: 'cat-1',
      fieldKey: 'test',
      label: label,
      fieldType: type,
      isList: isList,
      validation: FieldValidation(allowedTypes: allowedTypes),
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget wrap(Widget Function(WidgetRef ref) build) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 2400,
            child: SingleChildScrollView(child: _FakeScreen(build: build)),
          ),
        ),
      ),
    );
  }

  group('a resolvable ref is a link', () {
    testWidgets('tapping a spell in a spell list opens that spell card',
        (tester) async {
      // The reported case, verbatim: a packaged spell arrives as a soft ref,
      // because its target lives in another package and is resolved by name at
      // read time.
      await tester.pumpWidget(wrap((ref) => FieldWidgetFactory.create(
            schema: schema(FieldType.relation,
                label: 'Spells', isList: true, allowedTypes: const ['spell']),
            value: const [
              {'slug': 'spell', 'name': 'Fireball'}
            ],
            readOnly: true,
            onChanged: (_) {},
            entities: entities,
            ref: ref,
          )));
      await tester.pumpAndSettle();

      expect(find.text('Fireball'), findsOneWidget,
          reason: 'a soft ref used to resolve to a null id and render blank');
      expect(find.text('OPEN: none'), findsOneWidget);

      await tester.tap(find.text('Fireball'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN: Fireball'), findsOneWidget);
    });

    testWidgets('a mini relation field inside a structured row is tappable',
        (tester) async {
      // `_MiniRelationField` — the widget the phase named. It printed the
      // resolved name with no gesture at all.
      await tester.pumpWidget(wrap((ref) => FieldWidgetFactory.create(
            schema: schema(FieldType.rangedSenseList, label: 'Senses'),
            value: const [
              {
                'sense_ref': {'slug': 'sense', 'name': 'Darkvision'},
                'range_ft': 60,
              }
            ],
            readOnly: true,
            onChanged: (_) {},
            entities: entities,
            ref: ref,
          )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Darkvision'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN: Darkvision'), findsOneWidget);
    });
  });

  group('an unresolvable ref stays non-interactive', () {
    testWidgets('a ref into an uninstalled pack does not navigate',
        (tester) async {
      // "A link that opens an empty dialog is worse than no link." The name is
      // still shown — the DM should see what the card asked for — but nothing
      // happens on tap.
      await tester.pumpWidget(wrap((ref) => FieldWidgetFactory.create(
            schema: schema(FieldType.rangedSenseList, label: 'Senses'),
            value: const [
              {
                'sense_ref': {'slug': 'sense', 'name': 'Tremorsense'},
                'range_ft': 30,
              }
            ],
            readOnly: true,
            onChanged: (_) {},
            entities: entities,
            ref: ref,
          )));
      await tester.pumpAndSettle();

      expect(find.text('Tremorsense'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Tremorsense'));
      expect(label.style?.decoration, isNot(TextDecoration.underline),
          reason: 'the underline is the affordance; it must not lie');

      await tester.tap(find.text('Tremorsense'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN: none'), findsOneWidget);
    });
  });

  group('the link path is the reader U1 standardised on', () {
    test('entityLinkTarget is resolveEntityRef, for all four shapes', () {
      for (final raw in <Object>[
        'id-fireball',
        {'slug': 'spell', 'name': 'Fireball'},
        {'_ref': 'spell', 'name': 'Fireball'},
        {'_lookup': 'spell', 'name': 'Fireball'},
      ]) {
        expect(entityLinkTarget(raw, entities), resolveEntityRef(raw, entities),
            reason: 'U3 adds no second envelope reader: $raw');
        expect(entityLinkTarget(raw, entities), 'id-fireball');
      }
      expect(
          entityLinkTarget({'slug': 'spell', 'name': 'Nope'}, entities), isNull);
      expect(entityLinkTarget(null, entities), isNull);
    });

    test('resolveRelationId keeps its empty-string-not-null convention', () {
      expect(resolveRelationId({'slug': 'spell', 'name': 'Fireball'}, entities),
          'id-fireball');
      expect(resolveRelationId({'slug': 'spell', 'name': 'Nope'}, entities), '');
      // A bare id passes through unresolved so a broken hard ref stays visible.
      expect(resolveRelationId('id-missing', entities), 'id-missing');
    });
  });
}

/// Stands in for `main_screen` / `package_screen`: listens to the one
/// navigation provider, keeps its own selection, clears the provider.
class _FakeScreen extends ConsumerStatefulWidget {
  const _FakeScreen({required this.build});
  final Widget Function(WidgetRef ref) build;

  @override
  ConsumerState<_FakeScreen> createState() => _FakeScreenState();
}

class _FakeScreenState extends ConsumerState<_FakeScreen> {
  String? _selectedEntityId;

  static const _names = {
    'id-fireball': 'Fireball',
    'id-darkvision': 'Darkvision',
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(entityNavigationProvider, (_, id) {
      if (id == null) return;
      setState(() => _selectedEntityId = id);
      ref.read(entityNavigationProvider.notifier).state = null;
      ref.read(entityNavigationTargetPanelProvider.notifier).state = null;
    });
    final open = _selectedEntityId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OPEN: ${open == null ? 'none' : _names[open] ?? open}'),
        widget.build(ref),
      ],
    );
  }
}
