import 'package:dungeon_master_tool/data/datasources/local/custom_template_store.dart';
import 'package:dungeon_master_tool/domain/entities/custom_fields.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/template_mechanics.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

FieldSchema _field(String key) {
  final now = DateTime.now().toUtc().toIso8601String();
  return FieldSchema(
    fieldId: 'f-$key',
    categoryId: 'cat',
    fieldKey: key,
    label: key,
    fieldType: FieldType.text,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('mechanics gate', () {
    test('only the shipped built-in template runs mechanics', () {
      final builtin = generateBuiltinDnd5eV2Schema().schema;
      expect(schemaHasMechanics(builtin), isTrue);

      // A copy carries the same categories but a new schemaId — deliberately
      // mechanics-free (the resolver is bound to the built-in contract).
      final copy = builtin.copyWith(schemaId: 'custom-1');
      expect(schemaHasMechanics(copy), isFalse);
      expect(templateIdHasMechanics(null), isFalse);
    });
  });

  group('free fields', () {
    test('roundtrip through the untyped entity fields map', () {
      final fields = <String, dynamic>{
        'name': 'Bob',
        kCustomFieldsKey: encodeCustomFields([_field('favourite_ale')]),
      };
      final read = customFieldsOf(fields);
      expect(read, hasLength(1));
      expect(read.single.fieldKey, 'favourite_ale');
    });

    test('a broken definition does not take the whole card down', () {
      final fields = <String, dynamic>{
        kCustomFieldsKey: [
          {'garbage': true},
          ...encodeCustomFields([_field('ok')]),
        ],
      };
      expect(customFieldsOf(fields).map((f) => f.fieldKey), ['ok']);
    });

    test('no custom fields reads as empty, never throws', () {
      expect(customFieldsOf({}), isEmpty);
      expect(customFieldsOf({kCustomFieldsKey: 'not a list'}), isEmpty);
    });
  });

  group('CustomTemplateStore', () {
    test('upsert / list / delete against the side table', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final store = CustomTemplateStore(db);

      final now = DateTime.now().toUtc().toIso8601String();
      final schema = WorldSchema(
        schemaId: 'custom-1',
        name: 'Homebrew',
        createdAt: now,
        updatedAt: now,
      );

      expect(await store.list(), isEmpty);
      await store.upsert(schema);
      expect((await store.list()).single.name, 'Homebrew');

      await store.upsert(schema.copyWith(name: 'Homebrew v2'));
      final rows = await store.list();
      expect(rows, hasLength(1), reason: 'upsert must not duplicate');
      expect(rows.single.name, 'Homebrew v2');

      await store.delete('custom-1');
      expect(await store.list(), isEmpty);
    });
  });
}
