import '../../../domain/dnd5e/core/advantage_state.dart';
import 'd20_roller.dart';

/// Inputs to an attack roll. Ability mod + proficiency bonus + arbitrary
/// flat bonuses (magical weapon, bless d4 is rolled separately and passed in
/// via `flatBonus`) are summed on top of the d20.
class AttackRollInput {
  final int abilityMod;
  final int proficiencyBonus;
  final int flatBonus;
  final AdvantageState advantage;
  final int targetArmorClass;
  final int coverAcBonus;

  const AttackRollInput({
    required this.abilityMod,
    required this.proficiencyBonus,
    required this.targetArmorClass,
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    this.coverAcBonus = 0,
  });

  int get effectiveArmorClass => targetArmorClass + coverAcBonus;
}

class AttackRollResult {
  final int d20Chosen;
  final int d20Other;
  final AdvantageState advantage;
  final int totalRoll;
  final int effectiveAc;
  final bool hit;
  final bool isCritical;
  final bool isFumble;

  const AttackRollResult({
    required this.d20Chosen,
    required this.d20Other,
    required this.advantage,
    required this.totalRoll,
    required this.effectiveAc,
    required this.hit,
    required this.isCritical,
    required this.isFumble,
  });
}

/// Pure attack roller. Natural 20 is always a critical hit; natural 1 is
/// always a miss (fumble). Non-nat totals compare against AC + cover. Does
/// not read Combatant fields — caller flattens them into [AttackRollInput].
class AttackResolver {
  final D20Roller roller;

  const AttackResolver(this.roller);

  AttackRollResult resolve(AttackRollInput input) {
    final d = roller.roll(input.advantage);
    final ac = input.effectiveArmorClass;
    final total =
        d.chosen + input.abilityMod + input.proficiencyBonus + input.flatBonus;

    if (d.isNaturalTwenty) {
      return AttackRollResult(
        d20Chosen: d.chosen,
        d20Other: d.other,
        advantage: d.state,
        totalRoll: total,
        effectiveAc: ac,
        hit: true,
        isCritical: true,
        isFumble: false,
      );
    }
    if (d.isNaturalOne) {
      return AttackRollResult(
        d20Chosen: d.chosen,
        d20Other: d.other,
        advantage: d.state,
        totalRoll: total,
        effectiveAc: ac,
        hit: false,
        isCritical: false,
        isFumble: true,
      );
    }
    return AttackRollResult(
      d20Chosen: d.chosen,
      d20Other: d.other,
      advantage: d.state,
      totalRoll: total,
      effectiveAc: ac,
      hit: total >= ac,
      isCritical: false,
      isFumble: false,
    );
  }
}
