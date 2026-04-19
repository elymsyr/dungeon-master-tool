import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/core/dice_expression.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';
import '../effect/combatant_effect_source.dart';
import '../effect/effect_accumulator.dart';
import '../effect/effect_context.dart';
import '../effect/effect_context_builder.dart';
import 'attack_roll.dart';

/// Inputs to a full attack pipeline run. Aggregates the static numbers the
/// caller already knows (ability mod, prof bonus, magic-weapon bonus) plus
/// the shape descriptors needed to build the [EffectContext].
class AttackPipelineInput {
  final Combatant attacker;
  final Combatant target;
  final int abilityMod;
  final int proficiencyBonus;
  final int weaponBonus;
  final int targetArmorClass;
  final int coverAcBonus;
  final AttackReach reach;
  final Ability? attackAbility;
  final Set<String> weaponProperties;
  final String? damageTypeId;
  final bool hasAdvantage;
  final Set<String> activeEffectIds;

  const AttackPipelineInput({
    required this.attacker,
    required this.target,
    required this.abilityMod,
    required this.proficiencyBonus,
    required this.targetArmorClass,
    this.weaponBonus = 0,
    this.coverAcBonus = 0,
    this.reach = AttackReach.melee,
    this.attackAbility,
    this.weaponProperties = const {},
    this.damageTypeId,
    this.hasAdvantage = false,
    this.activeEffectIds = const {},
  });
}

/// Full attack-roll output: the underlying [AttackRollResult] plus the two
/// [AttackContribution]s the pipeline derived for inspection (UI breakdown,
/// audit log, replay).
class AttackPipelineResult {
  final AttackRollResult roll;
  final AttackContribution attackerContribution;
  final AttackContribution targetContribution;
  final List<DiceExpression> extraAttackDice;

  AttackPipelineResult({
    required this.roll,
    required this.attackerContribution,
    required this.targetContribution,
    required List<DiceExpression> extraAttackDice,
  }) : extraAttackDice = List.unmodifiable(extraAttackDice);
}

/// Composes [CombatantEffectSource] (both sides) + [EffectAccumulator] +
/// [AttackResolver] into one call. Pure: no Combatant mutation, no repository
/// writes; the only RNG is the [AttackResolver]'s injected d20.
///
/// The pipeline does not roll the [extraAttackDice] returned in the result —
/// that's the damage step's job (e.g. Hunter's Mark riding alongside the
/// weapon damage). Surfaces them so the damage step can fold them in.
class AttackPipeline {
  final CombatantEffectSource effectSource;
  final EffectAccumulator accumulator;
  final EffectContextBuilder contextBuilder;
  final AttackResolver resolver;

  const AttackPipeline({
    required this.effectSource,
    this.accumulator = const EffectAccumulator(),
    this.contextBuilder = const EffectContextBuilder(),
    required this.resolver,
  });

  AttackPipelineResult run(AttackPipelineInput input) {
    final attackerEffects = effectSource.collect(input.attacker);
    final targetEffects = effectSource.collect(input.target);
    final ctx = contextBuilder.forAttack(
      attacker: input.attacker,
      target: input.target,
      reach: input.reach,
      attackAbility: input.attackAbility,
      weaponProperties: input.weaponProperties,
      damageTypeId: input.damageTypeId,
      hasAdvantage: input.hasAdvantage,
      activeEffectIds: input.activeEffectIds,
    );
    final atk = accumulator.accumulateAttack(attackerEffects, ctx);
    final tgt = accumulator.accumulateAttack(
      targetEffects,
      ctx,
      appliesTo: EffectTarget.targeted,
    );
    final flatBonus = input.weaponBonus + atk.flatBonus + tgt.flatBonus;
    final advantage = atk.advantage.combine(tgt.advantage);
    final rollInput = AttackRollInput(
      abilityMod: input.abilityMod,
      proficiencyBonus: input.proficiencyBonus,
      targetArmorClass: input.targetArmorClass,
      flatBonus: flatBonus,
      advantage: advantage,
      coverAcBonus: input.coverAcBonus,
    );
    final result = resolver.resolve(rollInput);
    return AttackPipelineResult(
      roll: result,
      attackerContribution: atk,
      targetContribution: tgt,
      extraAttackDice: [...atk.extraDice, ...tgt.extraDice],
    );
  }
}
