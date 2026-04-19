import 'package:dungeon_master_tool/application/dnd5e/effect/effect_context.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/predicate_evaluator.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/predicate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eval = PredicateEvaluator();

  group('atoms', () {
    test('Always is always true', () {
      expect(eval.evaluate(const Always(), EffectContext()), isTrue);
    });

    test('IsCritical reads ctx.isCritical', () {
      expect(eval.evaluate(const IsCritical(), EffectContext()), isFalse);
      expect(
        eval.evaluate(const IsCritical(), EffectContext(isCritical: true)),
        isTrue,
      );
    });

    test('HasAdvantage reads ctx.hasAdvantage', () {
      expect(eval.evaluate(const HasAdvantage(), EffectContext()), isFalse);
      expect(
        eval.evaluate(const HasAdvantage(), EffectContext(hasAdvantage: true)),
        isTrue,
      );
    });
  });

  group('combinators', () {
    test('Not flips inner', () {
      expect(eval.evaluate(const Not(Always()), EffectContext()), isFalse);
      expect(
        eval.evaluate(Not(const IsCritical()), EffectContext()),
        isTrue,
      );
    });

    test('All requires every child to hold', () {
      final p = All([const Always(), const IsCritical()]);
      expect(eval.evaluate(p, EffectContext(isCritical: true)), isTrue);
      expect(eval.evaluate(p, EffectContext()), isFalse);
    });

    test('All on empty list is vacuously true', () {
      expect(eval.evaluate(All(const []), EffectContext()), isTrue);
    });

    test('Any holds when at least one child holds', () {
      final p = Any([const IsCritical(), const HasAdvantage()]);
      expect(eval.evaluate(p, EffectContext(hasAdvantage: true)), isTrue);
      expect(eval.evaluate(p, EffectContext()), isFalse);
    });

    test('Any on empty list is false', () {
      expect(eval.evaluate(Any(const []), EffectContext()), isFalse);
    });

    test('nested combinators evaluate recursively', () {
      // (IsCritical AND NOT HasAdvantage) OR Always-false-via-Not(Always)
      final p = Any([
        All([const IsCritical(), const Not(HasAdvantage())]),
        const Not(Always()),
      ]);
      expect(
        eval.evaluate(p, EffectContext(isCritical: true)),
        isTrue,
      );
      expect(
        eval.evaluate(
          p,
          EffectContext(isCritical: true, hasAdvantage: true),
        ),
        isFalse,
      );
    });
  });

  group('attacker / target conditions', () {
    test('AttackerHasCondition matches by id', () {
      expect(
        eval.evaluate(
          const AttackerHasCondition('srd:blessed'),
          EffectContext(attackerConditions: const {'srd:blessed'}),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const AttackerHasCondition('srd:blessed'),
          EffectContext(attackerConditions: const {'srd:poisoned'}),
        ),
        isFalse,
      );
    });

    test('TargetHasCondition does not match attacker conditions', () {
      expect(
        eval.evaluate(
          const TargetHasCondition('srd:prone'),
          EffectContext(attackerConditions: const {'srd:prone'}),
        ),
        isFalse,
      );
      expect(
        eval.evaluate(
          const TargetHasCondition('srd:prone'),
          EffectContext(targetConditions: const {'srd:prone'}),
        ),
        isTrue,
      );
    });
  });

  group('attack-shape predicates', () {
    test('AttackIsMelee true only when reach is melee', () {
      expect(
        eval.evaluate(
          const AttackIsMelee(),
          EffectContext(attackReach: AttackReach.melee),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const AttackIsMelee(),
          EffectContext(attackReach: AttackReach.ranged),
        ),
        isFalse,
      );
      expect(
        eval.evaluate(const AttackIsMelee(), EffectContext()),
        isFalse,
      );
    });

    test('AttackIsRanged true only when reach is ranged', () {
      expect(
        eval.evaluate(
          const AttackIsRanged(),
          EffectContext(attackReach: AttackReach.ranged),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const AttackIsRanged(),
          EffectContext(attackReach: AttackReach.melee),
        ),
        isFalse,
      );
    });

    test('AttackUsesAbility matches Ability', () {
      expect(
        eval.evaluate(
          const AttackUsesAbility(Ability.dexterity),
          EffectContext(attackAbility: Ability.dexterity),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const AttackUsesAbility(Ability.dexterity),
          EffectContext(attackAbility: Ability.strength),
        ),
        isFalse,
      );
      expect(
        eval.evaluate(
          const AttackUsesAbility(Ability.dexterity),
          EffectContext(),
        ),
        isFalse,
      );
    });
  });

  group('weapon / damage / effect predicates', () {
    test('WeaponHasProperty matches by namespaced id', () {
      expect(
        eval.evaluate(
          const WeaponHasProperty('srd:finesse'),
          EffectContext(weaponProperties: const {'srd:finesse'}),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const WeaponHasProperty('srd:finesse'),
          EffectContext(weaponProperties: const {'srd:heavy'}),
        ),
        isFalse,
      );
    });

    test('DamageTypeIs matches by namespaced id', () {
      expect(
        eval.evaluate(
          const DamageTypeIs('srd:fire'),
          EffectContext(damageTypeId: 'srd:fire'),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const DamageTypeIs('srd:fire'),
          EffectContext(damageTypeId: 'srd:cold'),
        ),
        isFalse,
      );
      expect(
        eval.evaluate(const DamageTypeIs('srd:fire'), EffectContext()),
        isFalse,
      );
    });

    test('EffectActive matches by raw id', () {
      expect(
        eval.evaluate(
          const EffectActive('srd:bless#combatant42'),
          EffectContext(activeEffectIds: const {'srd:bless#combatant42'}),
        ),
        isTrue,
      );
      expect(
        eval.evaluate(
          const EffectActive('srd:bless#combatant42'),
          EffectContext(activeEffectIds: const {'srd:bane#combatant42'}),
        ),
        isFalse,
      );
    });
  });
}
