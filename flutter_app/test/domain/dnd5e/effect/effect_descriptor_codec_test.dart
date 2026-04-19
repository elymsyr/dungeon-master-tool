import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/predicate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ctx = 'srd:test';

  // Round-trip helper — json-encode then decode to catch any non-serializable
  // values slipping through.
  EffectDescriptor rt(EffectDescriptor e) {
    final s = jsonEncode(encodeEffect(e));
    return decodeEffect(jsonDecode(s), ctx);
  }

  Predicate rtP(Predicate p) {
    final s = jsonEncode(encodePredicate(p));
    return decodePredicate(jsonDecode(s), ctx);
  }

  EffectDuration rtD(EffectDuration d) {
    final s = jsonEncode(encodeDuration(d));
    return decodeDuration(jsonDecode(s), ctx);
  }

  AcFormula rtAc(AcFormula f) {
    final s = jsonEncode(encodeAcFormula(f));
    return decodeAcFormula(jsonDecode(s), ctx);
  }

  group('Predicate codec', () {
    test('Always round-trips', () {
      final back = rtP(const Always());
      expect(back, const Always());
    });

    test('All nests predicates', () {
      final p = All([const AttackIsMelee(), const IsCritical()]);
      final back = rtP(p);
      expect(back, isA<All>());
      expect((back as All).all, [const AttackIsMelee(), const IsCritical()]);
    });

    test('Any round-trips', () {
      final p = Any([const HasAdvantage(), const AttackIsRanged()]);
      expect(rtP(p), p);
    });

    test('Not round-trips', () {
      final p = Not(const IsCritical());
      expect(rtP(p), p);
    });

    test('AttackerHasCondition round-trips content id', () {
      final p = const AttackerHasCondition('srd:blinded');
      expect(rtP(p), p);
    });

    test('TargetHasCondition round-trips', () {
      expect(rtP(const TargetHasCondition('srd:stunned')),
          const TargetHasCondition('srd:stunned'));
    });

    test('AttackUsesAbility round-trips enum via name', () {
      final encoded = encodePredicate(const AttackUsesAbility(Ability.dexterity));
      expect(encoded['ability'], 'dexterity');
      expect(rtP(const AttackUsesAbility(Ability.dexterity)),
          const AttackUsesAbility(Ability.dexterity));
    });

    test('WeaponHasProperty + DamageTypeIs round-trip', () {
      expect(rtP(const WeaponHasProperty('srd:finesse')),
          const WeaponHasProperty('srd:finesse'));
      expect(rtP(const DamageTypeIs('srd:fire')),
          const DamageTypeIs('srd:fire'));
    });

    test('EffectActive round-trips', () {
      expect(rtP(const EffectActive('bless')), const EffectActive('bless'));
    });

    test('unknown tag rejected', () {
      expect(() => decodePredicate({'t': 'bogus'}, ctx), throwsFormatException);
    });

    test('non-object rejected', () {
      expect(() => decodePredicate('nope', ctx), throwsFormatException);
    });

    test('All rejects non-array "of"', () {
      expect(() => decodePredicate({'t': 'all', 'of': 'x'}, ctx),
          throwsFormatException);
    });
  });

  group('EffectDuration codec', () {
    test('Instantaneous', () {
      expect(rtD(const Instantaneous()), const Instantaneous());
    });

    test('RoundsDuration', () {
      expect(rtD(RoundsDuration(3)), RoundsDuration(3));
    });

    test('MinutesDuration', () {
      expect(rtD(MinutesDuration(10)), MinutesDuration(10));
    });

    test('UntilRest short + long', () {
      expect(rtD(const UntilRest(RestKind.shortRest)),
          const UntilRest(RestKind.shortRest));
      expect(rtD(const UntilRest(RestKind.longRest)),
          const UntilRest(RestKind.longRest));
    });

    test('ConcentrationDuration wraps inner', () {
      final d = ConcentrationDuration(MinutesDuration(1));
      final back = rtD(d);
      expect(back, isA<ConcentrationDuration>());
      expect((back as ConcentrationDuration).max, MinutesDuration(1));
    });

    test('UntilRemoved', () {
      expect(rtD(const UntilRemoved()), const UntilRemoved());
    });

    test('unknown tag rejected', () {
      expect(() => decodeDuration({'t': 'forever'}, ctx), throwsFormatException);
    });
  });

  group('AcFormula codec', () {
    test('AcFlat', () {
      expect(rtAc(const AcFlat(17)), const AcFlat(17));
    });

    test('AcNaturalPlusDex with cap', () {
      final f = const AcNaturalPlusDex(base: 14, maxDex: 2);
      final back = rtAc(f);
      expect(back, isA<AcNaturalPlusDex>());
      expect((back as AcNaturalPlusDex).base, 14);
      expect(back.maxDex, 2);
    });

    test('AcNaturalPlusDex without cap omits maxDex', () {
      final encoded = encodeAcFormula(const AcNaturalPlusDex(base: 11));
      expect(encoded.containsKey('maxDex'), false);
      expect(rtAc(const AcNaturalPlusDex(base: 11)),
          const AcNaturalPlusDex(base: 11));
    });

    test('AcUnarmored carries ability', () {
      final back = rtAc(const AcUnarmored(Ability.wisdom));
      expect((back as AcUnarmored).ability, Ability.wisdom);
    });

    test('AcMageArmor', () {
      expect(rtAc(const AcMageArmor()), const AcMageArmor());
    });
  });

  group('EffectDescriptor codec', () {
    test('ModifyAttackRoll defaults elided on encode', () {
      final e = const ModifyAttackRoll();
      final encoded = encodeEffect(e);
      expect(encoded.keys.toSet(), {'t'});
      expect(encoded['t'], 'modifyAttackRoll');
    });

    test('ModifyAttackRoll full round-trip', () {
      final e = ModifyAttackRoll(
        when: const AttackIsRanged(),
        flatBonus: 2,
        advantage: AdvantageState.advantage,
        extraDice: DiceExpression.parse('1d6'),
        appliesTo: EffectTarget.targeted,
      );
      final back = rt(e) as ModifyAttackRoll;
      expect(back.when, const AttackIsRanged());
      expect(back.flatBonus, 2);
      expect(back.advantage, AdvantageState.advantage);
      expect(back.extraDice, DiceExpression.parse('1d6'));
      expect(back.appliesTo, EffectTarget.targeted);
    });

    test('ModifyDamageRoll with typed dice list', () {
      final e = ModifyDamageRoll(
        flatBonus: 3,
        extraDice: DiceExpression.parse('2d6'),
        extraTypedDice: [
          TypedDice(
              dice: DiceExpression.parse('1d8'),
              damageTypeId: 'srd:radiant'),
        ],
        damageTypeOverride: 'srd:force',
      );
      final back = rt(e) as ModifyDamageRoll;
      expect(back.flatBonus, 3);
      expect(back.extraDice, DiceExpression.parse('2d6'));
      expect(back.extraTypedDice.single.dice, DiceExpression.parse('1d8'));
      expect(back.extraTypedDice.single.damageTypeId, 'srd:radiant');
      expect(back.damageTypeOverride, 'srd:force');
    });

    test('ModifyDamageRoll rejects non-array extraTypedDice', () {
      expect(
          () => decodeEffect({
                't': 'modifyDamageRoll',
                'extraTypedDice': 'nope',
              }, ctx),
          throwsFormatException);
    });

    test('ModifySave round-trips + autoSucceed', () {
      final e = ModifySave(
        ability: Ability.wisdom,
        flatBonus: 1,
        advantage: AdvantageState.advantage,
        autoSucceed: true,
      );
      final back = rt(e) as ModifySave;
      expect(back.ability, Ability.wisdom);
      expect(back.flatBonus, 1);
      expect(back.advantage, AdvantageState.advantage);
      expect(back.autoSucceed, true);
      expect(back.autoFail, false);
    });

    test('ModifyAc with formula', () {
      final e = const ModifyAc(
        flat: 2,
        formula: AcNaturalPlusDex(base: 13, maxDex: 2),
      );
      final back = rt(e) as ModifyAc;
      expect(back.flat, 2);
      expect(back.formula, isA<AcNaturalPlusDex>());
    });

    test('ModifyResistances sorts ids for stable output', () {
      final e = ModifyResistances(
        kind: ResistanceKind.resistance,
        add: {'srd:fire', 'srd:acid', 'srd:cold'},
      );
      final encoded = encodeEffect(e);
      expect(encoded['add'], ['srd:acid', 'srd:cold', 'srd:fire']);
      final back = rt(e) as ModifyResistances;
      expect(back.kind, ResistanceKind.resistance);
      expect(back.add, {'srd:fire', 'srd:acid', 'srd:cold'});
    });

    test('GrantCondition with save-to-resist half on success', () {
      final e = GrantCondition(
        conditionId: 'srd:paralyzed',
        duration: ConcentrationDuration(MinutesDuration(1)),
        saveToResist: SaveSpec(
            ability: Ability.wisdom, dc: 15, halfOnSuccess: true),
      );
      final back = rt(e) as GrantCondition;
      expect(back.conditionId, 'srd:paralyzed');
      expect(back.duration, ConcentrationDuration(MinutesDuration(1)));
      expect(back.saveToResist!.ability, Ability.wisdom);
      expect(back.saveToResist!.dc, 15);
      expect(back.saveToResist!.halfOnSuccess, true);
    });

    test('GrantCondition without save', () {
      final e = GrantCondition(
        conditionId: 'srd:prone',
        duration: const UntilRemoved(),
      );
      final back = rt(e) as GrantCondition;
      expect(back.saveToResist, isNull);
    });

    test('GrantProficiency defaults level to full', () {
      final e = GrantProficiency(
        kind: ProficiencyKind.skill,
        targetId: 'srd:stealth',
      );
      final encoded = encodeEffect(e);
      expect(encoded.containsKey('level'), false);
      final back = rt(e) as GrantProficiency;
      expect(back.level, Proficiency.full);
    });

    test('GrantProficiency expertise round-trips', () {
      final e = GrantProficiency(
        kind: ProficiencyKind.skill,
        targetId: 'srd:perception',
        level: Proficiency.expertise,
      );
      final back = rt(e) as GrantProficiency;
      expect(back.level, Proficiency.expertise);
    });

    test('GrantSenseOrSpeed round-trips', () {
      final e = GrantSenseOrSpeed(kind: SenseOrSpeedKind.darkvision, value: 60);
      final back = rt(e) as GrantSenseOrSpeed;
      expect(back.kind, SenseOrSpeedKind.darkvision);
      expect(back.value, 60);
    });

    test('Heal dice + flat', () {
      final e = Heal(dice: DiceExpression.parse('2d4'), flatBonus: 2);
      final back = rt(e) as Heal;
      expect(back.dice, DiceExpression.parse('2d4'));
      expect(back.flatBonus, 2);
    });

    test('ConditionInteraction elides defaults on encode', () {
      final e = ConditionInteraction();
      final encoded = encodeEffect(e);
      expect(encoded.keys.toSet(), {'t'});
    });

    test('ConditionInteraction full round-trip + sorted saves', () {
      final e = ConditionInteraction(
        incapacitated: true,
        speedZero: true,
        autoFailSavesOf: {Ability.strength, Ability.dexterity},
        imposedAdvantageOnAttacksAgainst: true,
        attacksHaveDisadvantage: true,
        cannotTakeActions: true,
        cannotTakeReactions: true,
        grappled: true,
        restrained: true,
        invisibleToSight: true,
      );
      final encoded = encodeEffect(e);
      expect(encoded['autoFailSavesOf'], ['dexterity', 'strength']);
      final back = rt(e) as ConditionInteraction;
      expect(back.incapacitated, true);
      expect(back.speedZero, true);
      expect(back.autoFailSavesOf,
          {Ability.strength, Ability.dexterity});
      expect(back.imposedAdvantageOnAttacksAgainst, true);
      expect(back.attacksHaveDisadvantage, true);
      expect(back.cannotTakeActions, true);
      expect(back.cannotTakeReactions, true);
      expect(back.grappled, true);
      expect(back.restrained, true);
      expect(back.invisibleToSight, true);
    });

    test('CustomEffect with parameters', () {
      final e = CustomEffect(
        implementationId: 'srd:wish',
        parameters: {'flavor': 'wish', 'n': 3},
      );
      final back = rt(e) as CustomEffect;
      expect(back.implementationId, 'srd:wish');
      expect(back.parameters, {'flavor': 'wish', 'n': 3});
    });

    test('CustomEffect without parameters omits field', () {
      final e = CustomEffect(implementationId: 'srd:simple');
      final encoded = encodeEffect(e);
      expect(encoded.containsKey('parameters'), false);
    });

    test('unknown effect tag rejected with ctx prefix', () {
      expect(
        () => decodeEffect({'t': 'bogus'}, ctx),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains(ctx))),
      );
    });

    test('non-object body rejected', () {
      expect(() => decodeEffect([1, 2, 3], ctx), throwsFormatException);
    });

    test('bad dice in ModifyAttackRoll yields FormatException', () {
      expect(
          () => decodeEffect({
                't': 'modifyAttackRoll',
                'extraDice': 'not-a-dice',
              }, ctx),
          throwsFormatException);
    });
  });

  group('Predicate integration inside effects', () {
    test('nested All predicate on ModifyAttackRoll', () {
      final e = ModifyAttackRoll(
        when: All([
          const AttackIsMelee(),
          Not(const TargetHasCondition('srd:dodging')),
        ]),
        flatBonus: 1,
      );
      final back = rt(e) as ModifyAttackRoll;
      expect(back.when, isA<All>());
      final all = back.when as All;
      expect(all.all.length, 2);
      expect(all.all[0], const AttackIsMelee());
      expect(all.all[1], isA<Not>());
    });
  });
}
