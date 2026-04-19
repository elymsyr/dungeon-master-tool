import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../effect/combatant_effect_source.dart';
import '../effect/effect_accumulator.dart';
import '../effect/effect_context_builder.dart';
import 'save_resolver.dart';

/// Inputs for one save-pipeline run. The caller already knows the saver's
/// ability mod + proficiency contribution; the pipeline folds in any
/// `ModifySave` descriptors that match the requested ability.
class SavePipelineInput {
  final Combatant saver;
  final Ability ability;
  final int abilityMod;
  final int proficiencyContribution;
  final int dc;
  final AdvantageState baseAdvantage;
  final Set<String> activeEffectIds;

  const SavePipelineInput({
    required this.saver,
    required this.ability,
    required this.abilityMod,
    required this.dc,
    this.proficiencyContribution = 0,
    this.baseAdvantage = AdvantageState.normal,
    this.activeEffectIds = const {},
  });
}

class SavePipelineResult {
  final SaveResult save;
  final SaveContribution contribution;

  const SavePipelineResult({required this.save, required this.contribution});
}

/// Composes [CombatantEffectSource] + [EffectAccumulator] (save side) +
/// [SaveResolver]. Pure: only RNG is the resolver's d20.
///
/// Combines auto-flags with the resolver's own precedence — the accumulator
/// surfaces both `autoSucceed` and `autoFail` raw, and [SaveResolver] applies
/// the SRD rule (autoFail wins). Advantage from descriptors is combined with
/// the caller-provided [baseAdvantage] before the d20 is rolled.
class SavePipeline {
  final CombatantEffectSource effectSource;
  final EffectAccumulator accumulator;
  final EffectContextBuilder contextBuilder;
  final SaveResolver resolver;

  const SavePipeline({
    required this.effectSource,
    this.accumulator = const EffectAccumulator(),
    this.contextBuilder = const EffectContextBuilder(),
    required this.resolver,
  });

  SavePipelineResult run(SavePipelineInput input) {
    final effects = effectSource.collect(input.saver);
    final ctx = contextBuilder.forSelfSave(
      saver: input.saver,
      activeEffectIds: input.activeEffectIds,
    );
    final contribution = accumulator.accumulateSave(
      effects,
      ctx,
      ability: input.ability,
    );
    final input_ = SaveInput(
      ability: input.ability,
      abilityMod: input.abilityMod,
      flatBonus: input.proficiencyContribution + contribution.flatBonus,
      dc: input.dc,
      advantage: input.baseAdvantage.combine(contribution.advantage),
      autoSucceed: contribution.autoSucceed,
      autoFail: contribution.autoFail,
    );
    final result = resolver.resolve(input_);
    return SavePipelineResult(save: result, contribution: contribution);
  }
}
