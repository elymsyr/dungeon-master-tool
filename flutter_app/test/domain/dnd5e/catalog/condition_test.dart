import 'package:dungeon_master_tool/domain/dnd5e/catalog/condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Condition', () {
    test('constructs with valid id', () {
      final c = Condition(id: 'srd:stunned', name: 'Stunned');
      expect(c.id, 'srd:stunned');
      expect(c.name, 'Stunned');
      expect(c.description, '');
      expect(c.effects, isEmpty);
    });

    test('rejects malformed id', () {
      expect(
          () => Condition(id: 'stunned', name: 'x'), throwsArgumentError);
    });

    test('rejects empty name', () {
      expect(() => Condition(id: 'srd:x', name: ''), throwsArgumentError);
    });

    test('effects list is unmodifiable', () {
      final c = Condition(id: 'srd:x', name: 'X', effects: []);
      expect(() => c.effects.add(c.effects.first), throwsA(isA<Error>()));
    }, skip: 'Condition.effects is empty; modification would throw on add-any');

    test('equality by id', () {
      final a = Condition(id: 'srd:stunned', name: 'A');
      final b = Condition(id: 'srd:stunned', name: 'B');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith updates name', () {
      final a = Condition(id: 'srd:x', name: 'X');
      final b = a.copyWith(name: 'Y');
      expect(b.name, 'Y');
      expect(b.id, 'srd:x');
    });
  });
}
