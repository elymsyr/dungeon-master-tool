import '../../../domain/dnd5e/combat/concentration.dart';
import '../../../domain/dnd5e/core/ability.dart';
import '../../../domain/dnd5e/core/advantage_state.dart';
import '../combat/save_resolver.dart';
import 'concentration_check_outcome.dart';
import 'concentration_dc.dart';

/// Pure damage→save→keep/break pipeline. Composes [ConcentrationDc] with
/// [SaveResolver] so the formula and the save mechanics live in one place.
/// Combatant-level wiring (writing the new concentration back, surfacing a
/// "broken" toast) is the caller's job.
class ConcentrationCheckResolver {
  final SaveResolver saveResolver;

  const ConcentrationCheckResolver(this.saveResolver);

  /// `damage` is the unmitigated damage that *landed* on the concentrator
  /// this turn (post-resistance/vulnerability/temp-hp absorption). When a
  /// creature takes multiple damage instances in one turn, the SRD requires
  /// one save per instance — call this method once per instance.
  ConcentrationCheckOutcome check({
    required Concentration current,
    required int damage,
    required int conMod,
    int saveProfBonus = 0,
    AdvantageState advantage = AdvantageState.normal,
    bool autoSucceed = false,
    bool autoFail = false,
  }) {
    final dc = ConcentrationDc.forDamage(damage);
    final save = saveResolver.resolve(SaveInput(
      ability: Ability.constitution,
      abilityMod: conMod,
      flatBonus: saveProfBonus,
      dc: dc,
      advantage: advantage,
      autoSucceed: autoSucceed,
      autoFail: autoFail,
    ));
    return ConcentrationCheckOutcome(
      damage: damage,
      dc: dc,
      save: save,
      concentrationAfter: save.succeeded ? current : null,
    );
  }
}
