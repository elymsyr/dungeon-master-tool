import '../../../domain/dnd5e/catalog/content_reference.dart';
import '../../../domain/dnd5e/catalog/damage_type.dart';
import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../../../domain/dnd5e/core/dice_expression.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';
import 'effect_context.dart';
import 'predicate_evaluator.dart';

/// Reduced [ModifyAttackRoll] bag for one attack-roll computation. Caller
/// folds these into [AttackRollInput.flatBonus] / `.advantage` and rolls
/// [extraDice] alongside weapon damage if attack-side dice (e.g. Sneak Attack)
/// are wired into the damage step.
class AttackContribution {
  final int flatBonus;
  final AdvantageState advantage;
  final List<DiceExpression> extraDice;

  AttackContribution({
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    List<DiceExpression> extraDice = const [],
  }) : extraDice = List.unmodifiable(extraDice);
}

/// Reduced [ModifyDamageRoll] bag for one damage roll. [damageTypeOverride]
/// is the *last* non-null override seen in iteration order — content authors
/// who care about determinism should order their lists accordingly.
class DamageContribution {
  final int flatBonus;
  final List<DiceExpression> extraDice;
  final List<TypedDice> extraTypedDice;
  final ContentReference<DamageType>? damageTypeOverride;

  DamageContribution({
    this.flatBonus = 0,
    List<DiceExpression> extraDice = const [],
    List<TypedDice> extraTypedDice = const [],
    this.damageTypeOverride,
  })  : extraDice = List.unmodifiable(extraDice),
        extraTypedDice = List.unmodifiable(extraTypedDice);
}

/// Reduced [ModifySave] bag for one ability's save. Auto-fail / auto-succeed
/// flags are *both* surfaced; precedence is the resolver's job
/// ([SaveResolver] picks autoFail over autoSucceed).
class SaveContribution {
  final int flatBonus;
  final AdvantageState advantage;
  final bool autoSucceed;
  final bool autoFail;

  const SaveContribution({
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    this.autoSucceed = false,
    this.autoFail = false,
  });
}

/// Pure reducer over a list of [EffectDescriptor]. Filters Modify* descriptors
/// by their `when:` predicate (via [PredicateEvaluator]) plus shape-specific
/// matchers (target side, save ability) and folds the survivors into one of
/// the three contribution structs above. Non-modify descriptors
/// ([GrantCondition], [Heal], [GrantProficiency], …) are out of scope here —
/// they are dispatched at different points in the combat lifecycle.
class EffectAccumulator {
  final PredicateEvaluator evaluator;

  const EffectAccumulator([this.evaluator = const PredicateEvaluator()]);

  AttackContribution accumulateAttack(
    Iterable<EffectDescriptor> descriptors,
    EffectContext ctx, {
    EffectTarget appliesTo = EffectTarget.attacker,
  }) {
    var flat = 0;
    var adv = AdvantageState.normal;
    final extra = <DiceExpression>[];
    for (final d in descriptors) {
      if (d is! ModifyAttackRoll) continue;
      if (d.appliesTo != appliesTo) continue;
      if (!evaluator.evaluate(d.when, ctx)) continue;
      flat += d.flatBonus;
      adv = adv.combine(d.advantage);
      if (d.extraDice != null) extra.add(d.extraDice!);
    }
    return AttackContribution(
      flatBonus: flat,
      advantage: adv,
      extraDice: extra,
    );
  }

  DamageContribution accumulateDamage(
    Iterable<EffectDescriptor> descriptors,
    EffectContext ctx,
  ) {
    var flat = 0;
    final extra = <DiceExpression>[];
    final typed = <TypedDice>[];
    ContentReference<DamageType>? override;
    for (final d in descriptors) {
      if (d is! ModifyDamageRoll) continue;
      if (!evaluator.evaluate(d.when, ctx)) continue;
      flat += d.flatBonus;
      if (d.extraDice != null) extra.add(d.extraDice!);
      typed.addAll(d.extraTypedDice);
      if (d.damageTypeOverride != null) override = d.damageTypeOverride;
    }
    return DamageContribution(
      flatBonus: flat,
      extraDice: extra,
      extraTypedDice: typed,
      damageTypeOverride: override,
    );
  }

  SaveContribution accumulateSave(
    Iterable<EffectDescriptor> descriptors,
    EffectContext ctx, {
    required Ability ability,
  }) {
    var flat = 0;
    var adv = AdvantageState.normal;
    var autoSucceed = false;
    var autoFail = false;
    for (final d in descriptors) {
      if (d is! ModifySave) continue;
      if (d.ability != ability) continue;
      if (!evaluator.evaluate(d.when, ctx)) continue;
      flat += d.flatBonus;
      adv = adv.combine(d.advantage);
      if (d.autoSucceed) autoSucceed = true;
      if (d.autoFail) autoFail = true;
    }
    return SaveContribution(
      flatBonus: flat,
      advantage: adv,
      autoSucceed: autoSucceed,
      autoFail: autoFail,
    );
  }
}
