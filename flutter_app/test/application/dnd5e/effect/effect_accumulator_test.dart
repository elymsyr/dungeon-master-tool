import 'package:dungeon_master_tool/application/dnd5e/effect/effect_accumulator.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/effect_context.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/predicate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const acc = EffectAccumulator();

  group('accumulateAttack', () {
    test('empty list yields neutral contribution', () {
      final c = acc.accumulateAttack(const [], EffectContext());
      expect(c.flatBonus, 0);
      expect(c.advantage, AdvantageState.normal);
      expect(c.extraDice, isEmpty);
    });

    test('sums flatBonus across surviving ModifyAttackRoll entries', () {
      final list = <EffectDescriptor>[
        const ModifyAttackRoll(flatBonus: 2),
        const ModifyAttackRoll(flatBonus: 3),
        ModifyDamageRoll(flatBonus: 99),
      ];
      final c = acc.accumulateAttack(list, EffectContext());
      expect(c.flatBonus, 5);
    });

    test('combines advantage states via SRD cancellation rule', () {
      final list = <EffectDescriptor>[
        const ModifyAttackRoll(advantage: AdvantageState.advantage),
        const ModifyAttackRoll(advantage: AdvantageState.disadvantage),
      ];
      final c = acc.accumulateAttack(list, EffectContext());
      expect(c.advantage, AdvantageState.normal);
    });

    test('skips descriptors whose when: predicate is false', () {
      final list = <EffectDescriptor>[
        const ModifyAttackRoll(when: IsCritical(), flatBonus: 10),
        const ModifyAttackRoll(flatBonus: 1),
      ];
      final c = acc.accumulateAttack(list, EffectContext());
      expect(c.flatBonus, 1);
      final c2 = acc.accumulateAttack(list, EffectContext(isCritical: true));
      expect(c2.flatBonus, 11);
    });

    test('filters by appliesTo target side', () {
      final list = <EffectDescriptor>[
        const ModifyAttackRoll(flatBonus: 2),
        const ModifyAttackRoll(
          flatBonus: 5,
          appliesTo: EffectTarget.targeted,
        ),
      ];
      final atk = acc.accumulateAttack(list, EffectContext());
      expect(atk.flatBonus, 2);
      final tgt = acc.accumulateAttack(
        list,
        EffectContext(),
        appliesTo: EffectTarget.targeted,
      );
      expect(tgt.flatBonus, 5);
    });

    test('collects extraDice in iteration order', () {
      final d1 = DiceExpression.single(1, Die.d4);
      final d2 = DiceExpression.single(2, Die.d6);
      final list = <EffectDescriptor>[
        ModifyAttackRoll(extraDice: d1),
        const ModifyAttackRoll(),
        ModifyAttackRoll(extraDice: d2),
      ];
      final c = acc.accumulateAttack(list, EffectContext());
      expect(c.extraDice, [d1, d2]);
    });
  });

  group('accumulateDamage', () {
    test('empty list yields neutral contribution', () {
      final c = acc.accumulateDamage(const [], EffectContext());
      expect(c.flatBonus, 0);
      expect(c.extraDice, isEmpty);
      expect(c.extraTypedDice, isEmpty);
      expect(c.damageTypeOverride, isNull);
    });

    test('sums flatBonus + collects extraDice + extraTypedDice', () {
      final extra = DiceExpression.single(1, Die.d6);
      final typed = TypedDice(
        dice: DiceExpression.single(1, Die.d8),
        damageTypeId: 'srd:radiant',
      );
      final list = <EffectDescriptor>[
        ModifyDamageRoll(flatBonus: 2, extraDice: extra),
        ModifyDamageRoll(flatBonus: 3, extraTypedDice: [typed]),
        const ModifyAttackRoll(flatBonus: 99),
      ];
      final c = acc.accumulateDamage(list, EffectContext());
      expect(c.flatBonus, 5);
      expect(c.extraDice, [extra]);
      expect(c.extraTypedDice, [typed]);
    });

    test('damageTypeOverride is the last non-null in iteration order', () {
      final list = <EffectDescriptor>[
        ModifyDamageRoll(damageTypeOverride: 'srd:fire'),
        ModifyDamageRoll(),
        ModifyDamageRoll(damageTypeOverride: 'srd:cold'),
      ];
      final c = acc.accumulateDamage(list, EffectContext());
      expect(c.damageTypeOverride, 'srd:cold');
    });

    test('skips descriptors whose when: predicate is false', () {
      final list = <EffectDescriptor>[
        ModifyDamageRoll(when: const IsCritical(), flatBonus: 10),
        ModifyDamageRoll(flatBonus: 1),
      ];
      final c = acc.accumulateDamage(list, EffectContext());
      expect(c.flatBonus, 1);
    });
  });

  group('accumulateSave', () {
    test('empty list yields neutral contribution', () {
      final c = acc.accumulateSave(
        const [],
        EffectContext(),
        ability: Ability.dexterity,
      );
      expect(c.flatBonus, 0);
      expect(c.advantage, AdvantageState.normal);
      expect(c.autoSucceed, isFalse);
      expect(c.autoFail, isFalse);
    });

    test('matches by ability', () {
      final list = <EffectDescriptor>[
        ModifySave(ability: Ability.dexterity, flatBonus: 2),
        ModifySave(ability: Ability.strength, flatBonus: 5),
      ];
      final dex = acc.accumulateSave(
        list,
        EffectContext(),
        ability: Ability.dexterity,
      );
      expect(dex.flatBonus, 2);
      final str = acc.accumulateSave(
        list,
        EffectContext(),
        ability: Ability.strength,
      );
      expect(str.flatBonus, 5);
    });

    test('autoFail and autoSucceed both surface when present on different descriptors', () {
      final list = <EffectDescriptor>[
        ModifySave(ability: Ability.constitution, autoSucceed: true),
        ModifySave(ability: Ability.constitution, autoFail: true),
      ];
      final c = acc.accumulateSave(
        list,
        EffectContext(),
        ability: Ability.constitution,
      );
      expect(c.autoSucceed, isTrue);
      expect(c.autoFail, isTrue);
    });

    test('combines advantage states via SRD cancellation', () {
      final list = <EffectDescriptor>[
        ModifySave(
          ability: Ability.wisdom,
          advantage: AdvantageState.advantage,
        ),
        ModifySave(
          ability: Ability.wisdom,
          advantage: AdvantageState.disadvantage,
        ),
      ];
      final c = acc.accumulateSave(
        list,
        EffectContext(),
        ability: Ability.wisdom,
      );
      expect(c.advantage, AdvantageState.normal);
    });

    test('skips descriptors whose when: predicate is false', () {
      final list = <EffectDescriptor>[
        ModifySave(
          ability: Ability.dexterity,
          when: const IsCritical(),
          flatBonus: 10,
        ),
        ModifySave(ability: Ability.dexterity, flatBonus: 1),
      ];
      final c = acc.accumulateSave(
        list,
        EffectContext(),
        ability: Ability.dexterity,
      );
      expect(c.flatBonus, 1);
    });
  });

  group('non-modify descriptors are ignored across all accumulators', () {
    final list = <EffectDescriptor>[
      const Heal(flatBonus: 5),
    ];
    test('attack', () {
      expect(acc.accumulateAttack(list, EffectContext()).flatBonus, 0);
    });
    test('damage', () {
      expect(acc.accumulateDamage(list, EffectContext()).flatBonus, 0);
    });
    test('save', () {
      expect(
        acc
            .accumulateSave(list, EffectContext(), ability: Ability.charisma)
            .flatBonus,
        0,
      );
    });
  });
}
