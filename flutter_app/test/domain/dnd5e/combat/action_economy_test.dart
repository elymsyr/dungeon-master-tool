import 'package:dungeon_master_tool/domain/dnd5e/combat/action_economy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionEconomy', () {
    test('fresh starts all false', () {
      const e = ActionEconomy.fresh();
      expect(e.actionUsed, isFalse);
      expect(e.bonusUsed, isFalse);
      expect(e.reactionUsed, isFalse);
    });

    test('spendAction sets actionUsed only', () {
      final e = const ActionEconomy.fresh().spendAction();
      expect(e.actionUsed, isTrue);
      expect(e.bonusUsed, isFalse);
      expect(e.reactionUsed, isFalse);
    });

    test('all three spends independent', () {
      final e = const ActionEconomy.fresh()
          .spendAction()
          .spendBonus()
          .spendReaction();
      expect(e.actionUsed, isTrue);
      expect(e.bonusUsed, isTrue);
      expect(e.reactionUsed, isTrue);
    });

    test('equality by fields', () {
      expect(
        const ActionEconomy.fresh().spendAction(),
        const ActionEconomy.fresh().spendAction(),
      );
    });
  });
}
