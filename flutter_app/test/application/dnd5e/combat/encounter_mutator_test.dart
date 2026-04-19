import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_mutator.dart';
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
  const m = EncounterMutator();

  group('replaceCombatant', () {
    test('swaps the matching combatant; round/order/id/name preserved', () {
      final e = _enc([_mc('a'), _mc('b'), _mc('c')]);
      final updated = _mc('b', hp: 2);
      final next = m.replaceCombatant(e, updated);
      expect(next.id, e.id);
      expect(next.name, e.name);
      expect(next.round, e.round);
      expect(next.order, e.order);
      expect(next.byId('b')!.currentHp, 2);
      expect(next.byId('a')!.currentHp, 7);
      expect(next.byId('c')!.currentHp, 7);
    });

    test('unknown id throws StateError', () {
      final e = _enc([_mc('a')]);
      expect(() => m.replaceCombatant(e, _mc('zzz')),
          throwsA(isA<StateError>()));
    });

    test('returns a new instance, not the original', () {
      final e = _enc([_mc('a')]);
      final updated = _mc('a', hp: 0);
      final next = m.replaceCombatant(e, updated);
      expect(identical(next, e), isFalse);
    });
  });

  group('replaceAll', () {
    test('bulk swap preserves order/round/id/name', () {
      final e = _enc([_mc('a'), _mc('b')]);
      final next = m.replaceAll(e, [_mc('a', hp: 1), _mc('b', hp: 2)]);
      expect(next.byId('a')!.currentHp, 1);
      expect(next.byId('b')!.currentHp, 2);
      expect(next.order, e.order);
    });

    test('dropping a combatant referenced by order throws ArgumentError', () {
      final e = _enc([_mc('a'), _mc('b')]);
      // 'b' missing from the new list; order still references it.
      expect(() => m.replaceAll(e, [_mc('a')]), throwsArgumentError);
    });
  });
}
