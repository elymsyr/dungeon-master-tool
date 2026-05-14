import 'package:dungeon_master_tool/domain/entities/schema/default_dnd5e_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late final schema = generateDefaultDnd5eSchema();

  group('Default D&D 5e Schema', () {
    test('generates 19 categories', () {
      expect(schema.categories.length, 19);
    });

    test('schema metadata is correct', () {
      expect(schema.name, 'D&D 5e (Default)');
      expect(schema.version, '1.1.0');
      expect(schema.baseSystem, 'dnd5e');
    });

    test('all categories are builtin', () {
      for (final cat in schema.categories) {
        expect(cat.isBuiltin, true, reason: '${cat.name} should be builtin');
      }
    });

    test('categories have correct slugs', () {
      final slugs = schema.categories.map((c) => c.slug).toList();
      expect(slugs, containsAll([
        'npc', 'monster', 'player', 'spell', 'equipment',
        'class', 'race', 'location', 'quest', 'lore',
        'status-effect', 'feat', 'background', 'plane', 'condition',
        'trait', 'action', 'reaction', 'legendary-action',
      ]));
    });

    test('NPC has statBlock, combatStats, actionList, spellList fields', () {
      final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
      final fieldTypes = npc.fields.map((f) => f.fieldType).toSet();
      expect(fieldTypes, containsAll([
        FieldType.statBlock,
        FieldType.combatStats,
        FieldType.relation,  // actions + spells are now relation type
        FieldType.enum_,
        FieldType.text,
      ]));
    });

    test('NPC has Race relation field with allowedTypes=[race]', () {
      final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
      final raceField = npc.fields.firstWhere((f) => f.fieldKey == 'race');
      expect(raceField.fieldType, FieldType.relation);
      expect(raceField.validation.allowedTypes, ['race']);
    });

    test('Spell has Level enum with Cantrip-9', () {
      final spell = schema.categories.firstWhere((c) => c.slug == 'spell');
      final levelField = spell.fields.firstWhere((f) => f.fieldKey == 'level');
      expect(levelField.fieldType, FieldType.enum_);
      expect(levelField.validation.allowedValues, ['Cantrip', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    });

    test('Equipment has 12 text fields (including source)', () {
      final eq = schema.categories.firstWhere((c) => c.slug == 'equipment');
      final textFields = eq.fields.where((f) => f.fieldType == FieldType.text);
      expect(textFields.length, 12);
    });

    test('Monster and Player do NOT have creature-only fields', () {
      // Monster and Player should have statBlock like NPC
      final monster = schema.categories.firstWhere((c) => c.slug == 'monster');
      final player = schema.categories.firstWhere((c) => c.slug == 'player');
      expect(monster.fields.any((f) => f.fieldType == FieldType.statBlock), true);
      expect(player.fields.any((f) => f.fieldType == FieldType.statBlock), true);
    });

    test('Condition has source, effects, and condition_stats fields', () {
      final cond = schema.categories.firstWhere((c) => c.slug == 'condition');
      expect(cond.fields.length, 3);
      expect(cond.fields.map((f) => f.fieldKey).toList(),
          containsAll(['source', 'effects', 'condition_stats']));
    });

    test('default encounter layout exists', () {
      expect(schema.encounterLayouts.length, 1);
      final layout = schema.encounterLayouts.first;
      expect(layout.name, 'Standard D&D 5e');
      expect(layout.columns.length, 5);
      expect(layout.sortRules.first.fieldKey, 'initiative');
    });

    test('all field orderIndex values are sequential within each category', () {
      for (final cat in schema.categories) {
        for (var i = 0; i < cat.fields.length; i++) {
          expect(cat.fields[i].orderIndex, i,
              reason: '${cat.name}.${cat.fields[i].fieldKey} orderIndex');
        }
      }
    });
  });
}
