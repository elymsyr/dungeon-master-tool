import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(14),
      con: AbilityScore(12),
      int_: AbilityScore(10),
      wis: AbilityScore(12),
      cha: AbilityScore(10),
    );

Character _character() => Character(
      id: 'pc-1',
      name: 'Aria',
      classLevels: [CharacterClassLevel(classId: 'srd:wizard', level: 3)],
      speciesId: 'srd:human',
      backgroundId: 'srd:sage',
      alignmentId: 'srd:neutral',
      abilities: _abs(),
      hp: HitPoints(current: 18, max: 20),
    );

Monster _monster() => Monster(
      id: 'srd:goblin',
      name: 'Goblin',
      stats: StatBlock(
        sizeId: 'srd:small',
        typeId: 'srd:humanoid',
        armorClass: 15,
        hitPoints: 7,
        abilities: _abs(),
        cr: ChallengeRating.parse('1/4'),
      ),
    );

PlayerCombatant _pc() => PlayerCombatant(
      character: _character(),
      initiativeRoll: 12,
      turnState: TurnState(speedFt: 30),
    );

MonsterCombatant _mc() => MonsterCombatant(
      definition: _monster(),
      id: 'goblin#1',
      instanceMaxHp: 7,
      initiativeRoll: 8,
      turnState: TurnState(speedFt: 30),
    );

void main() {
  group('PlayerCombatant.copyWith', () {
    test('no overrides preserves all fields', () {
      final a = _pc();
      final b = a.copyWith();
      expect(b.character, a.character);
      expect(b.initiativeRoll, a.initiativeRoll);
      expect(b.conditionIds, a.conditionIds);
      expect(b.conditionDurationsRounds, a.conditionDurationsRounds);
      expect(b.concentration, a.concentration);
      expect(b.turnState, a.turnState);
      expect(b.mapPosition, a.mapPosition);
    });

    test('override individual fields', () {
      final a = _pc();
      final newTurn = TurnState(speedFt: 25);
      final b = a.copyWith(
        initiativeRoll: 20,
        conditionIds: const {'srd:blessed'},
        conditionDurationsRounds: const {'srd:blessed': 10},
        turnState: newTurn,
        mapPosition: const TokenPosition(5, 10),
      );
      expect(b.initiativeRoll, 20);
      expect(b.conditionIds, {'srd:blessed'});
      expect(b.conditionDurationsRounds, {'srd:blessed': 10});
      expect(b.turnState, newTurn);
      expect(b.mapPosition, const TokenPosition(5, 10));
      expect(b.character, a.character);
    });

    test('replacing character delegates HP through new character', () {
      final a = _pc();
      final newChar = _character().copyWith(hp: HitPoints(current: 5, max: 20));
      final b = a.copyWith(character: newChar);
      expect(b.currentHp, 5);
      expect(b.maxHp, 20);
      expect(a.currentHp, 18); // original untouched
    });

    test('concentration: set, then clearConcentration nulls it', () {
      final a = _pc();
      final conc = Concentration(
        spellId: 'srd:bless',
        castAtLevel: SpellLevel(1),
      );
      final b = a.copyWith(concentration: conc);
      expect(b.concentration, conc);
      final c = b.copyWith(clearConcentration: true);
      expect(c.concentration, isNull);
    });

    test('clearMapPosition nulls a previously-set position', () {
      final a = _pc().copyWith(mapPosition: const TokenPosition(1, 2));
      expect(a.mapPosition, const TokenPosition(1, 2));
      final b = a.copyWith(clearMapPosition: true);
      expect(b.mapPosition, isNull);
    });

    test('clearConcentration ignores non-null concentration param', () {
      final a = _pc().copyWith(
        concentration: Concentration(
          spellId: 'srd:bless',
          castAtLevel: SpellLevel(1),
        ),
      );
      final newConc = Concentration(
        spellId: 'srd:bane',
        castAtLevel: SpellLevel(1),
      );
      final b = a.copyWith(
        concentration: newConc,
        clearConcentration: true,
      );
      expect(b.concentration, isNull);
    });

    test('result is a new immutable instance, not mutation of original', () {
      final a = _pc();
      final b = a.copyWith(initiativeRoll: 99);
      expect(identical(a, b), isFalse);
      expect(a.initiativeRoll, 12);
      expect(b.initiativeRoll, 99);
    });
  });

  group('MonsterCombatant.copyWith', () {
    test('no overrides preserves all fields', () {
      final a = _mc();
      final b = a.copyWith();
      expect(b.definition, a.definition);
      expect(b.id, a.id);
      expect(b.instanceMaxHp, a.instanceMaxHp);
      expect(b.instanceCurrentHp, a.instanceCurrentHp);
      expect(b.initiativeRoll, a.initiativeRoll);
      expect(b.conditionIds, a.conditionIds);
      expect(b.conditionDurationsRounds, a.conditionDurationsRounds);
      expect(b.concentration, a.concentration);
      expect(b.turnState, a.turnState);
      expect(b.mapPosition, a.mapPosition);
    });

    test('decrement instanceCurrentHp', () {
      final a = _mc();
      final b = a.copyWith(instanceCurrentHp: 3);
      expect(b.instanceCurrentHp, 3);
      expect(b.instanceMaxHp, 7);
      expect(a.instanceCurrentHp, 7); // unchanged
    });

    test('definition cannot be replaced via copyWith (no param)', () {
      final a = _mc();
      final b = a.copyWith(initiativeRoll: 99);
      expect(identical(b.definition, a.definition), isTrue);
      expect(b.id, a.id);
    });

    test('factory validation still runs: rejects out-of-range HP', () {
      final a = _mc();
      expect(() => a.copyWith(instanceCurrentHp: -1), throwsArgumentError);
      expect(() => a.copyWith(instanceCurrentHp: 999), throwsArgumentError);
    });

    test('override conditions and turnState', () {
      final a = _mc();
      final newTurn = TurnState(speedFt: 20);
      final b = a.copyWith(
        conditionIds: const {'srd:prone'},
        conditionDurationsRounds: const {'srd:prone': 1},
        turnState: newTurn,
      );
      expect(b.conditionIds, {'srd:prone'});
      expect(b.conditionDurationsRounds, {'srd:prone': 1});
      expect(b.turnState, newTurn);
    });

    test('clearConcentration / clearMapPosition behave like PlayerCombatant', () {
      final a = _mc().copyWith(
        concentration: Concentration(
          spellId: 'srd:hold-person',
          castAtLevel: SpellLevel(2),
        ),
        mapPosition: const TokenPosition(3, 4),
      );
      final b = a.copyWith(
        clearConcentration: true,
        clearMapPosition: true,
      );
      expect(b.concentration, isNull);
      expect(b.mapPosition, isNull);
    });

    test('result is a new immutable instance', () {
      final a = _mc();
      final b = a.copyWith(initiativeRoll: 1);
      expect(identical(a, b), isFalse);
      expect(a.initiativeRoll, 8);
      expect(b.initiativeRoll, 1);
    });
  });
}
