// Gerçek paket verisi gerçek alan widget'larında render oluyor mu.
//
// M1 mekaniğin çözüldüğünü, U2 sihirbazın satırı gördüğünü kanıtlıyor; ikisi de
// hiçbir widget çalıştırmıyor. Şema bir alanı `FieldType.x` diye ilan edip paket
// oraya başka şekilde bir değer yazdığında hata **sadece ekranda** ortaya çıkar.
// Bu dosya o boşluğu kapatır: her paketten her (kategori, alan) çifti bir kez,
// gerçek değeriyle, hem salt-okunur hem düzenleme modunda pump edilir.
//
//   cd flutter_app && flutter test test/presentation/pack_field_render_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/presentation/widgets/field_widgets/field_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 2400,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

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

  final schema = generateBuiltinDnd5eV2Schema().schema;
  final fieldsByCategory = <String, Map<String, FieldSchema>>{
    for (final c in schema.categories)
      c.slug: {for (final f in c.fields) f.fieldKey: f},
  };

  final packFiles = Directory('assets/open5e_packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // (kategori, alan) çifti başına tek örnek yeter — aynı alanı 3000 kez pump
  // etmek testi dakikalara çıkarır, yeni bilgi vermez.
  final seen = <String>{};
  var rendered = 0;

  for (final file in packFiles) {
    final slug = file.uri.pathSegments.last.replaceAll('.pkg.json', '');

    testWidgets('$slug fields render', (tester) async {
      final payload =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final entities = (payload['entities'] as Map).cast<String, dynamic>();

      for (final entry in entities.entries) {
        final e = (entry.value as Map).cast<String, dynamic>();
        final fields = fieldsByCategory[e['type']];
        if (fields == null) continue;
        final attrs =
            (e['attributes'] as Map?)?.cast<String, dynamic>() ?? const {};

        for (final a in attrs.entries) {
          final fs = fields[a.key];
          if (fs == null || a.value == null) continue;
          if (!seen.add('${e['type']}/${a.key}')) continue;

          for (final readOnly in const [true, false]) {
            await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
              schema: fs,
              value: a.value,
              readOnly: readOnly,
              onChanged: (_) {},
            )));
            await tester.pump();
            expect(tester.takeException(), isNull,
                reason: '$slug: ${e['name']} → ${e['type']}.${a.key} '
                    '(${fs.fieldType.name}, readOnly=$readOnly) render hatası');
            rendered++;
          }
        }
      }
    });
  }

  // Built-in SRD aynı hatayı taşıyordu (Dragonborn'un `granted_senses`'i de
  // soft ref) — paketler değil, her kullanıcının gördüğü içerik.
  testWidgets('builtin SRD fields render', (tester) async {
    final srd = buildBuiltinSrdEntities();
    for (final e in srd.values) {
      final fields = fieldsByCategory[e.categorySlug];
      if (fields == null) continue;
      for (final a in e.fields.entries) {
        final fs = fields[a.key];
        if (fs == null || a.value == null) continue;
        if (!seen.add('srd/${e.categorySlug}/${a.key}')) continue;

        for (final readOnly in const [true, false]) {
          await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
            schema: fs,
            value: a.value,
            readOnly: readOnly,
            onChanged: (_) {},
          )));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: 'SRD: ${e.name} → ${e.categorySlug}.${a.key} '
                  '(${fs.fieldType.name}, readOnly=$readOnly) render hatası');
          rendered++;
        }
      }
    }
  });

  // R3 açtığı dört alan henüz `assets/open5e_packs/` içinde değil (Stage R tek
  // seferde promote ediyor), yani yukarıdaki tarama onlara dokunamaz. Değerler
  // mapper'ın gerçekten yazdığı biçim: kaynağın kendi cümlesi, kaynağın kendi
  // bedeli, `{sense_ref, range_ft}` satırı.
  group('R3 — yeni (kategori, alan) çiftleri', () {
    final cases = <(String, String, dynamic, String?)>[
      (
        'monster',
        'resistance_note',
        'fire; bludgeoning, piercing, and slashing from nonmagical attacks',
        'fire; bludgeoning, piercing, and slashing from nonmagical attacks',
      ),
      (
        'monster',
        'immunity_note',
        'bludgeoning, piercing, and slashing from nonmagical attacks',
        'bludgeoning, piercing, and slashing from nonmagical attacks',
      ),
      (
        'monster',
        'language_note',
        "understands Common but can't speak",
        "understands Common but can't speak",
      ),
      ('creature-action', 'legendary_action_cost', 2, '2'),
      (
        'monster',
        'senses',
        [
          {
            'sense_ref': {'_lookup': 'sense', 'name': 'Keensense'},
            'range_ft': 60,
          },
        ],
        '60',
      ),
    ];

    for (final c in cases) {
      final (category, key, value, expectText) = c;
      testWidgets('$category.$key', (tester) async {
        final fs = fieldsByCategory[category]![key];
        expect(fs, isNotNull, reason: '$category.$key şemada yok');

        for (final readOnly in const [true, false]) {
          await tester.pumpWidget(_wrap(FieldWidgetFactory.create(
            schema: fs!,
            value: value,
            readOnly: readOnly,
            onChanged: (_) {},
          )));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '$category.$key (readOnly=$readOnly) render hatası');
          if (expectText != null) {
            expect(find.textContaining(expectText, findRichText: true),
                findsWidgets,
                reason: '$category.$key (readOnly=$readOnly) değeri '
                    'ekranda görünmüyor');
          }
        }
      });
    }
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('pack_field_render: ${seen.length} (kategori, alan) çifti, '
        '$rendered pump');
  });
}
