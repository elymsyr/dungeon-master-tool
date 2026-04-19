import '../combat/save_resolver.dart';
import 'apply_damage_outcome.dart';

/// Per-target result from an AoE spell. [spellSave] is null when the spell
/// has no save-for-half (the orchestrator was called without a saveDc); the
/// damage pipeline still ran. [damage] always present.
class AoETargetOutcome {
  final SaveResult? spellSave;
  final ApplyDamageOutcome damage;

  const AoETargetOutcome({
    required this.spellSave,
    required this.damage,
  });
}
