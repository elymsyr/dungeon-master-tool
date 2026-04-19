import 'package:dungeon_master_tool/application/dnd5e/combat/condition_tick_service.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(10),
      con: AbilityScore(10),
      int_: AbilityScore(10),
      wis: AbilityScore(10),
      cha: AbilityScore(10),
    );

MonsterCombatant _mc({
  Set<String> conditions = const {},
  Map<String, int> durations = const {},
}) =>
    MonsterCombatant(
      definition: Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: StatBlock(
          sizeId: 'srd:small',
          typeId: 'srd:humanoid',
          armorClass: 13,
          hitPoints: 7,
          abilities: _abs(),
          cr: ChallengeRating.parse('1/4'),
        ),
      ),
      id: 'm',
      instanceMaxHp: 7,
      initiativeRoll: 10,
      conditionIds: conditions,
      conditionDurationsRounds: durations,
      turnState: TurnState(speedFt: 30),
    );

void main() {
  const svc = ConditionTickService();

  group('tick', () {
    test('empty durations: combatant returned unchanged, no expirations', () {
      final c = _mc();
      final r = svc.tick(c);
      expect(r.expiredConditionIds, isEmpty);
      expect(r.combatant.conditionIds, isEmpty);
      expect(r.combatant.conditionDurationsRounds, isEmpty);
    });

    test('decrements every duration by one', () {
      final c = _mc(
        conditions: const {'srd:bless', 'srd:hex'},
        durations: const {'srd:bless': 5, 'srd:hex': 10},
      );
      final r = svc.tick(c);
      expect(r.expiredConditionIds, isEmpty);
      expect(r.combatant.conditionDurationsRounds, {
        'srd:bless': 4,
        'srd:hex': 9,
      });
      expect(r.combatant.conditionIds, {'srd:bless', 'srd:hex'});
    });

    test('duration of 1 expires this tick: removed from set + map', () {
      final c = _mc(
        conditions: const {'srd:bless', 'srd:hex'},
        durations: const {'srd:bless': 1, 'srd:hex': 5},
      );
      final r = svc.tick(c);
      expect(r.expiredConditionIds, {'srd:bless'});
      expect(r.combatant.conditionIds, {'srd:hex'});
      expect(r.combatant.conditionDurationsRounds, {'srd:hex': 4});
    });

    test('open-ended conditions (no duration entry) untouched', () {
      final c = _mc(
        conditions: const {'srd:grappled', 'srd:hex'},
        durations: const {'srd:hex': 1}, // grappled has no duration
      );
      final r = svc.tick(c);
      expect(r.expiredConditionIds, {'srd:hex'});
      expect(r.combatant.conditionIds, {'srd:grappled'});
      expect(r.combatant.conditionDurationsRounds, isEmpty);
    });

    test('idempotent shape: tick on no-duration combatant returns identical', () {
      final c = _mc(conditions: const {'srd:grappled'});
      final r = svc.tick(c);
      expect(r.combatant.conditionIds, {'srd:grappled'});
      expect(r.combatant.conditionDurationsRounds, isEmpty);
    });
  });

  group('tickAll', () {
    test('processes every combatant in iteration order', () {
      final list = [
        _mc(
          conditions: const {'a:b'},
          durations: const {'a:b': 1},
        ),
        _mc(),
      ];
      final results = svc.tickAll(list);
      expect(results, hasLength(2));
      expect(results[0].expiredConditionIds, {'a:b'});
      expect(results[1].expiredConditionIds, isEmpty);
    });
  });
}
