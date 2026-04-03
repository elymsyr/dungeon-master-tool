import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/schema/field_group.dart';
import 'package:dungeon_master_tool/domain/entities/schema/default_dnd5e_schema.dart';

void main() {
  group('FieldGroup', () {
    test('creates with defaults', () {
      const group = FieldGroup(groupId: 'test-grp');
      expect(group.groupId, 'test-grp');
      expect(group.name, '');
      expect(group.gridColumns, 1);
      expect(group.orderIndex, 0);
      expect(group.isCollapsed, false);
    });

    test('toJson / fromJson roundtrip', () {
      const group = FieldGroup(
        groupId: 'grp-1',
        name: 'Combat',
        gridColumns: 2,
        orderIndex: 3,
      );

      final json = group.toJson();
      final restored = FieldGroup.fromJson(json);

      expect(restored.groupId, 'grp-1');
      expect(restored.name, 'Combat');
      expect(restored.gridColumns, 2);
      expect(restored.orderIndex, 3);
    });
  });

  group('Default D&D 5e Schema Groups', () {
    test('NPC category has field groups', () {
      final schema = generateDefaultDnd5eSchema();
      final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
      expect(npc.fieldGroups, isNotEmpty);
      expect(npc.fieldGroups.length, greaterThanOrEqualTo(4));
    });

    test('field groups have sequential orderIndex', () {
      final schema = generateDefaultDnd5eSchema();
      final monster = schema.categories.firstWhere((c) => c.slug == 'monster');
      for (var i = 0; i < monster.fieldGroups.length; i++) {
        expect(monster.fieldGroups[i].orderIndex, i);
      }
    });

    test('grouped fields reference valid groupId', () {
      final schema = generateDefaultDnd5eSchema();
      final npc = schema.categories.firstWhere((c) => c.slug == 'npc');
      final validGroupIds = npc.fieldGroups.map((g) => g.groupId).toSet();

      for (final field in npc.fields) {
        if (field.groupId != null) {
          expect(validGroupIds.contains(field.groupId), true,
              reason: '${field.fieldKey} has invalid groupId: ${field.groupId}');
        }
      }
    });

    test('simple categories have no groups', () {
      final schema = generateDefaultDnd5eSchema();
      final quest = schema.categories.firstWhere((c) => c.slug == 'quest');
      expect(quest.fieldGroups, isEmpty);
    });
  });
}
