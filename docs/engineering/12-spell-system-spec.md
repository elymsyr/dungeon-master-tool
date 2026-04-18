# 12 — Spell System Spec

> **For Claude.** Spell slots, multiclass calculator, concentration, AoE geometry.
> **Source rules:** [00 §17, §24](./00-dnd5e-mechanics-reference.md#17-multiclassing-pp-24-25)
> **Target:** `flutter_app/lib/application/dnd5e/spell/`, `flutter_app/lib/domain/dnd5e/spell/`
> **Content policy.** Spell slot *progression tables* are D&D 5e mechanics and live in Dart (see below). Concrete spells and classes are Tier 1 content and arrive via packages. A class's `casterFraction` field (data) drives the multiclass calculator (structural logic). `Spell.effects: List<EffectDescriptor>` — see [01-domain-model-spec.md](./01-domain-model-spec.md) §Effects for the unified descriptor family.

## Spell Slot Tables

The slot progression table is structural (a D&D 5e mechanic); class identities (`srd:wizard`, `srd:paladin`, …) and their caster fractions are content. Tier 1 `CharacterClass` declares:

```dart
enum CasterKind { none, full, half, third, pact }

class CharacterClass {
  final String id;                     // 'srd:wizard'
  final String name;
  final CasterKind casterKind;         // data input to multiclass calculator
  final double casterFraction;         // 1.0 / 0.5 / (1/3). 0 for non-casters. Pact uses own table.
  ...
}
```

No per-class slot tables live in Dart. All full-casters share one progression; half-casters use it at `floor(level * 0.5)`; third-casters at `floor(level * 1/3)`. Warlock (Pact) uses the separate table below, gated on `casterKind == pact`.

### Multiclass / Single-Class Slot Calculator

Single-class callers invoke the multiclass calculator with a one-entry list — the math collapses correctly.

```dart
// flutter_app/lib/application/dnd5e/spell/multiclass_slot_calculator.dart

class MulticlassSlotCalculator {
  final ContentRegistry registry;
  MulticlassSlotCalculator(this.registry);

  /// Returns combined caster level by summing level * class.casterFraction.
  int combinedCasterLevel(List<CharacterClassLevel> levels) {
    double sum = 0;
    for (final lvl in levels) {
      final cls = registry.classes[lvl.classId];
      if (cls == null) continue;
      if (cls.casterKind == CasterKind.none || cls.casterKind == CasterKind.pact) continue;
      sum += lvl.level * cls.casterFraction;
    }
    return sum.floor();
  }

  /// Returns slot array (9 entries, one per spell level) for a spellcaster.
  List<int> slotsFor(List<CharacterClassLevel> levels) {
    final cl = combinedCasterLevel(levels);
    if (cl == 0) return List.filled(9, 0);
    return _slotProgression[cl - 1];
  }

  /// Structural D&D 5e slot progression — identical for all full casters.
  /// Half/third casters index via combinedCasterLevel which has already applied their fraction.
  static const List<List<int>> _slotProgression = [
    [2,0,0,0,0,0,0,0,0],   // 1
    [3,0,0,0,0,0,0,0,0],
    [4,2,0,0,0,0,0,0,0],
    [4,3,0,0,0,0,0,0,0],
    [4,3,2,0,0,0,0,0,0],
    [4,3,3,0,0,0,0,0,0],
    [4,3,3,1,0,0,0,0,0],
    [4,3,3,2,0,0,0,0,0],
    [4,3,3,3,1,0,0,0,0],
    [4,3,3,3,2,0,0,0,0],
    [4,3,3,3,2,1,0,0,0],
    [4,3,3,3,2,1,0,0,0],
    [4,3,3,3,2,1,1,0,0],
    [4,3,3,3,2,1,1,0,0],
    [4,3,3,3,2,1,1,1,0],
    [4,3,3,3,2,1,1,1,0],
    [4,3,3,3,2,1,1,1,1],
    [4,3,3,3,3,1,1,1,1],
    [4,3,3,3,3,2,1,1,1],
    [4,3,3,3,3,2,2,1,1],   // 20
  ];
}
```

### Pact Magic (Warlock)

Pact Magic is a D&D 5e mechanic wired to a class whose `casterKind == pact`. The content package decides *which* class has pact casting — the SRD package assigns it to `srd:warlock`. The progression table below is structural.

Stored separately from Spellcasting slots. Different progression:

```dart
class PactMagicTable {
  static const List<({int slots, int slotLevel})> _table = [
    (slots: 1, slotLevel: 1),    // L1
    (slots: 2, slotLevel: 1),
    (slots: 2, slotLevel: 2),
    (slots: 2, slotLevel: 2),
    (slots: 2, slotLevel: 3),
    (slots: 2, slotLevel: 3),
    (slots: 2, slotLevel: 4),
    (slots: 2, slotLevel: 4),
    (slots: 2, slotLevel: 5),
    (slots: 2, slotLevel: 5),    // L10
    (slots: 3, slotLevel: 5),
    (slots: 3, slotLevel: 5),
    (slots: 3, slotLevel: 5),
    (slots: 3, slotLevel: 5),
    (slots: 3, slotLevel: 5),
    (slots: 3, slotLevel: 5),
    (slots: 4, slotLevel: 5),
    (slots: 4, slotLevel: 5),
    (slots: 4, slotLevel: 5),
    (slots: 4, slotLevel: 5),    // L20
  ];

  static ({int slots, int slotLevel}) forLevel(int warlockLevel) =>
    _table[warlockLevel - 1];
}
```

Pact slots refresh on **Short Rest** (Warlock-specific rule).
Spellcasting slots refresh on **Long Rest**.

Both can cast each other's prepared spells (per rule §17.5 Pact Magic + Spellcasting Interaction).

## Concentration Manager

```dart
// flutter_app/lib/application/dnd5e/spell/concentration_manager.dart

class ConcentrationManager {
  /// Compute concentration save DC after taking damage.
  /// DC = max(10, floor(damage / 2)), capped at 30.
  int saveDcForDamage(int damage) {
    final calculated = math.max(10, (damage / 2).floor());
    return math.min(30, calculated);
  }

  /// Returns true if concentration is broken.
  bool checkConcentration({
    required Combatant target,
    required int damage,
    required ContentRegistry registry,
    required EffectCompiler compiler,
  }) {
    if (target.concentration == null) return false;
    // Read "incapacitated" tag from compiled ConditionInteraction descriptors,
    // not from a hardcoded Condition enum match.
    final incapacitated = target.conditionIds.any((id) {
      final cond = registry.conditions[id];
      return cond != null && compiler.conditionInteraction(cond).incapacitated;
    });
    if (incapacitated) return true;
    if (target.isDead) return true;
    final dc = saveDcForDamage(damage);
    final save = Dice.d20() + target.savingThrowMod(Ability.constitution);
    return save < dc;
  }

  /// Set new concentration. Returns updated Combatant with prior concentration ended.
  Combatant startConcentration(Combatant c, Concentration newConc) {
    return c.copyWith(concentration: newConc);
  }

  Combatant endConcentration(Combatant c) {
    return c.copyWith(concentration: null);
  }
}
```

When concentration ends:
- Notify all `affectedCombatantIds` to remove the spell's effect.
- UI shows toast: "Concentration on [Spell] broken."

## Spell Casting Validator

Pre-cast checks:

```dart
class SpellCastValidator {
  /// Returns null if valid; else error message.
  String? validate({
    required Character caster,
    required Spell spell,
    required int? slotLevelChosen,    // null = cantrip or non-slot
    required CastingMethod method,    // normal | ritual | always-prepared
  }) {
    if (spell.level == SpellLevel.cantrip) return null;

    if (method == CastingMethod.ritual) {
      if (!spell.ritual) return 'Spell is not a ritual';
      if (!_isPreparedOrInBook(caster, spell)) return 'Spell not available for ritual';
      return null;
    }

    if (slotLevelChosen == null) return 'Slot level must be chosen';
    if (slotLevelChosen < spell.level.value) return 'Slot too low';
    if (slotLevelChosen > 9) return 'Slot level invalid';

    final available = caster.spellSlots.byLevel(slotLevelChosen);
    if (available.current < 1) return 'No slots remaining at level $slotLevelChosen';

    if (!_isPrepared(caster, spell)) return 'Spell not prepared';

    // Component checks (V/S/M).
    if (spell.components.any((c) => c is VerbalComponent) && _silenced(caster)) {
      return 'Cannot cast Verbal spell while silenced or unable to speak';
    }
    if (spell.components.any((c) => c is SomaticComponent) && !_freeHand(caster)) {
      return 'Cannot cast Somatic spell without a free hand';
    }
    final material = spell.components.whereType<MaterialComponent>().firstOrNull;
    if (material != null) {
      if (material.consumed && !_hasMaterial(caster, material)) {
        return 'Missing required material: ${material.description}';
      }
      if (!material.consumed && !(_hasFocus(caster) || _hasComponentPouch(caster) || _hasMaterial(caster, material))) {
        return 'Need a focus, pouch, or the specific material';
      }
    }

    // One-leveled-spell-per-turn rule (only matters mid-combat).
    // (Tracked in TurnState.appliedThisTurn.)

    return null;
  }
}
```

## Casting Pipeline

```dart
class SpellCastService {
  Future<SpellCastResult> cast({
    required Character caster,
    required Spell spell,
    required int? slotLevel,
    required List<TargetSpec> targets,
    required CastingMethod method,
  }) async {
    final err = validator.validate(...);
    if (err != null) throw SpellCastException(err);

    // 1. Expend slot (or pact slot, if used).
    final updatedCaster = method == CastingMethod.ritual
      ? caster
      : _expendSlot(caster, slotLevel!);

    // 2. Set concentration if needed.
    final withConc = spell.duration is ConcentrationDuration
      ? _setConcentration(updatedCaster, spell)
      : updatedCaster;

    // 3. Resolve effects (delegated to attack/save/damage resolvers).
    final results = <SpellEffectResult>[];
    for (final fx in spell.effects) {
      results.add(await _resolveEffect(fx, withConc, targets, slotLevel ?? spell.level.value));
    }

    return SpellCastResult(updatedCaster: withConc, effectResults: results);
  }
}
```

**MVP scope:** in manual mode, the cast service only validates and decrements slots. It does NOT auto-roll attack/damage. UI offers buttons to roll those manually. (See [24](./24-player-action-protocol.md) for player commit flow.)

## AoE Geometry

```dart
// flutter_app/lib/domain/dnd5e/spell/area_of_effect.dart

sealed class AreaOfEffect {
  bool includesOrigin();
  /// Returns set of grid cells affected (in grid space; convert to ft via 5 ft/cell).
  Set<GridCell> coverage(GridCell origin, GridDirection direction);
}

class ConeAoE extends AreaOfEffect {
  final double lengthFt;
  @override bool includesOrigin() => false;     // unless creator specifies
  @override Set<GridCell> coverage(origin, dir) {
    // Cone width at distance d = d ft.
    // Walk grid from origin along direction; at each row, include 2*ceil(d/5)+1 wide span.
  }
}

class CubeAoE extends AreaOfEffect {
  final double sideFt;
  @override bool includesOrigin() => false;
  @override Set<GridCell> coverage(origin, dir) {
    // Pick anchor face = origin; extrude side ft in direction.
  }
}

class SphereAoE extends AreaOfEffect {
  final double radiusFt;
  @override bool includesOrigin() => true;
  @override Set<GridCell> coverage(origin, _) {
    // All cells within radius (Euclidean or Chebyshev — pick one and document).
  }
}

class CylinderAoE extends AreaOfEffect {
  final double radiusFt;
  final double heightFt;     // 2D map: ignored
  @override bool includesOrigin() => true;
}

class LineAoE extends AreaOfEffect {
  final double lengthFt;
  final double widthFt;
  @override bool includesOrigin() => false;
}

class EmanationAoE extends AreaOfEffect {
  final double distanceFt;
  @override bool includesOrigin() => false;
}
```

**Distance metric:** SRD §8.2 says "count squares from a square adjacent to one creature to a square adjacent to the other (shortest route)." This is Chebyshev for grid combat. Use Chebyshev for sphere coverage on a grid.

**Total Cover blocks line of effect:** AoE coverage must filter by raycast: for each candidate cell, draw line from origin → cell; if any blocking obstacle intersects, exclude cell. (MVP: optional. DM can manually deselect targets.)

## UI: AoE Preview Widget

In battlemap layer (added per [33](./33-battlemap-interaction-spec.md)):

```dart
class AoEPreviewOverlay extends StatelessWidget {
  final AreaOfEffect aoe;
  final GridCell origin;
  final GridDirection direction;     // for Cone/Line/Cube
  final Color previewColor;          // semi-transparent
  ...
}
```

Player flow:
1. Open spell from spell list.
2. Tap "Cast" → battlemap overlay activates.
3. Tap origin point → AoE preview rendered.
4. Drag direction handle (for Cone/Line/Cube).
5. Confirm → broadcast marker via [24](./24-player-action-protocol.md).

## Slot Refresh on Rest

```dart
class SpellSlotRefreshService {
  Character afterShortRest(Character c, ContentRegistry registry) {
    // Wizard Arcane Recovery handled separately (interactive: choose slots).
    // Any class with casterKind == pact refreshes pact slots on short rest.
    for (final lvl in c.classLevels) {
      final cls = registry.classes[lvl.classId];
      if (cls != null && cls.casterKind == CasterKind.pact) {
        final pact = PactMagicTable.forLevel(lvl.level);
        return c.copyWith(pactSlots: PactMagicSlots(current: pact.slots, max: pact.slots, slotLevel: pact.slotLevel));
      }
    }
    return c;
  }

  Character afterLongRest(Character c) {
    final fresh = _recomputeMaxSlots(c);   // also restores pact
    return c.copyWith(spellSlots: fresh.spellSlots, pactSlots: fresh.pactSlots);
  }
}
```

## Acceptance

- Single-class spellcaster L1-L20: slots from the structural progression table, driven by the SRD package's class `casterKind` + `casterFraction`.
- Multiclass (e.g., `srd:wizard` 5 + `srd:cleric` 3): slots match the progression at combined caster level 8.
- `srd:warlock` 5: 2 slots at slot level 3, refresh on Short Rest (driven by `casterKind == pact`).
- A homebrew class package with `casterKind: full, casterFraction: 1.0` produces identical slot math to SRD full-casters.
- Concentration broken on damage: CON save with DC = max(10, dmg/2) ≤ 30.
- Casting ritual spell: no slot expended, +10 min duration noted.
- AoE shapes render correctly on grid for Cone (15/30/60 ft), Cube (5/10/15 ft), Sphere (10/20/30 ft), Line (30 ft).
- One-leveled-spell-per-turn rule: enforced in turn state tracking.
- `flutter test` covers slot tables + multiclass calc + concentration DC formula.

## Open Questions

1. Sphere distance metric on grid: Chebyshev (8-direction) vs Euclidean (true circle)? → **Chebyshev** per SRD grid rules.
2. AoE direction choice for Cube — pick face direction, or 8 corners? → Face direction (4 options on 2D map). Keeps UI simple.
3. Concentration auto-save vs prompt? → MVP: prompt DM to confirm. Auto-roll button available.
