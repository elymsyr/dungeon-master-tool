# 13 — Damage Resolver Spec

> **For Claude.** Pure functions for attack roll → crit → damage roll → resistance/vuln/immunity → save-half → temp HP → HP delta.
> **Source rules:** [00 §1, §10, §11](./00-dnd5e-mechanics-reference.md#11-damage-pp-16-17)
> **Target:** `flutter_app/lib/application/dnd5e/combat/`

## Pipeline Overview

```
[1] AttackResolver       — d20 + mods vs AC → hit | miss | critical
[2] DamageRollBuilder    — assemble dice + modifiers; double dice on crit
[3] DamageReducer        — order: adjustments → resistance → vulnerability
[4] ImmunityFilter       — zero out if immune
[5] SaveHalfModifier     — halve if from saving throw effect with success
[6] TempHpAbsorber       — drain temp HP first
[7] HpApplier            — clamp to [0, max]; produce HP delta
[8] PostDamageHooks      — concentration check, instant death, prone-on-fall, etc.
```

All steps are pure functions (input → output). Side effects (DB writes, broadcast) happen in calling service.

## Types

```dart
// flutter_app/lib/application/dnd5e/combat/types/damage_pipeline_types.dart

class AttackContext {
  final Combatant attacker;
  final Combatant target;
  final Weapon? weapon;            // null if spell attack
  final Spell? spell;              // null if weapon attack
  final bool isMelee;
  final bool isRanged;
  final double distanceFt;
  final List<FeatureEffect> attackerEffects;
  final List<FeatureEffect> targetEffects;
  final AdvantageState baselineAdvantage;
}

class AttackResult {
  final int d20Roll;
  final int totalRoll;
  final bool hit;
  final bool isCritical;
  final bool isFumble;             // nat 1
  final AdvantageState appliedAdvantage;
  final int targetAc;
}

class DamageRollSpec {
  final List<DiceExpression> dice;
  final int flatBonus;
  final DamageType primaryType;
  final List<({DiceExpression dice, DamageType type})> additionalTypes;
  final bool isCritical;
  final bool fromSavingThrowEffect;
  final bool savingThrowSucceeded;
  final String? sourceSpellId;     // for concentration
}

class DamageRollResult {
  final int totalRolled;
  final Map<DamageType, int> byType;
  final List<int> individualDice;   // for display
}

class DamageOutcome {
  final int newCurrentHp;
  final int newTempHp;
  final int actualDamageDealt;     // post-resistance/vuln, after temp absorb
  final bool concentrationBroken;
  final bool instantDeath;
  final int deathSaveFailuresGained;   // 0, 1, or 2
  final List<String> notes;
}
```

## [1] AttackResolver

```dart
class AttackResolver {
  AttackResult resolve(AttackContext ctx) {
    // Compute advantage from baseline + effects.
    AdvantageState adv = ctx.baselineAdvantage;
    int flatBonus = 0;
    final extraDice = <DiceExpression>[];

    for (final fx in ctx.attackerEffects) {
      final m = fx.modifyAttackRoll(_buildAttackRollContext(ctx));
      adv = adv.combine(m.advantageState);
      flatBonus += m.flatBonus;
      extraDice.addAll(m.extraDice);
    }
    for (final fx in ctx.targetEffects) {
      // Some target effects impose disadvantage on attacks vs them.
      final m = fx.modifyAttackAgainst(_buildAttackRollContext(ctx));
      adv = adv.combine(m.advantageState);
    }

    // Cover bonus.
    final coverAcBonus = _coverAcBonus(ctx);
    final effectiveAc = ctx.target.armorClass + coverAcBonus;

    // Roll.
    final d20 = adv.rollD20();
    if (d20 == 20) return AttackResult(d20Roll: 20, totalRoll: 20, hit: true, isCritical: true, isFumble: false, appliedAdvantage: adv, targetAc: effectiveAc);
    if (d20 == 1)  return AttackResult(d20Roll: 1,  totalRoll: 1,  hit: false, isCritical: false, isFumble: true,  appliedAdvantage: adv, targetAc: effectiveAc);

    final abilityMod = _attackAbilityMod(ctx);
    final pb = ctx.attacker.proficiencyBonus;
    final extras = extraDice.fold(0, (s, d) => s + d.roll());

    final total = d20 + abilityMod + pb + flatBonus + extras;
    return AttackResult(
      d20Roll: d20,
      totalRoll: total,
      hit: total >= effectiveAc,
      isCritical: false,
      isFumble: false,
      appliedAdvantage: adv,
      targetAc: effectiveAc,
    );
  }

  int _coverAcBonus(AttackContext ctx) {
    // MVP: optional. Default 0; DM can manually flag cover.
    return ctx.target.coverState?.acBonus ?? 0;
  }
}
```

### AdvantageState

```dart
enum AdvantageState {
  normal, advantage, disadvantage;

  AdvantageState combine(AdvantageState other) {
    if (this == other) return this;
    if (this == normal) return other;
    if (other == normal) return this;
    return normal;   // advantage + disadvantage cancel
  }

  int rollD20() => switch (this) {
    normal => Dice.d20(),
    advantage => math.max(Dice.d20(), Dice.d20()),
    disadvantage => math.min(Dice.d20(), Dice.d20()),
  };
}
```

## [2] DamageRollBuilder

```dart
class DamageRollBuilder {
  /// Assembles the damage spec given the attack context and effects.
  DamageRollSpec build(AttackContext ctx, AttackResult attack) {
    final base = _baseDamage(ctx);   // weapon die + ability mod, or spell-specified

    final extras = <({DiceExpression dice, DamageType type})>[];
    int flatBonus = 0;

    for (final fx in ctx.attackerEffects) {
      final m = fx.modifyDamageRoll(_buildDamageContext(ctx, attack));
      flatBonus += m.flatBonus;
      for (final d in m.extraDice) {
        extras.add((dice: d, type: ctx.weapon?.damageType ?? base.primaryType));
      }
      for (final t in m.additionalTypes) {
        extras.add((dice: m.extraDice.first, type: t));   // simplified
      }
    }

    return DamageRollSpec(
      dice: base.dice,
      flatBonus: base.flatBonus + flatBonus,
      primaryType: base.primaryType,
      additionalTypes: extras,
      isCritical: attack.isCritical,
      fromSavingThrowEffect: false,
      savingThrowSucceeded: false,
    );
  }
}
```

## [3] Roll the Dice

```dart
class DamageRollExecutor {
  DamageRollResult execute(DamageRollSpec spec) {
    final byType = <DamageType, int>{};
    final allDice = <int>[];

    // Primary dice.
    int primary = 0;
    for (final d in spec.dice) {
      final rolled = spec.isCritical ? d.rollDoubled() : d.roll();
      primary += rolled;
      allDice.addAll(d.lastIndividualRolls);
    }
    primary += spec.flatBonus;
    byType[spec.primaryType] = (byType[spec.primaryType] ?? 0) + primary;

    // Additional types.
    for (final extra in spec.additionalTypes) {
      final rolled = spec.isCritical ? extra.dice.rollDoubled() : extra.dice.roll();
      byType[extra.type] = (byType[extra.type] ?? 0) + rolled;
      allDice.addAll(extra.dice.lastIndividualRolls);
    }

    final total = byType.values.fold(0, (a, b) => a + b);
    return DamageRollResult(totalRolled: total, byType: byType, individualDice: allDice);
  }
}
```

`DiceExpression.rollDoubled()`: rolls dice twice the count, sums; modifiers added once.

## [4-6] DamageReducer (resistance/vuln/immunity/save-half/temp-HP)

```dart
class DamageReducer {
  /// Pure. Apply order per SRD §11.5: adjustments → resistance → vulnerability.
  /// Then immunity zero-out; save-half if applicable; temp HP absorb.
  DamageOutcome apply({
    required Combatant target,
    required DamageRollResult rolled,
    required bool fromSave,
    required bool saveSucceeded,
  }) {
    int totalAfter = 0;
    final notes = <String>[];

    for (final entry in rolled.byType.entries) {
      var amt = entry.value;

      // [3] Adjustments. (MVP: skip; auras come later.)

      // [4] Resistance.
      if (target.resistances.contains(entry.key)) {
        amt = (amt / 2).floor();
        notes.add('Resistance to ${entry.key.name}: halved');
      }

      // [5] Vulnerability.
      if (target.vulnerabilities.contains(entry.key)) {
        amt = amt * 2;
        notes.add('Vulnerability to ${entry.key.name}: doubled');
      }

      // [6] Immunity.
      if (target.damageImmunities.contains(entry.key)) {
        amt = 0;
        notes.add('Immune to ${entry.key.name}');
      }

      totalAfter += amt;
    }

    // [7] Save-half.
    if (fromSave && saveSucceeded) {
      totalAfter = (totalAfter / 2).floor();
      notes.add('Save succeeded: damage halved');
    }

    // [8] Temp HP absorption.
    int newTempHp = target.tempHp;
    int realDamage = totalAfter;
    if (target.tempHp > 0) {
      final absorbed = math.min(target.tempHp, totalAfter);
      newTempHp = target.tempHp - absorbed;
      realDamage = totalAfter - absorbed;
      notes.add('Temp HP absorbed $absorbed');
    }

    final newHp = math.max(0, target.currentHp - realDamage);

    // Concentration check.
    final concBroken = target.concentration != null && _concentrationCheck(target, totalAfter);
    if (concBroken) notes.add('Concentration broken');

    // Instant death (PCs only; massive damage rule).
    final instantDeath = (target is PlayerCombatant)
      && newHp == 0
      && realDamage >= target.maxHp;
    if (instantDeath) notes.add('Massive damage: instant death');

    // Death save failures from damage at 0 HP.
    int dsFailures = 0;
    if (target is PlayerCombatant && target.currentHp == 0 && realDamage > 0) {
      dsFailures = (rolled.byType.values.any((_) => _isCriticalSourced)) ? 2 : 1;
    }

    return DamageOutcome(
      newCurrentHp: newHp,
      newTempHp: newTempHp,
      actualDamageDealt: realDamage,
      concentrationBroken: concBroken,
      instantDeath: instantDeath,
      deathSaveFailuresGained: dsFailures,
      notes: notes,
    );
  }

  bool _concentrationCheck(Combatant target, int damage) {
    if (target.concentration == null) return false;
    if (target.conditions.contains(Condition.incapacitated)) return true;
    final dc = math.min(30, math.max(10, (damage / 2).floor()));
    final save = Dice.d20() + target.savingThrowMod(Ability.constitution);
    return save < dc;
  }
}
```

## Saving Throw Resolver (parallel pipeline for save-only spells)

```dart
class SaveResolver {
  SaveResult resolve({
    required Combatant target,
    required Ability ability,
    required int dc,
    required List<FeatureEffect> targetEffects,
    bool autoFailSometimes = false,    // for paralyzed STR/DEX, etc.
  }) {
    // Auto-fail for certain conditions (Paralyzed → STR/DEX auto-fail).
    if (_autoFailsByCondition(target, ability)) {
      return SaveResult(succeeded: false, autoResult: 'auto-fail', d20Roll: 0, total: 0, dc: dc);
    }

    AdvantageState adv = AdvantageState.normal;
    int flatBonus = 0;
    bool autoSucceed = false;
    bool autoFail = false;

    for (final fx in targetEffects) {
      final m = fx.modifySave(_buildSaveContext(target, ability));
      adv = adv.combine(m.advantageState);
      flatBonus += m.flatBonus;
      if (m.autoSucceed) autoSucceed = true;
      if (m.autoFail) autoFail = true;
    }

    if (autoFail) return SaveResult(succeeded: false, autoResult: 'auto-fail', d20Roll: 0, total: 0, dc: dc);
    if (autoSucceed) return SaveResult(succeeded: true, autoResult: 'auto-succeed', d20Roll: 0, total: 0, dc: dc);

    final d20 = adv.rollD20();
    final total = d20 + target.savingThrowMod(ability) + flatBonus;
    return SaveResult(succeeded: total >= dc, d20Roll: d20, total: total, dc: dc);
  }
}
```

## AoE Damage (single roll, multi-apply)

Per SRD §11.6:

```dart
class AoEDamageOrchestrator {
  Map<String, DamageOutcome> apply({
    required AreaOfEffect area,
    required GridCell origin,
    required List<Combatant> potentialTargets,
    required DamageRollResult rolledOnce,         // rolled ONCE
    required Ability saveAbility,
    required int saveDc,
  }) {
    final affected = potentialTargets.where((t) =>
      area.coverage(origin, /* dir */).contains(t.tokenPosition?.toGridCell())
    );

    return {
      for (final target in affected)
        target.id: _resolveOne(target, rolledOnce, saveAbility, saveDc),
    };
  }
}
```

## Test Fixtures (test/application/dnd5e/combat/)

Required test scenarios (parameterized):

| Scenario | Inputs | Expected |
|---|---|---|
| 28 fire dmg, Resist all + Vuln Fire, -5 aura | order check | 22 final (28-5=23 → 11 → 22) |
| Crit on 1d8+3 weapon | crit=true | 2d8 + 3 |
| Crit + Sneak Attack 3d6 | crit=true | 2d8+3 + 6d6 |
| AoE save success → half | save=true | (rolled/2 floor) |
| Damage + temp HP | tempHp=5, dmg=7 | tempHp=0, hpΔ=2 |
| Concentration check | dmg=15, CON +1 | DC = max(10, 7) = 10; pass if 1d20+1 ≥ 10 |
| Massive damage at 0 HP | hp=0, dmg=maxHp | instantDeath=true |
| Crit at 0 HP | hp=0, dmg=any | deathSaveFailures=2 |
| Auto-fail STR save while Paralyzed | condition=paralyzed | succeeded=false |
| Adv + Disadv cancel | both flagged | advState=normal |

## Acceptance

- All test scenarios pass.
- Damage pipeline is pure (no DB, no broadcast).
- Caller (combat service / cast service) invokes resolver and persists outcome.
- Output `notes` array supports UI explanation toast.
- `flutter test` ≥ 50 cases for damage pipeline.

## Open Questions

1. Where do critical-hit-only extra dice (e.g., Champion's Improved Critical) modify the spec? → Modeled via `FeatureEffect.modifyDamageRoll` checking `ctx.isCritical`.
2. Should we model "halve damage rounding" globally (round down per §1.6)? → Yes; centralize as `_halveDown(int)` helper.
3. Resistance/vuln on non-weapon damage (e.g., Fire Shield reactive damage): → Same pipeline; just different `DamageRollSpec` source.
