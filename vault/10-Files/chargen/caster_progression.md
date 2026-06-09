---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/caster_progression.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `caster_progression.dart`

> [!abstract] Primary Purpose
> Pure, Flutter-free D&D 5e caster-progression helpers. Derives spell-related caps (cantrips known, prepared/known count, max preparable spell level) and spell-slot maps from a class entity's `caster_kind`, falling back to embedded SRD §1.5 slot tables when the class entity's per-level tables aren't populated. Wired into the wizard's Spells step and the level-up planner.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — top-level functions + the `CasterKind` enum.
- Reads: caller-supplied `Entity? cls` (reads `caster_kind`, `spell_slots_by_level`, `cantrips_known_by_level`, `prepared_spells_by_level`) and an `int level`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `CasterKind` enum (`none/full/half/third/pact`), `parseCasterKind`, `levelTableValue`, `defaultCantripsKnown`, `defaultPreparedSpells`, `maxPreparableSpellLevel`, `slotsByLevelOverride`, `spellSlotsForClass`, `defaultSpellSlotsByLevel`.

## Dependencies & Links
- Depends on: `entity.dart` only.
- Used by: [[level_up_planner]], [[multiclass_helper]] (`combinedCasterLevel` calls `defaultSpellSlotsByLevel(CasterKind.full,...)`), the wizard Spells step.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1.5

## Key Logic / Variables
- `parseCasterKind`: maps the schema enum strings `'Full'/'Half'/'Third'/'Pact'` to `CasterKind`; anything else (incl. 'None'/'Ritual') → `none`.
- `levelTableValue(raw, level)`: reads an `int` out of a `Map<int,int>`-shaped (JSON-stringified keys tolerated) per-level table; null on miss so callers fall back to defaults.
- `defaultCantripsKnown`: full → 3/4/5 (by <4/<10/else); pact → 2/3/4; half/third/none → 0.
- `defaultPreparedSpells`: full = `level+3`; half = `floor(level/2)+1` from L2; third = `(level-2)~/2+1` from L3; pact = `(level+1)~/2+1`; none = 0.
- `maxPreparableSpellLevel`: full `floor((level+1)/2)` clamp 1-9; half clamp 1-5 from L2; third clamp 1-4 from L3; pact clamp 1-5; none 0.
- Embedded SRD slot tables (`const`, indexed by `level-1`): `_fullCasterSlots` (20×9), `_halfCasterSlots` (20×5), `_thirdCasterSlots` (20×4), `_pactSlots` (20×`[count, slotLevel]` — all pact slots share one level and recharge on a **short** rest).
- `slotsByLevelOverride`: reads an author override `spell_slots_by_level` (`Map<level, Map<spellLevel, count>>`, stringified keys); returns null when absent/malformed/no row; empty map distinguishes "override says zero" from "no override".
- `spellSlotsForClass(cls, level)`: override first, else `defaultSpellSlotsByLevel(parseCasterKind(...))`. `defaultSpellSlotsByLevel` returns `{spellLevel: count}` (zeros sparse-omitted); pact returns a single `{slotLevel: count}` entry.

## Notes
- Default cantrip/prepared curves are deliberately approximate "middle" values when the class entity has nothing populated; the UI surfaces a "populate the class table for exact counts" hint.
