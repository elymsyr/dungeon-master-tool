import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
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

SaveResolver _res(List<int> rolls) =>
    SaveResolver(D20Roller(_QueueRng(rolls)));

SaveInput _in({
  Ability ab = Ability.constitution,
  int mod = 2,
  int flat = 0,
  int dc = 15,
  AdvantageState adv = AdvantageState.normal,
  bool autoSucceed = false,
  bool autoFail = false,
}) =>
    SaveInput(
      ability: ab,
      abilityMod: mod,
      flatBonus: flat,
      dc: dc,
      advantage: adv,
      autoSucceed: autoSucceed,
      autoFail: autoFail,
    );

void main() {
  group('SaveResolver', () {
    test('pass when total >= DC', () {
      // roll 13 + mod 2 = 15 vs DC 15
      final r = _res([12]).resolve(_in(dc: 15));
      expect(r.succeeded, true);
      expect(r.resolution, SaveResolution.rolled);
      expect(r.totalRoll, 15);
    });

    test('fail when total < DC', () {
      final r = _res([5]).resolve(_in(dc: 15));
      expect(r.succeeded, false);
    });

    test('auto-fail wins over auto-succeed', () {
      final r = _res([19]).resolve(
        _in(autoSucceed: true, autoFail: true),
      );
      expect(r.resolution, SaveResolution.autoFail);
      expect(r.succeeded, false);
    });

    test('auto-fail without rolling', () {
      final r = _res([]).resolve(_in(autoFail: true));
      expect(r.resolution, SaveResolution.autoFail);
      expect(r.succeeded, false);
      expect(r.d20Chosen, 0);
    });

    test('auto-succeed without rolling', () {
      final r = _res([]).resolve(_in(autoSucceed: true));
      expect(r.resolution, SaveResolution.autoSucceed);
      expect(r.succeeded, true);
    });

    test('advantage picks higher', () {
      // [14, 3] → chosen 15 + mod 2 = 17 vs DC 15
      final r = _res([14, 2]).resolve(
        _in(dc: 15, adv: AdvantageState.advantage),
      );
      expect(r.succeeded, true);
      expect(r.d20Chosen, 15);
    });

    test('flatBonus added', () {
      // 10 + mod 2 + flat 4 = 16 vs DC 15
      final r = _res([9]).resolve(_in(dc: 15, flat: 4));
      expect(r.succeeded, true);
    });
  });
}
