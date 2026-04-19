import 'dart:math' as math;

import 'damage_outcome.dart';
import 'target_defenses.dart';
import 'typed_damage.dart';

/// Per-type mitigation breakdown — one row per damage type in the incoming
/// bundle, with the amount surviving resist/vuln/imm. Sum of
/// `amountAfterMitigation` over all rows equals the bundle total pre-save.
class TypedDamageBreakdownRow {
  final String typeId;
  final int amountBefore;
  final int amountAfterMitigation;
  final bool resisted;
  final bool vulnerable;
  final bool immune;

  const TypedDamageBreakdownRow({
    required this.typeId,
    required this.amountBefore,
    required this.amountAfterMitigation,
    required this.resisted,
    required this.vulnerable,
    required this.immune,
  });
}

class MultiTypeDamageOutcome {
  final DamageOutcome outcome;
  final List<TypedDamageBreakdownRow> breakdown;
  final int totalPreSave;
  final int totalPostSave;

  const MultiTypeDamageOutcome({
    required this.outcome,
    required this.breakdown,
    required this.totalPreSave,
    required this.totalPostSave,
  });
}

/// Multi-type damage pipeline per Doc 13 §DamageReducer. Applies resist/vuln/
/// imm per type (order: halve-if-resisted → double-if-vulnerable → zero-if-
/// immune, matching single-type `DamageResolver`), sums the survivors, halves
/// again on successful save, absorbs temp HP, subtracts from currentHp,
/// then reports concentration-check trigger + PC instant death + death-save
/// failures accrued at 0 HP. Pure function — no RNG, no side effects.
class MultiTypeDamageResolver {
  const MultiTypeDamageResolver();

  MultiTypeDamageOutcome resolve(TargetDefenses t, TypedDamage dmg) {
    final rows = <TypedDamageBreakdownRow>[];
    int totalPreSave = 0;

    for (final e in dmg.byType.entries) {
      final typeId = e.key;
      var amt = e.value;
      final immune = t.damageImmunities.contains(typeId);
      final resisted = !immune && t.resistances.contains(typeId);
      final vulnerable = !immune && t.vulnerabilities.contains(typeId);

      if (immune) {
        amt = 0;
      } else {
        if (resisted) amt = amt ~/ 2;
        if (vulnerable) amt = amt * 2;
      }

      rows.add(TypedDamageBreakdownRow(
        typeId: typeId,
        amountBefore: e.value,
        amountAfterMitigation: amt,
        resisted: resisted,
        vulnerable: vulnerable,
        immune: immune,
      ));
      totalPreSave += amt;
    }

    var total = totalPreSave;
    if (dmg.fromSavedThrow && dmg.savedSucceeded) {
      total = total ~/ 2;
    }
    final totalPostSave = total;

    int absorbed = 0;
    int tempHpAfter = t.tempHp;
    int remainder = total;
    if (t.tempHp > 0 && total > 0) {
      absorbed = math.min(t.tempHp, total);
      tempHpAfter = t.tempHp - absorbed;
      remainder = total - absorbed;
    }

    final hpAfter = math.max(0, t.currentHp - remainder);
    final dropsToZero = t.currentHp > 0 && hpAfter == 0;
    final concCheck = total > 0;
    final concDc = math.min(30, math.max(10, total ~/ 2));

    final overkill = remainder - t.currentHp;
    final instantDeath =
        t.isPlayer && hpAfter == 0 && overkill >= t.maxHp;

    int deathFails = 0;
    if (t.isPlayer && !instantDeath && t.currentHp == 0 && remainder > 0) {
      deathFails = dmg.isCritical ? 2 : 1;
    }

    return MultiTypeDamageOutcome(
      outcome: DamageOutcome(
        amountAfterMitigation: total,
        absorbedByTempHp: absorbed,
        newCurrentHp: hpAfter,
        newTempHp: tempHpAfter,
        dropsToZero: dropsToZero,
        concentrationCheckTriggered: concCheck,
        concentrationSaveDc: concDc,
        instantDeath: instantDeath,
        deathSaveFailuresToAdd: deathFails,
      ),
      breakdown: List.unmodifiable(rows),
      totalPreSave: totalPreSave,
      totalPostSave: totalPostSave,
    );
  }
}
