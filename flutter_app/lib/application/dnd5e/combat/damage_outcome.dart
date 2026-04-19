/// Result of applying one [DamageInstance] to a [TargetDefenses]. Pure data;
/// caller writes back to the underlying Combatant + triggers concentration
/// save / death-save prompts based on these flags.
class DamageOutcome {
  final int amountAfterMitigation;
  final int absorbedByTempHp;
  final int newCurrentHp;
  final int newTempHp;
  final bool dropsToZero;
  final bool concentrationCheckTriggered;
  final int concentrationSaveDc;
  final bool instantDeath;
  final int deathSaveFailuresToAdd;

  const DamageOutcome({
    required this.amountAfterMitigation,
    required this.absorbedByTempHp,
    required this.newCurrentHp,
    required this.newTempHp,
    required this.dropsToZero,
    required this.concentrationCheckTriggered,
    required this.concentrationSaveDc,
    required this.instantDeath,
    required this.deathSaveFailuresToAdd,
  });
}
