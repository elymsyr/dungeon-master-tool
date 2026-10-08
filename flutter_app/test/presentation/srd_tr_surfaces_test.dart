import 'package:dungeon_master_tool/application/character_creation/pending_choices.dart';
import 'package:dungeon_master_tool/application/providers/content_translator_provider.dart';
import 'package:dungeon_master_tool/application/services/entity_snapshot_builder.dart';
import 'package:dungeon_master_tool/application/services/projection_ipc.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/projection/battle_map_snapshot.dart';
import 'package:dungeon_master_tool/domain/entities/projection/entity_snapshot.dart';
import 'package:dungeon_master_tool/domain/entities/projection/projection_item.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/content_translator.dart';
import 'package:dungeon_master_tool/domain/services/entity_search.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/player_window/player_window_state_provider.dart';
import 'package:dungeon_master_tool/presentation/screens/player_window/views/entity_card_projection_view.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/character_stat_chips.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:dungeon_master_tool/presentation/widgets/pending_choices_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/srd-tr/ROADMAP.md Faz 6: SRD adları her yüzeyde, her cihazın kendi
/// dilinde. DM'den çıkan her şey (projeksiyon, token) İngilizce kalır; çeviri
/// alıcıda yapılır.
void main() {
  const tr = ContentTranslator({
    'monster': {'Goblin Warrior': 'Goblin Savaşçı', 'A small humanoid.': 'Küçük bir insansı.'},
    'condition': {'Prone': 'Yere Düşme'},
    'weapon': {'Scimitar': 'Pala'},
    '_schema': {
      'Monster': 'Canavar',
      'Size': 'Boyut',
      'Medium': 'Orta Boy',
      'Weapons': 'Silahlar',
      'Notes': 'Notlar',
    },
  });
  String trFn(String s, String en) => tr.tr(s, en);

  group('EntitySnapshot', () {
    const snap = EntitySnapshot(
      id: 'g',
      name: 'Goblin Warrior',
      categorySlug: 'monster',
      categoryName: 'Monster',
      description: 'A small humanoid.',
      fields: [
        EntityFieldSnapshot(
            label: 'Size', value: 'Medium', parts: [('_schema', 'Medium')]),
        EntityFieldSnapshot(
            label: 'Weapons',
            value: 'Scimitar, Club',
            parts: [('weapon', 'Scimitar'), ('weapon', 'Club')]),
        // Eski gönderen: parça yok → değer aynen.
        EntityFieldSnapshot(label: 'Notes', value: 'Scimitar'),
      ],
    );

    test('JSON gidiş-dönüşü parçaları korur, İngilizce kalır', () {
      final back = EntitySnapshot.fromJson(snap.toJson());
      expect(back.name, 'Goblin Warrior');
      expect(back.fields[1].parts, [('weapon', 'Scimitar'), ('weapon', 'Club')]);
      expect(back.fields[2].parts, isNull);
    });

    test('localized: alıcı kendi dilinde birleştirir', () {
      final l = snap.localized(trFn);
      expect(l.name, 'Goblin Savaşçı');
      expect(l.categoryName, 'Canavar');
      expect(l.description, 'Küçük bir insansı.');
      expect(l.fields[0].label, 'Boyut');
      expect(l.fields[0].value, 'Orta Boy');
      expect(l.fields[1].value, 'Pala, Club');
      expect(l.fields[2].label, 'Notlar');
      expect(l.fields[2].value, 'Scimitar');
      // Kaynak değişmez.
      expect(snap.name, 'Goblin Warrior');
    });
  });

  test('EntitySnapshotBuilder metin, enum ve ilişkiye parça ekler', () {
    const now = '2026-10-08';
    FieldSchema f(String key, FieldType t) => FieldSchema(
        fieldId: key,
        categoryId: 'c',
        fieldKey: key,
        label: key,
        fieldType: t,
        createdAt: now,
        updatedAt: now);
    final schema = WorldSchema(
      schemaId: 's',
      createdAt: now,
      updatedAt: now,
      categories: [
        EntityCategorySchema(
          categoryId: 'c',
          schemaId: 's',
          name: 'Monster',
          slug: 'monster',
          createdAt: now,
          updatedAt: now,
          fields: [
            f('size', FieldType.enum_),
            f('weapon', FieldType.relation),
            f('lore', FieldType.text),
          ],
        ),
      ],
    );
    const scimitar =
        Entity(id: 'w1', name: 'Scimitar', categorySlug: 'weapon');
    const goblin = Entity(
      id: 'g',
      name: 'Goblin Warrior',
      categorySlug: 'monster',
      fields: {'size': 'Medium', 'weapon': 'w1', 'lore': 'Sneaky.'},
    );
    final snap = EntitySnapshotBuilder.build(
        entity: goblin, schema: schema, entities: {'w1': scimitar});
    final byLabel = {for (final r in snap.fields) r.label: r};
    expect(byLabel['size']!.parts, [(ContentTranslator.schemaScope, 'Medium')]);
    expect(byLabel['weapon']!.value, 'Scimitar');
    expect(byLabel['weapon']!.parts, [('weapon', 'Scimitar')]);
    expect(byLabel['lore']!.parts, [('monster', 'Sneaky.')]);
  });

  group('TokenSnapshot', () {
    test('kart adındaki token çevrilir, DM\'in verdiği ad aynen kalır', () {
      const t = TokenSnapshot(
        id: 'a',
        name: 'Goblin Warrior',
        x: 0,
        y: 0,
        nameScope: 'monster',
        conditions: [ConditionSnapshot(name: 'Prone', turns: 2)],
      );
      final back = TokenSnapshot.fromJson(t.toJson());
      expect(back.nameScope, 'monster');
      final l = back.localized(trFn);
      expect(l.name, 'Goblin Savaşçı');
      expect(l.conditions.single.name, 'Yere Düşme');
      expect(l.conditions.single.turns, 2);

      const renamed =
          TokenSnapshot(id: 'b', name: 'Goblin Warrior', x: 0, y: 0);
      expect(renamed.localized(trFn).name, 'Goblin Warrior');
    });
  });

  group('arama', () {
    const goblin =
        Entity(id: 'g', name: 'Goblin Warrior', categorySlug: 'monster');
    const potion = Entity(
        id: 'p', name: 'Potion of Healing', categorySlug: 'magic-item');

    test('gösterilen adla da eşleşir; İngilizce ad çalışmaya devam eder', () {
      final shown = {
        'g': searchFold('Goblin Savaşçı'),
        'p': searchFold('İyileştirme İksiri'),
      };
      expect(rankEntities([goblin, potion], 'savaşçı', shownNames: shown),
          [goblin]);
      expect(rankEntities([goblin, potion], 'warrior', shownNames: shown),
          [goblin]);
      // Dart 'İ'.toLowerCase() = "i̇"; searchFold "iksir" ile eşleştirir.
      expect(rankEntities([goblin, potion], 'iksir', shownNames: shown),
          [potion]);
    });
  });

  group('her cihaz kendi dili', () {
    const snap = EntitySnapshot(
        id: 'g',
        name: 'Goblin Warrior',
        categorySlug: 'monster',
        categoryName: 'Monster');
    const item = EntityCardProjection(
        id: 'i', label: 'Goblin', entityId: 'g', snapshot: snap);

    Future<void> pump(WidgetTester tester, ContentTranslator tx) =>
        tester.pumpWidget(ProviderScope(
          overrides: [contentTranslatorProvider.overrideWithValue(tx)],
          child: const MaterialApp(
              home: Scaffold(body: EntityCardProjectionView(item: item))),
        ));

    testWidgets('aynı İngilizce yayın: Türkçe cihaz Türkçe görür',
        (tester) async {
      await pump(tester, tr);
      expect(find.text('Goblin Savaşçı'), findsOneWidget);
      expect(find.text('Goblin Warrior'), findsNothing);
    });

    testWidgets('aynı İngilizce yayın: İngilizce cihaz İngilizce görür',
        (tester) async {
      await pump(tester, ContentTranslator.identity);
      expect(find.text('Goblin Warrior'), findsOneWidget);
    });

    test('ana uygulamada dil arayüz dilidir', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(contentLanguageProvider), 'en');
    });

    test('yerel projeksiyon penceresi DM\'in IPC ile gelen dilini kullanır',
        () {
      final c = ProviderContainer(overrides: projectionLanguageOverrides);
      addTearDown(c.dispose);
      expect(c.read(contentLanguageProvider), 'en');
      c.read(projectionContentLanguageProvider.notifier).state = 'tr';
      expect(c.read(contentLanguageProvider), 'tr');
    });

    test('IPC tam durum zarfı dili taşır; yama taşımaz', () {
      const full =
          '{"type":"full","payload":{"items":[]},"lang":"tr"}';
      const patch = '{"type":"patch","payload":{}}';
      expect(ProjectionIpc.decodeApply(full).$3, 'tr');
      expect(ProjectionIpc.decodeApply(patch).$3, isNull);
    });
  });

  group('karakter sayfası', () {
    const sheetTr = ContentTranslator({
      'ability': {'STR': 'KUV', 'Strength': 'Kuvvet'},
      'skill': {'Athletics': 'Atletizm'},
      'class': {'Wizard': 'Büyücü'},
      'species': {'Elf': 'Elf', 'Human': 'İnsan'},
      '_schema': {'Skills': 'Yetenekler'},
    });

    Widget wrap(Widget child) => ProviderScope(
          overrides: [contentTranslatorProvider.overrideWithValue(sheetTr)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            theme: buildThemeData('dark'),
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );

    testWidgets('kabiliyet, kurtarma ve yetenek tabloları çevrilir',
        (tester) async {
      final pc = generateBuiltinDnd5eV2Schema()
          .schema
          .categories
          .firstWhere((c) => c.slug == 'player-character');
      FieldSchema f(String k) => pc.fields.firstWhere((x) => x.fieldKey == k);
      Widget tile(String k) => FieldWidgetFactory.create(
            schema: sheetTr.field(f(k)),
            value: null,
            readOnly: false,
            onChanged: (_) {},
            entityFields: const {
              'stat_block': {'STR': 14},
            },
          );
      await tester.pumpWidget(wrap(Column(children: [
        tile('stat_block'),
        tile('saving_throws'),
        tile('skills'),
      ])));
      expect(find.text('Yetenekler'), findsOneWidget);
      expect(find.text('Kuvvet'), findsOneWidget); // kurtarma satırı
      expect(find.text('Atletizm'), findsOneWidget);
      expect(find.text('KUV'), findsWidgets); // blok + satır kısaltmaları
      expect(find.text('Strength'), findsNothing);
      expect(find.text('Athletics'), findsNothing);
      expect(find.text('STR'), findsNothing);
    });

    testWidgets('bekleyen seçim etiketi arayüz dilinde, sınıf adı çevrili',
        (tester) async {
      late String label;
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        label = pendingChoiceLabel(
            context,
            const PendingChoice(
              id: 'p',
              kind: PendingChoiceKind.spells,
              level: 4,
              classLabel: 'Wizard',
              count: 2,
              maxSpellLevel: 2,
            ));
        return const SizedBox();
      })));
      expect(label, 'Büyücü 4. seviye · 2 büyü seç (en fazla 2. seviye)');
    });

    test('karakter listesi çipleri: tür ve sınıf bu cihazın dilinde', () {
      const c = Character(
        id: 'c',
        templateId: 't',
        templateName: 'PC',
        createdAt: '',
        updatedAt: '',
        entity: Entity(
          id: 'e',
          name: 'Jamal',
          categorySlug: 'player-character',
          fields: {
            'species_ref': {'slug': 'species', 'name': 'Human'},
            'class_refs': ['cl'],
          },
        ),
      );
      final lines = characterStatLines(
        c,
        {'cl': const Entity(id: 'cl', name: 'Wizard', categorySlug: 'class')},
        tx: sheetTr,
        l10n: lookupL10n(const Locale('tr')),
      );
      final byLabel = {for (final l in lines) l.label: l.value};
      expect(byLabel['Tür'], 'İnsan');
      expect(byLabel['Sınıf'], 'Büyücü');
      expect(byLabel.containsKey('Can Puanı'), isTrue);
    });
  });
}
