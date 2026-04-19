import 'package:dungeon_master_tool/application/dnd5e/combat/encounter_repository.dart';
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

Encounter _enc(String id) {
  final c = MonsterCombatant(
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
    id: 'g',
    instanceMaxHp: 7,
    initiativeRoll: 10,
    turnState: TurnState(speedFt: 30),
  );
  return Encounter(
    id: id,
    name: 'Test',
    combatants: [c],
    order: InitiativeOrder(combatantIds: const ['g']),
  );
}

void main() {
  group('InMemoryEncounterRepository', () {
    test('findById returns null when absent', () async {
      final r = InMemoryEncounterRepository();
      expect(await r.findById('nope'), isNull);
    });

    test('save then findById round-trips', () async {
      final r = InMemoryEncounterRepository();
      final e = _enc('e1');
      await r.save(e);
      final back = await r.findById('e1');
      expect(back, isNotNull);
      expect(back!.id, 'e1');
    });

    test('save overwrites existing entry by id', () async {
      final r = InMemoryEncounterRepository();
      await r.save(_enc('e1'));
      await r.save(_enc('e1'));
      final all = await r.listAll();
      expect(all, hasLength(1));
    });

    test('delete removes by id', () async {
      final r = InMemoryEncounterRepository();
      await r.save(_enc('e1'));
      await r.delete('e1');
      expect(await r.findById('e1'), isNull);
    });

    test('listAll returns all stored encounters', () async {
      final r = InMemoryEncounterRepository();
      await r.save(_enc('e1'));
      await r.save(_enc('e2'));
      final all = await r.listAll();
      expect(all.map((e) => e.id).toSet(), {'e1', 'e2'});
    });

    test('listAll result is unmodifiable', () async {
      final r = InMemoryEncounterRepository();
      await r.save(_enc('e1'));
      final all = await r.listAll();
      expect(() => all.add(_enc('x')), throwsUnsupportedError);
    });
  });
}
