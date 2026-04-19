import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/predicate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Predicate equality', () {
    test('singletons equal by type', () {
      expect(const Always(), const Always());
      expect(const AttackIsMelee(), const AttackIsMelee());
      expect(const AttackIsRanged(), const AttackIsRanged());
      expect(const IsCritical(), const IsCritical());
      expect(const HasAdvantage(), const HasAdvantage());
    });

    test('parameterised predicates equal by field', () {
      expect(const AttackerHasCondition('srd:stunned'),
          const AttackerHasCondition('srd:stunned'));
      expect(const TargetHasCondition('srd:prone'),
          const TargetHasCondition('srd:prone'));
      expect(const AttackUsesAbility(Ability.strength),
          const AttackUsesAbility(Ability.strength));
      expect(const WeaponHasProperty('srd:finesse'),
          const WeaponHasProperty('srd:finesse'));
      expect(const DamageTypeIs('srd:fire'), const DamageTypeIs('srd:fire'));
      expect(const EffectActive('srd:rage'), const EffectActive('srd:rage'));
    });

    test('different condition ids are not equal', () {
      expect(
          const TargetHasCondition('srd:prone') ==
              const TargetHasCondition('srd:stunned'),
          isFalse);
    });
  });

  group('Predicate composition', () {
    test('All and Any preserve order in equality', () {
      final a = All([const Always(), const IsCritical()]);
      final b = All([const Always(), const IsCritical()]);
      final c = All([const IsCritical(), const Always()]);
      expect(a, b);
      expect(a == c, isFalse);
    });

    test('Not wraps any predicate', () {
      expect(const Not(Always()), const Not(Always()));
      expect(const Not(IsCritical()) == const Not(HasAdvantage()), isFalse);
    });

    test('nested compositions equal structurally', () {
      final nested = All([
        const Always(),
        Any([const AttackIsMelee(), const AttackIsRanged()]),
      ]);
      final same = All([
        const Always(),
        Any([const AttackIsMelee(), const AttackIsRanged()]),
      ]);
      expect(nested, same);
    });
  });
}
