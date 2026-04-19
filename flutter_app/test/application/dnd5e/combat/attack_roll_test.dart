import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/attack_roll.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> queue;
  int i = 0;
  _QueueRng(this.queue);
  @override
  int nextInt(int max) => queue[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

AttackResolver _resolver(List<int> rolls) =>
    AttackResolver(D20Roller(_QueueRng(rolls)));

AttackRollInput _input({
  int mod = 3,
  int pb = 2,
  int flat = 0,
  int ac = 15,
  int cover = 0,
  AdvantageState adv = AdvantageState.normal,
}) =>
    AttackRollInput(
      abilityMod: mod,
      proficiencyBonus: pb,
      flatBonus: flat,
      targetArmorClass: ac,
      coverAcBonus: cover,
      advantage: adv,
    );

void main() {
  group('AttackResolver', () {
    test('hit when total >= AC', () {
      // roll 14 → total 14+3+2 = 19 vs AC 15
      final res = _resolver([13]).resolve(_input(ac: 15));
      expect(res.hit, true);
      expect(res.isCritical, false);
      expect(res.totalRoll, 19);
      expect(res.effectiveAc, 15);
    });

    test('miss when total < AC', () {
      // roll 5 → total 5+3+2 = 10 vs AC 15
      final res = _resolver([4]).resolve(_input(ac: 15));
      expect(res.hit, false);
      expect(res.isCritical, false);
    });

    test('natural 20 always critical, even if would miss on mods', () {
      final res = _resolver([19]).resolve(_input(ac: 30, mod: 0, pb: 0));
      expect(res.hit, true);
      expect(res.isCritical, true);
    });

    test('natural 1 always misses', () {
      final res = _resolver([0]).resolve(_input(ac: 5, mod: 10, pb: 4));
      expect(res.hit, false);
      expect(res.isFumble, true);
    });

    test('cover raises effective AC', () {
      // roll 10 + 3 + 2 = 15 vs AC 15 → hit without cover
      expect(_resolver([9]).resolve(_input(ac: 15, cover: 0)).hit, true);
      // same roll vs AC 15 + 2 cover → miss
      expect(_resolver([9]).resolve(_input(ac: 15, cover: 2)).hit, false);
    });

    test('advantage uses higher die', () {
      // [7, 19] → chosen 20 ... wait nextInt=19 → face=20, already nat-20.
      // Use 14,7 → chosen 15 (not nat-20) + 3 + 2 = 20 vs AC 15 → hit.
      final res = _resolver([14, 6]).resolve(
        _input(ac: 15, adv: AdvantageState.advantage),
      );
      expect(res.hit, true);
      expect(res.isCritical, false);
      expect(res.d20Chosen, 15);
      expect(res.d20Other, 7);
    });

    test('disadvantage uses lower die', () {
      // [18, 3] → chosen 4 + 3 + 2 = 9 vs AC 15 → miss
      final res = _resolver([18, 2]).resolve(
        _input(ac: 15, adv: AdvantageState.disadvantage),
      );
      expect(res.hit, false);
      expect(res.d20Chosen, 3);
      expect(res.d20Other, 19);
    });

    test('flatBonus (e.g. bless) added to total', () {
      final res = _resolver([9]).resolve(_input(ac: 15, flat: 4));
      // 10 + 3 + 2 + 4 = 19 vs 15
      expect(res.hit, true);
      expect(res.totalRoll, 19);
    });
  });
}
