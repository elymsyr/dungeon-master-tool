import '../../../domain/dnd5e/core/advantage_state.dart';
import '../../../domain/dnd5e/core/ability.dart';
import 'd20_roller.dart';

/// Why a save returned its result — helps the UI explain auto-pass/-fail
/// without the caller inspecting `d20Chosen == 0`.
enum SaveResolution { rolled, autoSucceed, autoFail }

class SaveInput {
  final Ability ability;
  final int abilityMod;
  final int flatBonus;
  final int dc;
  final AdvantageState advantage;
  final bool autoSucceed;
  final bool autoFail;

  const SaveInput({
    required this.ability,
    required this.abilityMod,
    required this.dc,
    this.flatBonus = 0,
    this.advantage = AdvantageState.normal,
    this.autoSucceed = false,
    this.autoFail = false,
  });
}

class SaveResult {
  final bool succeeded;
  final SaveResolution resolution;
  final int d20Chosen;
  final int d20Other;
  final int totalRoll;
  final int dc;
  final AdvantageState advantage;

  const SaveResult({
    required this.succeeded,
    required this.resolution,
    required this.d20Chosen,
    required this.d20Other,
    required this.totalRoll,
    required this.dc,
    required this.advantage,
  });
}

/// Pure saving-throw resolver. Auto-fail wins over auto-succeed (paralyzed
/// creature trying to succeed via an effect still auto-fails STR/DEX per SRD
/// condition ruling), matching what Doc 01 Tier 2 `ModifySave` already
/// guards at construction.
class SaveResolver {
  final D20Roller roller;

  const SaveResolver(this.roller);

  SaveResult resolve(SaveInput input) {
    if (input.autoFail) {
      return SaveResult(
        succeeded: false,
        resolution: SaveResolution.autoFail,
        d20Chosen: 0,
        d20Other: 0,
        totalRoll: 0,
        dc: input.dc,
        advantage: input.advantage,
      );
    }
    if (input.autoSucceed) {
      return SaveResult(
        succeeded: true,
        resolution: SaveResolution.autoSucceed,
        d20Chosen: 0,
        d20Other: 0,
        totalRoll: 0,
        dc: input.dc,
        advantage: input.advantage,
      );
    }
    final d = roller.roll(input.advantage);
    final total = d.chosen + input.abilityMod + input.flatBonus;
    return SaveResult(
      succeeded: total >= input.dc,
      resolution: SaveResolution.rolled,
      d20Chosen: d.chosen,
      d20Other: d.other,
      totalRoll: total,
      dc: input.dc,
      advantage: d.state,
    );
  }
}
