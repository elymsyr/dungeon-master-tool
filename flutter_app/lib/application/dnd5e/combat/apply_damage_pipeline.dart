import '../../../domain/dnd5e/combat/concentration.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../spell/concentration_check_resolver.dart';
import 'apply_damage_outcome.dart';
import 'damage_instance.dart';
import 'damage_resolver.dart';
import 'target_defenses.dart';

/// Composes [DamageResolver] with [ConcentrationCheckResolver] so the caller
/// runs one method per hit. Pure: no Combatant mutation, no repository writes,
/// no RNG of its own — the concentration save's d20 comes from the injected
/// resolver.
///
/// MVP scope: only the damage-driven concentration trigger. Other break
/// causes (incapacitation, casting another concentration spell, death from
/// other sources) are the caller's responsibility — see Doc 12.
class ApplyDamagePipeline {
  final DamageResolver damageResolver;
  final ConcentrationCheckResolver concentrationResolver;

  const ApplyDamagePipeline({
    required this.damageResolver,
    required this.concentrationResolver,
  });

  ApplyDamageOutcome apply({
    required TargetDefenses target,
    required DamageInstance damage,
    Concentration? concentration,
    int conMod = 0,
    int saveProfBonus = 0,
    AdvantageState saveAdvantage = AdvantageState.normal,
    bool autoSucceedSave = false,
    bool autoFailSave = false,
  }) {
    final dmg = damageResolver.resolve(target, damage);

    final shouldRoll = concentration != null &&
        dmg.concentrationCheckTriggered &&
        !dmg.instantDeath;

    final conc = shouldRoll
        ? concentrationResolver.check(
            current: concentration,
            damage: dmg.amountAfterMitigation,
            conMod: conMod,
            saveProfBonus: saveProfBonus,
            advantage: saveAdvantage,
            autoSucceed: autoSucceedSave,
            autoFail: autoFailSave,
          )
        : null;

    return ApplyDamageOutcome(damage: dmg, concentration: conc);
  }
}
