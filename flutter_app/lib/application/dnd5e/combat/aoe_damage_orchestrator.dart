import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/spell/area_of_effect.dart';
import '../../../domain/dnd5e/spell/grid_cell.dart';
import '../combat/save_resolver.dart';
import 'aoe_target.dart';
import 'aoe_target_outcome.dart';
import 'apply_damage_pipeline.dart';
import 'damage_instance.dart';

/// Orchestrates one AoE damage spell:
///   1. Filter targets by [AreaOfEffect.coverage] from [origin]/[direction].
///   2. For each affected target, roll the spell save (if [saveDc] non-null).
///   3. Apply the same pre-rolled [damageAmount] via [ApplyDamagePipeline],
///      with [DamageInstance.fromSavedThrow] / [savedSucceeded] populated
///      from step 2 so the pipeline halves on success.
///
/// Per SRD §11.6 the damage roll is rolled ONCE for the whole AoE — this
/// orchestrator takes the already-rolled total and broadcasts it.
class AoEDamageOrchestrator {
  final SaveResolver saveResolver;
  final ApplyDamagePipeline damagePipeline;

  const AoEDamageOrchestrator({
    required this.saveResolver,
    required this.damagePipeline,
  });

  Map<String, AoETargetOutcome> apply({
    required AreaOfEffect area,
    required GridCell origin,
    required GridDirection direction,
    required List<AoETarget> targets,
    required int damageAmount,
    required String damageTypeId,
    Ability? saveAbility,
    int? saveDc,
    bool isCritical = false,
    String? sourceSpellId,
  }) {
    if (damageAmount < 0) {
      throw ArgumentError(
          'AoEDamageOrchestrator.damageAmount must be >= 0, got $damageAmount');
    }
    if ((saveDc == null) != (saveAbility == null)) {
      throw ArgumentError(
          'saveDc and saveAbility must be set together (both or neither)');
    }

    final coverage = area.coverage(origin, direction);
    final out = <String, AoETargetOutcome>{};

    for (final t in targets) {
      if (!coverage.contains(t.position)) continue;

      SaveResult? spellSave;
      bool savedSucceeded = false;
      if (saveDc != null) {
        spellSave = saveResolver.resolve(SaveInput(
          ability: saveAbility!,
          abilityMod: t.spellSaveAbilityMod,
          flatBonus: t.spellSaveProfBonus,
          dc: saveDc,
          advantage: t.spellSaveAdvantage,
          autoSucceed: t.autoSucceedSpellSave,
          autoFail: t.autoFailSpellSave,
        ));
        savedSucceeded = spellSave.succeeded;
      }

      final dmg = DamageInstance(
        amount: damageAmount,
        typeId: damageTypeId,
        isCritical: isCritical,
        fromSavedThrow: saveDc != null,
        savedSucceeded: savedSucceeded,
        sourceSpellId: sourceSpellId,
      );

      final apply = damagePipeline.apply(
        target: t.defenses,
        damage: dmg,
        concentration: t.concentration,
        conMod: t.conMod,
        saveProfBonus: t.concentrationSaveProfBonus,
        saveAdvantage: t.concentrationSaveAdvantage,
        autoSucceedSave: t.autoSucceedConcentrationSave,
        autoFailSave: t.autoFailConcentrationSave,
      );

      out[t.id] = AoETargetOutcome(spellSave: spellSave, damage: apply);
    }

    return out;
  }
}
