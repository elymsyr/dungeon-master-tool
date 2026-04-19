import 'package:dungeon_master_tool/domain/dnd5e/combat/initiative.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InitiativeOrder', () {
    test('rejects empty list', () {
      expect(() => InitiativeOrder(combatantIds: []), throwsArgumentError);
    });

    test('advance wraps to 0', () {
      final o = InitiativeOrder(combatantIds: ['a', 'b', 'c']);
      expect(o.currentId, 'a');
      final next = o.advance().advance().advance();
      expect(next.currentId, 'a');
    });

    test('currentIndex validated', () {
      expect(
          () => InitiativeOrder(combatantIds: ['a'], currentIndex: 1),
          throwsArgumentError);
    });
  });

  group('InitiativeOrder.sortIds', () {
    test('higher roll first', () {
      final ids = InitiativeOrder.sortIds({
        'a': (roll: 10, tieBreaker: 0),
        'b': (roll: 20, tieBreaker: 0),
      });
      expect(ids, ['b', 'a']);
    });

    test('ties broken by tieBreaker then id', () {
      final ids = InitiativeOrder.sortIds({
        'a': (roll: 15, tieBreaker: 3),
        'b': (roll: 15, tieBreaker: 5),
        'c': (roll: 15, tieBreaker: 3),
      });
      expect(ids, ['b', 'a', 'c']);
    });
  });
}
