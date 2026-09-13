// Oyuncu dmOnly kart içeriğini GÖRMEMELİ.
//
// Bilginin cihaza inmesi sorun değil (kurulu paket kartları tam gövdeyle
// gelir); kapı render tarafında. `fieldsVisibleToRole` kart çizen her yolun
// (entity_card, entity_preview_dialog) ortak filtresi — burası tutarsa
// "Secrets"/"Tactics" oyuncunun ekranına düşmez.
//
//   cd flutter_app && flutter test test/domain/field_visibility_role_test.dart

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:flutter_test/flutter_test.dart';

FieldSchema _f(String key, FieldVisibility vis) => FieldSchema(
      fieldId: key,
      categoryId: 'c',
      fieldKey: key,
      label: key,
      fieldType: FieldType.text,
      visibility: vis,
      createdAt: '',
      updatedAt: '',
    );

void main() {
  final fields = [
    _f('name', FieldVisibility.shared),
    _f('secrets', FieldVisibility.dmOnly),
    _f('tactics', FieldVisibility.dmOnly),
  ];

  test('oyuncuda dmOnly alanlar düşer', () {
    expect(
      fieldsVisibleToRole(fields, isPlayer: true).map((f) => f.fieldKey),
      ['name'],
    );
  });

  test('DM tam listeyi görür, liste kimliği korunur', () {
    expect(identical(fieldsVisibleToRole(fields, isPlayer: false), fields),
        isTrue);
    // Düşecek alan yoksa oyuncuda da aynı liste döner (satır cache'i bozulmasın).
    final open = [_f('name', FieldVisibility.shared)];
    expect(identical(fieldsVisibleToRole(open, isPlayer: true), open), isTrue);
  });

  test('builtin şemada hiçbir dmOnly alan oyuncuya kalmaz', () {
    final schema = generateBuiltinDnd5eV2Schema().schema;
    var dmOnlyCount = 0;
    for (final cat in schema.categories) {
      dmOnlyCount +=
          cat.fields.where((f) => f.visibility == FieldVisibility.dmOnly).length;
      expect(
        fieldsVisibleToRole(cat.fields, isPlayer: true)
            .where((f) => f.visibility == FieldVisibility.dmOnly),
        isEmpty,
        reason: '${cat.slug} oyuncuya dmOnly alan sızdırıyor',
      );
    }
    // Şema gerçekten dmOnly alan içeriyor olmalı; yoksa test boşa döner.
    expect(dmOnlyCount, greaterThan(0));
  });
}
