import '../../../domain/dnd5e/combat/concentration.dart';
import '../combat/save_resolver.dart';

/// Result of a concentration check after taking damage. [concentrationAfter]
/// is null when the save failed (concentration broken); otherwise it is the
/// same [Concentration] that was passed in — callers can write the value
/// back to the combatant snapshot unconditionally.
class ConcentrationCheckOutcome {
  final int damage;
  final int dc;
  final SaveResult save;
  final Concentration? concentrationAfter;

  const ConcentrationCheckOutcome({
    required this.damage,
    required this.dc,
    required this.save,
    required this.concentrationAfter,
  });

  bool get broken => concentrationAfter == null;
  bool get maintained => !broken;
}
