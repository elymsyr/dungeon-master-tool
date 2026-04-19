import 'package:dungeon_master_tool/application/dnd5e/combat/turn_rotation_service.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/encounter.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/initiative.dart';
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

MonsterCombatant _mc(String id, {int hp = 7}) => MonsterCombatant(
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
      id: id,
      instanceMaxHp: 7,
      instanceCurrentHp: hp,
      initiativeRoll: 10,
      turnState: TurnState(speedFt: 30),
    );

Encounter _enc(List<MonsterCombatant> cs) => Encounter(
      id: 'e1',
      name: 'Test',
      combatants: cs,
      order: InitiativeOrder(combatantIds: [for (final c in cs) c.id]),
    );

void main() {
  group('TurnRotationService.advance', () {
    test('default skip: 0-hp combatant skipped over', () {
      const svc = TurnRotationService();
      final e = _enc([_mc('a'), _mc('b', hp: 0), _mc('c')]);
      // active = a (index 0). Advance → b (skip, hp=0) → c.
      final next = svc.advance(e);
      expect(next.order.currentId, 'c');
    });

    test('round increments only when wrapping past last combatant', () {
      const svc = TurnRotationService();
      final e = _enc([_mc('a'), _mc('b'), _mc('c')]);
      final after1 = svc.advance(e); // a → b
      expect(after1.round, 1);
      expect(after1.order.currentId, 'b');
      final after2 = svc.advance(after1); // b → c
      expect(after2.round, 1);
      expect(after2.order.currentId, 'c');
      final after3 = svc.advance(after2); // c → a (wrap)
      expect(after3.round, 2);
      expect(after3.order.currentId, 'a');
    });

    test('all dead → returns single-step advance (no infinite loop)', () {
      const svc = TurnRotationService();
      final e = _enc([
        _mc('a', hp: 0),
        _mc('b', hp: 0),
        _mc('c', hp: 0),
      ]);
      final next = svc.advance(e);
      // Single advance from index 0 → index 1; round unchanged.
      expect(next.order.currentId, 'b');
      expect(next.round, 1);
    });

    test('custom predicate (skip incapacitated id)', () {
      final svc = TurnRotationService(
        skip: (c) => c.id == 'b',
      );
      final e = _enc([_mc('a'), _mc('b'), _mc('c')]);
      final next = svc.advance(e); // a → b (skip) → c
      expect(next.order.currentId, 'c');
    });

    test('skip wraps round when last alive sits before active', () {
      const svc = TurnRotationService();
      final e = _enc([
        _mc('a'),
        _mc('b', hp: 0),
        _mc('c', hp: 0),
      ]);
      // active = a. advance → b (skip) → c (skip) → a (wrap, alive).
      final next = svc.advance(e);
      expect(next.order.currentId, 'a');
      expect(next.round, 2);
    });
  });
}
