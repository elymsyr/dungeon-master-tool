import 'dart:math' as math;

import 'damage_instance.dart';
import 'damage_outcome.dart';
import 'target_defenses.dart';

/// Applies one [DamageInstance] to a [TargetDefenses], producing a
/// [DamageOutcome]. Pure function — no combatant mutation, no RNG. The caller
/// writes the outcome back onto the live combatant and handles follow-up
/// effects (concentration save, death save prompts).
///
/// Pipeline (order matters, per Doc 11 §Damage Application Pipeline):
///   1. Immunity → zero the amount
///   2. Resistance → floor(amount / 2)
///   3. Vulnerability → amount * 2
///   4. Save-for-half → floor(amount / 2) if `fromSavedThrow && savedSucceeded`
///   5. Temp HP absorbs first
///   6. Remainder subtracted from currentHp (floored at 0)
///   7. Concentration DC = max(10, floor(postMitigation / 2)), capped at 30
///   8. PC instant death: post-HP==0 and leftover >= maxHp
///   9. Death-save failures: +1 per zero-crossing hit, +2 if the hit was a crit
class DamageResolver {
  const DamageResolver();

  DamageOutcome resolve(TargetDefenses t, DamageInstance dmg) {
    var amt = dmg.amount;

    if (t.damageImmunities.contains(dmg.typeId)) {
      amt = 0;
    } else {
      if (t.resistances.contains(dmg.typeId)) amt = amt ~/ 2;
      if (t.vulnerabilities.contains(dmg.typeId)) amt = amt * 2;
      if (dmg.fromSavedThrow && dmg.savedSucceeded) amt = amt ~/ 2;
    }

    int absorbed = 0;
    int tempHpAfter = t.tempHp;
    int remainder = amt;
    if (t.tempHp > 0 && amt > 0) {
      absorbed = math.min(t.tempHp, amt);
      tempHpAfter = t.tempHp - absorbed;
      remainder = amt - absorbed;
    }

    final hpAfter = math.max(0, t.currentHp - remainder);
    final dropsToZero = t.currentHp > 0 && hpAfter == 0;

    final concCheck = amt > 0;
    final concDc = math.min(30, math.max(10, amt ~/ 2));

    final overkill = remainder - t.currentHp; // leftover past 0 HP
    final instantDeath =
        t.isPlayer && hpAfter == 0 && overkill >= t.maxHp;

    // Death-save failures: PC only, and only when the hit lands *while
    // already at 0 HP* (dropping TO 0 triggers Unconscious, not a failure).
    // Crit at 0 HP = 2 failures per SRD.
    int deathFails = 0;
    if (t.isPlayer && !instantDeath && t.currentHp == 0 && remainder > 0) {
      deathFails = dmg.isCritical ? 2 : 1;
    }

    return DamageOutcome(
      amountAfterMitigation: amt,
      absorbedByTempHp: absorbed,
      newCurrentHp: hpAfter,
      newTempHp: tempHpAfter,
      dropsToZero: dropsToZero,
      concentrationCheckTriggered: concCheck,
      concentrationSaveDc: concDc,
      instantDeath: instantDeath,
      deathSaveFailuresToAdd: deathFails,
    );
  }
}
