import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/legendary_action.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster_action.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

StatBlock _basicStats() => StatBlock(
      sizeId: 'srd:medium',
      typeId: 'srd:humanoid',
      armorClass: 12,
      hitPoints: 11,
      abilities: AbilityScores.allTens(),
      cr: ChallengeRating.parse('1/4'),
    );

void main() {
  const ctx = 'srd:test';

  group('MonsterAction codec', () {
    test('AttackAction round-trip', () {
      final a = AttackAction(
        name: 'Scimitar',
        attackBonus: 4,
        reachFt: 5,
        damage: DiceExpression.parse('1d6+2'),
        damageTypeId: 'srd:slashing',
      );
      final back = decodeMonsterAction(encodeMonsterAction(a), ctx)
          as AttackAction;
      expect(back.name, 'Scimitar');
      expect(back.attackBonus, 4);
      expect(back.reachFt, 5);
      expect(back.damage, DiceExpression.parse('1d6+2'));
      expect(back.damageTypeId, 'srd:slashing');
    });

    test('AttackAction with ranged profile', () {
      final a = AttackAction(
        name: 'Longbow',
        attackBonus: 4,
        reachFt: 0,
        rangeNormalFt: 150,
        rangeLongFt: 600,
        damage: DiceExpression.parse('1d8+2'),
        damageTypeId: 'srd:piercing',
      );
      final back = decodeMonsterAction(encodeMonsterAction(a), ctx)
          as AttackAction;
      expect(back.rangeNormalFt, 150);
      expect(back.rangeLongFt, 600);
      expect(back.reachFt, 0);
    });

    test('MultiattackAction default name elided on encode', () {
      final a = MultiattackAction(actionNames: const ['Scimitar', 'Bite']);
      final encoded = encodeMonsterAction(a);
      expect(encoded.containsKey('name'), false);
      final back = decodeMonsterAction(encoded, ctx) as MultiattackAction;
      expect(back.name, 'Multiattack');
      expect(back.actionNames, ['Scimitar', 'Bite']);
    });

    test('MultiattackAction rejects non-array actionNames', () {
      expect(
          () => decodeMonsterAction(
              {'t': 'multiattack', 'actionNames': 'nope'}, ctx),
          throwsFormatException);
    });

    test('SaveAction with damage + half-on-save default elided', () {
      final a = SaveAction(
        name: 'Fire Breath',
        ability: Ability.dexterity,
        dc: 13,
        damage: DiceExpression.parse('4d6'),
        damageTypeId: 'srd:fire',
      );
      final encoded = encodeMonsterAction(a);
      expect(encoded.containsKey('halfOnSave'), false);
      final back = decodeMonsterAction(encoded, ctx) as SaveAction;
      expect(back.ability, Ability.dexterity);
      expect(back.dc, 13);
      expect(back.damage, DiceExpression.parse('4d6'));
      expect(back.damageTypeId, 'srd:fire');
      expect(back.halfOnSave, true);
    });

    test('SaveAction without damage + halfOnSave false round-trips', () {
      final a = SaveAction(
        name: 'Gaze',
        ability: Ability.wisdom,
        dc: 15,
        halfOnSave: false,
      );
      final back = decodeMonsterAction(encodeMonsterAction(a), ctx)
          as SaveAction;
      expect(back.damage, isNull);
      expect(back.damageTypeId, isNull);
      expect(back.halfOnSave, false);
    });

    test('SpecialAction with nested effect', () {
      final a = SpecialAction(
        name: 'Regeneration',
        effects: [Heal(dice: DiceExpression.parse('1d6'), flatBonus: 5)],
      );
      final back = decodeMonsterAction(encodeMonsterAction(a), ctx)
          as SpecialAction;
      expect(back.name, 'Regeneration');
      expect(back.effects.single, isA<Heal>());
    });

    test('SpecialAction empty effects list elided', () {
      final a = SpecialAction(name: 'Amorphous');
      final encoded = encodeMonsterAction(a);
      expect(encoded.containsKey('effects'), false);
    });

    test('unknown action tag rejected', () {
      expect(() => decodeMonsterAction({'t': 'bogus', 'name': 'x'}, ctx),
          throwsFormatException);
    });
  });

  group('LegendaryAction codec', () {
    test('default cost elided', () {
      final la = LegendaryAction(
        name: 'Detect',
        inner: SpecialAction(name: 'detect'),
      );
      final encoded = encodeLegendaryAction(la);
      expect(encoded.containsKey('cost'), false);
      final back = decodeLegendaryAction(encoded, ctx);
      expect(back.cost, 1);
      expect(back.inner, isA<SpecialAction>());
    });

    test('cost > 1 round-trips', () {
      final la = LegendaryAction(
        name: 'Tail Attack',
        cost: 2,
        inner: AttackAction(
          name: 'Tail',
          attackBonus: 10,
          damage: DiceExpression.parse('2d8+5'),
          damageTypeId: 'srd:bludgeoning',
        ),
      );
      final back = decodeLegendaryAction(encodeLegendaryAction(la), ctx);
      expect(back.cost, 2);
      expect(back.inner, isA<AttackAction>());
    });
  });

  group('StatBlock via Monster top-level codec', () {
    test('minimal monster round-trips', () {
      final m = Monster(
        id: 'srd:commoner',
        name: 'Commoner',
        stats: _basicStats(),
      );
      final back = monsterFromEntry(monsterToEntry(m));
      expect(back.id, 'srd:commoner');
      expect(back.stats.sizeId, 'srd:medium');
      expect(back.stats.typeId, 'srd:humanoid');
      expect(back.stats.armorClass, 12);
      expect(back.stats.hitPoints, 11);
      expect(back.stats.cr.canonical, '1/4');
      expect(back.stats.abilities, AbilityScores.allTens());
      expect(back.actions, isEmpty);
      expect(back.legendaryActions, isEmpty);
      expect(back.description, '');
    });

    test('speeds round-trip with hover + fly', () {
      final stats = StatBlock(
        sizeId: 'srd:large',
        typeId: 'srd:dragon',
        armorClass: 18,
        hitPoints: 200,
        speeds: const MonsterSpeeds(walk: 40, fly: 80, hover: true),
        abilities: AbilityScores(
          str: AbilityScore(23),
          dex: AbilityScore(10),
          con: AbilityScore(21),
          int_: AbilityScore(14),
          wis: AbilityScore(13),
          cha: AbilityScore(19),
        ),
        cr: ChallengeRating.parse('10'),
      );
      final mon = Monster(id: 'srd:dragon-y', name: 'Young Dragon', stats: stats);
      final back = monsterFromEntry(monsterToEntry(mon));
      expect(back.stats.speeds.walk, 40);
      expect(back.stats.speeds.fly, 80);
      expect(back.stats.speeds.hover, true);
      expect(back.stats.abilities.str.value, 23);
    });

    test('senses round-trip', () {
      final stats = StatBlock(
        sizeId: 'srd:small',
        typeId: 'srd:humanoid',
        armorClass: 13,
        hitPoints: 7,
        abilities: AbilityScores.allTens(),
        senses: const MonsterSenses(darkvision: 60, blindsight: 10),
        cr: ChallengeRating.parse('1/8'),
      );
      final m = Monster(id: 'srd:goblin', name: 'Goblin', stats: stats);
      final back = monsterFromEntry(monsterToEntry(m));
      expect(back.stats.senses.darkvision, 60);
      expect(back.stats.senses.blindsight, 10);
      expect(back.stats.senses.tremorsense, isNull);
    });

    test('empty senses omitted from encoded body', () {
      final m = Monster(
        id: 'srd:c',
        name: 'C',
        stats: _basicStats(),
      );
      final body = monsterToEntry(m).bodyJson;
      expect(body.contains('"senses"'), false);
    });

    test('saving throws + skills round-trip with sorted output', () {
      final stats = StatBlock(
        sizeId: 'srd:medium',
        typeId: 'srd:humanoid',
        armorClass: 14,
        hitPoints: 40,
        abilities: AbilityScores.allTens(),
        savingThrows: const {
          Ability.wisdom: Proficiency.full,
          Ability.charisma: Proficiency.full,
        },
        skills: const {
          'srd:stealth': Proficiency.expertise,
          'srd:perception': Proficiency.full,
        },
        cr: ChallengeRating.parse('2'),
      );
      final m = Monster(id: 'srd:priest', name: 'Priest', stats: stats);
      final back = monsterFromEntry(monsterToEntry(m));
      expect(back.stats.savingThrows[Ability.wisdom], Proficiency.full);
      expect(back.stats.savingThrows[Ability.charisma], Proficiency.full);
      expect(back.stats.skills['srd:stealth'], Proficiency.expertise);
      // Stable output: wisdom (4) after charisma (5)... Ability enum order has
      // charisma last. Sorted by enum index.
      final body = monsterToEntry(m).bodyJson;
      final wisIdx = body.indexOf('wisdom');
      final chaIdx = body.indexOf('charisma');
      expect(wisIdx < chaIdx, true);
      // Skills sorted alphabetically.
      final perIdx = body.indexOf('srd:perception');
      final steIdx = body.indexOf('srd:stealth');
      expect(perIdx < steIdx, true);
    });

    test('damage / condition immunity sets round-trip sorted', () {
      final stats = StatBlock(
        sizeId: 'srd:large',
        typeId: 'srd:undead',
        armorClass: 15,
        hitPoints: 100,
        abilities: AbilityScores.allTens(),
        damageImmunityIds: const {'srd:poison', 'srd:necrotic'},
        damageResistanceIds: const {'srd:cold', 'srd:acid'},
        conditionImmunityIds: const {'srd:charmed', 'srd:poisoned'},
        cr: ChallengeRating.parse('5'),
      );
      final m = Monster(id: 'srd:zombie', name: 'Zombie', stats: stats);
      final body = monsterToEntry(m).bodyJson;
      expect(body.contains('["srd:necrotic","srd:poison"]'), true);
      expect(body.contains('["srd:acid","srd:cold"]'), true);
      final back = monsterFromEntry(monsterToEntry(m));
      expect(back.stats.damageImmunityIds, {'srd:poison', 'srd:necrotic'});
      expect(back.stats.conditionImmunityIds,
          {'srd:charmed', 'srd:poisoned'});
    });

    test('full monster with actions + legendary round-trips', () {
      final stats = StatBlock(
        sizeId: 'srd:huge',
        typeId: 'srd:dragon',
        alignmentId: 'srd:chaotic-evil',
        armorClass: 19,
        hitPoints: 256,
        hitPointsFormula: '19d12+133',
        speeds: const MonsterSpeeds(walk: 40, fly: 80, swim: 40),
        abilities: AbilityScores(
          str: AbilityScore(27),
          dex: AbilityScore(10),
          con: AbilityScore(25),
          int_: AbilityScore(16),
          wis: AbilityScore(13),
          cha: AbilityScore(21),
        ),
        languageIds: const {'srd:draconic', 'srd:common'},
        cr: ChallengeRating.parse('17'),
      );
      final mon = Monster(
        id: 'srd:adult-red-dragon',
        name: 'Adult Red Dragon',
        stats: stats,
        traits: [GrantCondition(
          conditionId: 'srd:frightened',
          duration: const UntilRemoved(),
        )],
        actions: [
          MultiattackAction(actionNames: const ['Bite', 'Claw', 'Claw']),
          AttackAction(
            name: 'Bite',
            attackBonus: 14,
            reachFt: 10,
            damage: DiceExpression.parse('2d10+8'),
            damageTypeId: 'srd:piercing',
          ),
          SaveAction(
            name: 'Fire Breath',
            ability: Ability.dexterity,
            dc: 21,
            damage: DiceExpression.parse('18d6'),
            damageTypeId: 'srd:fire',
          ),
        ],
        legendaryActions: [
          LegendaryAction(
            name: 'Tail Attack',
            inner: AttackAction(
              name: 'Tail',
              attackBonus: 14,
              reachFt: 15,
              damage: DiceExpression.parse('2d8+8'),
              damageTypeId: 'srd:bludgeoning',
            ),
          ),
          LegendaryAction(
            name: 'Wing Attack',
            cost: 2,
            inner: SpecialAction(
              name: 'Wing Attack',
              description: 'Flap wings to dislodge attackers.',
            ),
          ),
        ],
        legendaryActionSlots: 3,
        description: 'A terror from the skies.',
      );
      final back = monsterFromEntry(monsterToEntry(mon));
      expect(back.stats.alignmentId, 'srd:chaotic-evil');
      expect(back.stats.hitPointsFormula, '19d12+133');
      expect(back.traits, hasLength(1));
      expect(back.actions, hasLength(3));
      expect(back.actions[0], isA<MultiattackAction>());
      expect(back.actions[1], isA<AttackAction>());
      expect(back.actions[2], isA<SaveAction>());
      expect(back.legendaryActions, hasLength(2));
      expect(back.legendaryActions[1].cost, 2);
      expect(back.legendaryActionSlots, 3);
      expect(back.description, 'A terror from the skies.');
      expect(back.stats.languageIds, {'srd:common', 'srd:draconic'});
    });

    test('rejects missing stats', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '{}');
      expect(() => monsterFromEntry(e), throwsFormatException);
    });

    test('rejects invalid CR', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"stats":{"sizeId":"srd:m","typeId":"srd:h","armorClass":10,"hitPoints":1,"abilities":{"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10},"cr":"bogus"}}',
      );
      expect(() => monsterFromEntry(e), throwsArgumentError);
    });

    test('rejects non-object senses', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"stats":{"sizeId":"srd:m","typeId":"srd:h","armorClass":10,"hitPoints":1,"abilities":{"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10},"cr":"0","senses":"nope"}}',
      );
      expect(() => monsterFromEntry(e), throwsFormatException);
    });
  });
}
