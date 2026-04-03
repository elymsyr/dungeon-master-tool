import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/entity.dart';

void main() {
  group('Entity', () {
    test('creates with defaults', () {
      final entity = Entity(id: 'test-1', categorySlug: 'npc');
      expect(entity.id, 'test-1');
      expect(entity.name, 'New Record');
      expect(entity.categorySlug, 'npc');
      expect(entity.description, '');
      expect(entity.images, isEmpty);
      expect(entity.tags, isEmpty);
      expect(entity.fields, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      final entity = Entity(
        id: 'test-2',
        categorySlug: 'monster',
        name: 'Goblin',
        description: 'A small creature',
        tags: ['hostile', 'humanoid'],
      );

      final updated = entity.copyWith(name: 'Hobgoblin');
      expect(updated.name, 'Hobgoblin');
      expect(updated.description, 'A small creature');
      expect(updated.tags, ['hostile', 'humanoid']);
      expect(updated.categorySlug, 'monster');
    });

    test('toJson / fromJson roundtrip', () {
      final entity = Entity(
        id: 'test-3',
        categorySlug: 'spell',
        name: 'Fireball',
        source: 'PHB',
        description: 'A bright streak flashes',
        tags: ['evocation', 'fire'],
        fields: {'level': 3, 'school': 'Evocation'},
      );

      final json = entity.toJson();
      final restored = Entity.fromJson(json);

      expect(restored.id, entity.id);
      expect(restored.name, entity.name);
      expect(restored.source, entity.source);
      expect(restored.tags, entity.tags);
      expect(restored.fields['level'], 3);
    });
  });
}
