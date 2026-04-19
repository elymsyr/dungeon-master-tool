import '../../../domain/dnd5e/combat/concentration.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../../../domain/dnd5e/spell/grid_cell.dart';
import 'target_defenses.dart';

/// Per-target inputs the [AoEDamageOrchestrator] needs to resolve one combatant
/// inside an area-of-effect spell. The orchestrator filters by [position],
/// rolls the spell save (if the spell offers one) using the spell-save
/// fields, then runs the damage pipeline. The concentration-save fields are
/// only consumed when this target is currently concentrating AND takes
/// non-zero post-mitigation damage.
class AoETarget {
  final String id;
  final GridCell position;
  final TargetDefenses defenses;

  // Spell save (save-for-half on the AoE). Ignored when the spell is not a
  // saving-throw spell (saveDc on the orchestrator call is null).
  final int spellSaveAbilityMod;
  final int spellSaveProfBonus;
  final AdvantageState spellSaveAdvantage;
  final bool autoFailSpellSave;
  final bool autoSucceedSpellSave;

  // Concentration save (only fires when concentrating AND damaged).
  final Concentration? concentration;
  final int conMod;
  final int concentrationSaveProfBonus;
  final AdvantageState concentrationSaveAdvantage;
  final bool autoFailConcentrationSave;
  final bool autoSucceedConcentrationSave;

  const AoETarget({
    required this.id,
    required this.position,
    required this.defenses,
    this.spellSaveAbilityMod = 0,
    this.spellSaveProfBonus = 0,
    this.spellSaveAdvantage = AdvantageState.normal,
    this.autoFailSpellSave = false,
    this.autoSucceedSpellSave = false,
    this.concentration,
    this.conMod = 0,
    this.concentrationSaveProfBonus = 0,
    this.concentrationSaveAdvantage = AdvantageState.normal,
    this.autoFailConcentrationSave = false,
    this.autoSucceedConcentrationSave = false,
  });
}
