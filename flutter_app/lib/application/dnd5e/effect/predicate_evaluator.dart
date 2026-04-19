import '../../../domain/dnd5e/effect/predicate.dart';
import 'effect_context.dart';

/// Pure recursive evaluator for the sealed [Predicate] family. No registry
/// lookups, no I/O. The caller flattens live state into [EffectContext].
class PredicateEvaluator {
  const PredicateEvaluator();

  bool evaluate(Predicate p, EffectContext ctx) {
    return switch (p) {
      Always() => true,
      All(:final all) => all.every((q) => evaluate(q, ctx)),
      Any(:final any) => any.any((q) => evaluate(q, ctx)),
      Not(:final p) => !evaluate(p, ctx),
      AttackerHasCondition(:final id) => ctx.attackerConditions.contains(id),
      TargetHasCondition(:final id) => ctx.targetConditions.contains(id),
      AttackIsMelee() => ctx.attackReach == AttackReach.melee,
      AttackIsRanged() => ctx.attackReach == AttackReach.ranged,
      AttackUsesAbility(:final ability) => ctx.attackAbility == ability,
      WeaponHasProperty(:final id) => ctx.weaponProperties.contains(id),
      DamageTypeIs(:final id) => ctx.damageTypeId == id,
      IsCritical() => ctx.isCritical,
      HasAdvantage() => ctx.hasAdvantage,
      EffectActive(:final effectId) => ctx.activeEffectIds.contains(effectId),
    };
  }
}
