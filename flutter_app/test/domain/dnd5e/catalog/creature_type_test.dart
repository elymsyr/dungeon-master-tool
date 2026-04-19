import 'package:dungeon_master_tool/domain/dnd5e/catalog/creature_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreatureType', () {
    test('constructs', () {
      final t = CreatureType(id: 'srd:humanoid', name: 'Humanoid');
      expect(t.id, 'srd:humanoid');
    });

    test('rejects empty name', () {
      expect(() => CreatureType(id: 'srd:x', name: ''), throwsArgumentError);
    });

    test('equality by id', () {
      expect(CreatureType(id: 'srd:fiend', name: 'A'),
          CreatureType(id: 'srd:fiend', name: 'B'));
    });
  });
}
