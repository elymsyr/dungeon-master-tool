import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/combat/concentration.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../effect/combatant_effect_source.dart';
import '../effect/effect_accumulator.dart';
import '../effect/effect_context_builder.dart';
import 'apply_damage_outcome.dart';
import 'apply_damage_pipeline.dart';
import 'damage_instance.dart';
import 'target_defenses.dart';

/// Inputs for one damage-pipeline run. The caller has already rolled the base
/// weapon/spell damage and built the [TargetDefenses] view; the pipeline folds
/// in attacker-side `ModifyDamageRoll` flat bonuses plus any damage-type
/// override before delegating to [ApplyDamagePipeline].
class DamagePipelineInput {
  final Combatant attacker;
  final Combatant target;
  final TargetDefenses defenses;
  final DamageInstance baseDamage;
  final Concentration? concentration;
  final int conMod;
  final int saveProfBonus;
  final AdvantageState saveAdvantage;
  final bool autoSucceedSave;
  final bool autoFailSave;

  const DamagePipelineInput({
    required this.attacker,
    required this.target,
    required this.defenses,
    required this.baseDamage,
    this.concentration,
    this.conMod = 0,
    this.saveProfBonus = 0,
    this.saveAdvantage = AdvantageState.normal,
    this.autoSucceedSave = false,
    this.autoFailSave = false,
  });
}

class DamagePipelineResult {
  final ApplyDamageOutcome outcome;
  final DamageContribution contribution;
  final DamageInstance modifiedDamage;

  const DamagePipelineResult({
    required this.outcome,
    required this.contribution,
    required this.modifiedDamage,
  });
}

/// Composes [CombatantEffectSource] + [EffectAccumulator] (damage side) +
/// [ApplyDamagePipeline]. Pure: no Combatant mutation, no repository writes;
/// the only RNG is the concentration save's d20 inside [ApplyDamagePipeline].
///
/// Scope today: attacker-side `ModifyDamageRoll` only. The pipeline folds
/// `flatBonus` into the base damage and applies `damageTypeOverride` (last
/// non-null wins, by [EffectAccumulator] contract). Extra dice (`extraDice` /
/// `extraTypedDice`) are surfaced via [DamagePipelineResult.contribution] but
/// not rolled — the caller rolls them and runs additional pipeline calls per
/// extra type so resistances are applied per-type per Doc 11 §Multi-Type.
class DamagePipeline {
  final CombatantEffectSource effectSource;
  final EffectAccumulator accumulator;
  final EffectContextBuilder contextBuilder;
  final ApplyDamagePipeline applyPipeline;

  const DamagePipeline({
    required this.effectSource,
    this.accumulator = const EffectAccumulator(),
    this.contextBuilder = const EffectContextBuilder(),
    required this.applyPipeline,
  });

  DamagePipelineResult run(DamagePipelineInput input) {
    final attackerEffects = effectSource.collect(input.attacker);
    final ctx = contextBuilder.forDamage(
      attacker: input.attacker,
      target: input.target,
      damageTypeId: input.baseDamage.typeId,
      isCritical: input.baseDamage.isCritical,
    );
    final contribution = accumulator.accumulateDamage(attackerEffects, ctx);

    final modified = DamageInstance(
      amount: input.baseDamage.amount + contribution.flatBonus,
      typeId: contribution.damageTypeOverride ?? input.baseDamage.typeId,
      isCritical: input.baseDamage.isCritical,
      fromSavedThrow: input.baseDamage.fromSavedThrow,
      savedSucceeded: input.baseDamage.savedSucceeded,
      sourceSpellId: input.baseDamage.sourceSpellId,
    );

    final outcome = applyPipeline.apply(
      target: input.defenses,
      damage: modified,
      concentration: input.concentration,
      conMod: input.conMod,
      saveProfBonus: input.saveProfBonus,
      saveAdvantage: input.saveAdvantage,
      autoSucceedSave: input.autoSucceedSave,
      autoFailSave: input.autoFailSave,
    );

    return DamagePipelineResult(
      outcome: outcome,
      contribution: contribution,
      modifiedDamage: modified,
    );
  }
}
