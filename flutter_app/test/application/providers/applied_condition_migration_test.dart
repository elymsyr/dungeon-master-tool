import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pre-2.10.0 stored schema: still carries `applied-condition`, and the PC's
/// `current_conditions` still targets it.
WorldSchema _legacySchema() {
  final schema = generateBuiltinDnd5eV2Schema().schema;
  final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
  return schema.copyWith(categories: [
    for (final c in schema.categories)
      if (c.slug == 'player-character')
        c.copyWith(fields: [
          for (final f in c.fields)
            f.fieldKey == 'current_conditions'
                ? f.copyWith(
                    validation: f.validation
                        .copyWith(allowedTypes: ['applied-condition']))
                : f,
        ])
      else
        c,
    npc.copyWith(slug: 'applied-condition', name: 'Applied Condition'),
  ]);
}

void main() {
  test('drops unused applied-condition and repoints current_conditions', () {
    final out = migrateDropAppliedCondition(_legacySchema(), {
      'e1': {'type': 'npc'},
    })!;
    expect(out.categories.map((c) => c.slug), isNot(contains('applied-condition')));
    final pc = out.categories.firstWhere((c) => c.slug == 'player-character');
    final cc = pc.fields.firstWhere((f) => f.fieldKey == 'current_conditions');
    expect(cc.validation.allowedTypes, ['condition']);
  });

  test('keeps applied-condition while a card still uses it', () {
    expect(
      migrateDropAppliedCondition(_legacySchema(), {
        'e1': {'type': 'applied-condition'},
      }),
      isNull,
    );
  });

  test('no-op on a current schema', () {
    expect(
      migrateDropAppliedCondition(generateBuiltinDnd5eV2Schema().schema, {}),
      isNull,
    );
  });
}
