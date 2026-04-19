import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/predicate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypedDice', () {
    test('validates damage type id shape', () {
      expect(
          () => TypedDice(
                dice: DiceExpression.parse('1d6'),
                damageTypeId: 'fire',
              ),
          throwsArgumentError);
    });

    test('equal by fields', () {
      final a = TypedDice(
          dice: DiceExpression.parse('1d6'), damageTypeId: 'srd:fire');
      final b = TypedDice(
          dice: DiceExpression.parse('1d6'), damageTypeId: 'srd:fire');
      expect(a, b);
    });
  });

  group('SaveSpec', () {
    test('dc >= 0', () {
      expect(() => SaveSpec(ability: Ability.dexterity, dc: -1),
          throwsArgumentError);
    });
    test('equality by field', () {
      expect(
        SaveSpec(ability: Ability.wisdom, dc: 15, halfOnSuccess: true),
        SaveSpec(ability: Ability.wisdom, dc: 15, halfOnSuccess: true),
      );
    });
  });

  group('ModifyDamageRoll', () {
    test('validates override id', () {
      expect(
          () => ModifyDamageRoll(damageTypeOverride: 'fire'),
          throwsArgumentError);
    });
    test('extraTypedDice is unmodifiable', () {
      final m = ModifyDamageRoll(extraTypedDice: [
        TypedDice(
            dice: DiceExpression.parse('1d6'), damageTypeId: 'srd:fire'),
      ]);
      expect(() => m.extraTypedDice.add(m.extraTypedDice.first),
          throwsA(isA<Error>()));
    });
  });

  group('ModifySave', () {
    test('autoSucceed + autoFail rejected', () {
      expect(
          () => ModifySave(
                ability: Ability.dexterity,
                autoSucceed: true,
                autoFail: true,
              ),
          throwsArgumentError);
    });
  });

  group('ModifyResistances', () {
    test('validates ids in add/remove', () {
      expect(
          () => ModifyResistances(
                kind: ResistanceKind.resistance,
                add: {'fire'},
              ),
          throwsArgumentError);
    });
  });

  group('GrantCondition', () {
    test('validates conditionId', () {
      expect(
          () => GrantCondition(
                conditionId: 'stunned',
                duration: const Instantaneous(),
              ),
          throwsArgumentError);
    });
    test('happy path', () {
      final g = GrantCondition(
        conditionId: 'srd:stunned',
        duration: RoundsDuration(1),
        saveToResist: SaveSpec(ability: Ability.constitution, dc: 14),
      );
      expect(g.conditionId, 'srd:stunned');
      expect(g.duration, RoundsDuration(1));
      expect(g.saveToResist?.dc, 14);
    });
  });

  group('GrantProficiency', () {
    test('save targetId can be ability short code', () {
      final gp = GrantProficiency(
          kind: ProficiencyKind.save, targetId: 'DEX');
      expect(gp.targetId, 'DEX');
    });
    test('skill targetId must be namespaced', () {
      expect(
          () => GrantProficiency(
              kind: ProficiencyKind.skill, targetId: 'athletics'),
          throwsArgumentError);
    });
    test('default level full', () {
      final gp = GrantProficiency(
          kind: ProficiencyKind.tool, targetId: 'srd:thieves_tools');
      expect(gp.level, Proficiency.full);
    });
  });

  group('GrantSenseOrSpeed', () {
    test('value >= 0', () {
      expect(
          () => GrantSenseOrSpeed(
              kind: SenseOrSpeedKind.darkvision, value: -1),
          throwsArgumentError);
    });
  });

  group('ConditionInteraction', () {
    test('autoFailSavesOf is unmodifiable', () {
      final ci = ConditionInteraction(
        autoFailSavesOf: {Ability.strength, Ability.dexterity},
      );
      expect(() => ci.autoFailSavesOf.add(Ability.wisdom),
          throwsA(isA<Error>()));
    });
    test('defaults all false', () {
      final ci = ConditionInteraction();
      expect(ci.incapacitated, isFalse);
      expect(ci.speedZero, isFalse);
      expect(ci.autoFailSavesOf, isEmpty);
    });
  });

  group('CustomEffect', () {
    test('rejects empty implementationId', () {
      expect(
          () => CustomEffect(implementationId: ''), throwsArgumentError);
    });
    test('requires namespaced implementationId', () {
      expect(
          () => CustomEffect(implementationId: 'wish'), throwsArgumentError);
    });
    test('parameters is unmodifiable', () {
      final ce = CustomEffect(
        implementationId: 'srd:wish',
        parameters: {'foo': 1},
      );
      expect(() => ce.parameters['bar'] = 2, throwsA(isA<Error>()));
    });
  });

  group('AcFormula', () {
    test('AcFlat equality', () {
      expect(const AcFlat(13), const AcFlat(13));
      expect(const AcFlat(13) == const AcFlat(14), isFalse);
    });
    test('AcUnarmored equality', () {
      expect(const AcUnarmored(Ability.wisdom),
          const AcUnarmored(Ability.wisdom));
    });
    test('AcMageArmor singleton-equal', () {
      expect(const AcMageArmor(), const AcMageArmor());
    });
  });

  test('ModifyAttackRoll default construction', () {
    const m = ModifyAttackRoll();
    expect(m.when, const Always());
    expect(m.flatBonus, 0);
    expect(m.appliesTo, EffectTarget.attacker);
  });
}
