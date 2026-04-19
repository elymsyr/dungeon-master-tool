import 'package:dungeon_master_tool/domain/dnd5e/combat/action_economy.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TurnState', () {
    test('speedFt/movement non-negative', () {
      expect(() => TurnState(speedFt: -1), throwsArgumentError);
      expect(() => TurnState(speedFt: 30, movementUsedFt: -1),
          throwsArgumentError);
    });

    test('movementRemaining clamps at budget', () {
      final t = TurnState(speedFt: 30);
      expect(t.movementRemainingFt, 30);
    });

    test('dash doubles budget', () {
      final t = TurnState(speedFt: 30).dash();
      expect(t.movementBudgetFt, 60);
      expect(t.movementRemainingFt, 60);
    });

    test('move decrements remaining', () {
      final t = TurnState(speedFt: 30).move(10);
      expect(t.movementUsedFt, 10);
      expect(t.movementRemainingFt, 20);
    });

    test('move rejects over-budget', () {
      expect(() => TurnState(speedFt: 30).move(40), throwsStateError);
    });

    test('reset clears economy and movement', () {
      final t = TurnState(speedFt: 30).move(15).withEconomy(
            const ActionEconomy.fresh().spendAction(),
          );
      final r = t.reset(35);
      expect(r.speedFt, 35);
      expect(r.movementUsedFt, 0);
      expect(r.economy.actionUsed, isFalse);
    });
  });
}
