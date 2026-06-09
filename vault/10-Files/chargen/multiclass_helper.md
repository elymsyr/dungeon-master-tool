---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/multiclass_helper.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `multiclass_helper.dart`

> [!abstract] Primary Purpose
> Pure SRD §1.10 multiclass helpers: prerequisite checking (`checkMulticlassPrereq`), total character level, multiclass-caster detection, and the blended Multiclass Spellcaster slot table (`combinedCasterLevel` + `multiclassSpellSlotsFor`).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — top-level functions + the `MulticlassPrereq` result struct.
- Reads: caller-supplied `Entity classEntity`, `Map<String,Entity> entities`, `Map<String,int> abilityScores`, `Map<String,int> classLevels`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `MulticlassPrereq checkMulticlassPrereq({...})`, `int totalCharacterLevel(classLevels)`, `bool isMulticlassCaster({...})`, `Map<int,int>? multiclassSpellSlotsFor({...})`, `int combinedCasterLevel({...})`.

## Dependencies & Links
- Depends on: `entity.dart`, [[caster_progression]] (`CasterKind`, `defaultSpellSlotsByLevel`).
- Used by: the character editor's multiclass add-class flow (confirmation banner) + spell-slot display.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1.10

## Key Logic / Variables
- `checkMulticlassPrereq`: reads `multiclass_prereq_ability_refs` (ability entity ids/inline names), `multiclass_prereq_min_score` (default **13**), `multiclass_prereq_any_of` (bool). Default semantics = **AND** all listed abilities; `any_of: true` = OR (Fighter STR-or-DEX, Monk DEX-or-WIS). `abilityScores` keys accepted as uppercase ('STR') or full name ('Strength') via `_abbrevFor`. Returns `{met, reason}` — never blocks; the editor shows a confirmation banner. Only the **entry** prereq is enforced (leaving-class prereq skipped).
- `totalCharacterLevel`: sum of all `classLevels` values (= character level for PB/ASI/feats).
- `isMulticlassCaster`: ≥2 classes whose `caster_kind` is full/half/third (Pact/Warlock excluded).
- `combinedCasterLevel` (SRD multiclass spellcaster level): full = +level; half = `+level~/2` from L2; third = `+level~/3` from L3; pact = not folded in.
- `multiclassSpellSlotsFor`: returns the **full-caster** slot map at `combinedCasterLevel` (via `defaultSpellSlotsByLevel(CasterKind.full, lvl)`); `null` for 0-or-1 caster classes (single-class planner progression is correct then).

## Notes
- Warlock pact slots are always evaluated separately — never blended into the combined table.
