# Custom Content Editor & Granted Modifier Loading — Roadmap

Date: 2026-05-13
Scope: D&D 5e template/world editors + character creation grant pipeline.

## 1. Executive Summary

Two-front gap:

1. **Editor gap** — Users can create entities (class/race/background/feat/spell/item/monster) as generic database rows, but specialized SRD-aware editors are missing. Complex mechanics (per-level features, feat effect DSL, subclass progression, creature actions) must be filled via raw JSON-like fields without domain guidance.
2. **Runtime gap** — Wizard finalize copies only race grants onto the new character. Class/subclass-granted resistances, immunities, senses, condition immunities, AC bonuses, speed bonuses, racial feat effects never reach the saved character record. CharacterResolver runs against missing source refs → effective sheet stays empty.

Both must ship together: an editor that defines features is useless if the runtime never applies them.

## 2. Runtime Bug — Granted Modifiers Not Loading

### 2.1 Symptom

New PC created via wizard. Picked class = Barbarian (rage damage resistance), subclass slotted, race = Dwarf (poison resistance, darkvision).
Result on sheet: no resistances, no darkvision, no condition immunities. Class/subclass features absent.

### 2.2 Root cause

File: `flutter_app/lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`

`_buildSeedFields()` at lines 930–959 only walks `race` for granted refs. Class + subclass skipped entirely.

Resolver (`character_resolver.dart`) correctly applies feature effects when source refs exist on the character entity. But seed never writes them, so resolver has nothing to resolve.

### 2.3 Missing data flow

| Source field on class/subclass | Target field on character | Status |
|---|---|---|
| `granted_damage_resistances` | `resistance_refs` / `damage_resistances` | NOT COPIED |
| `granted_damage_immunities` | `damage_immunities` | NOT COPIED |
| `granted_condition_immunities` | `condition_immunities` | NOT COPIED |
| `granted_senses` | `senses` | NOT COPIED |
| `granted_modifiers` (AC/speed/save mods) | computed modifier list | NOT COPIED |
| `classFeatures[].grantedModifiers` (level ≤ draft.level) | feature_refs + modifier list | NOT COPIED |
| Race trait `granted_condition_immunities` | `condition_immunities` | NOT COPIED (only resistances handled) |

### 2.4 Fix plan

PR-A1 — extend `_buildSeedFields()`:
- Generalize `copyList(fromKey, toKeys)` helper to accept arbitrary source entity.
- Apply to: race (existing) + characterClass + subclass entity (lookup by `subclass_id`).
- Add condition_immunities + damage_immunities pairs.
- For `classFeatures`, filter `level <= draft.level`, push each feature id into `feature_refs`, then absorb each feature's `grantedModifiers`.
- For `granted_modifiers` (numeric/typed effect list), persist as `modifier_refs` or inline modifier records on the character.

PR-A2 — sheet display layer:
- Add UI binding for `damage_immunities`, `condition_immunities`, `senses` on character sheet (currently EffectiveCharacter exposes them but no widget reads).
- Show racial trait list with source label (e.g. "Poison Resistance — Dwarf").

PR-A3 — level-up dialog parity:
- When level increases, re-run grant absorption for any newly unlocked `classFeatures[].level == newLevel`.
- When subclass picked at L3 (or class-defined level), absorb its features then.

PR-A4 — tests:
- Wizard golden-path: Dwarf Barbarian → asserts poison resistance, darkvision, rage feature on sheet.
- Subclass pick at L3 → asserts subclass feature lands.
- Level-up to L5 → asserts L5 class features applied.

## 3. Editor Gap — Custom Content Builders

### 3.1 Class editor

Missing:
- Per-level feature table builder (level | name | description | grantedModifiers).
- Multiclass prereq UI (ability minimums).
- Spellcasting progression table (slot grid per level).
- Starting equipment choice group builder.
- Subclass slot definition (at which level subclass picked, which subclass-feature levels).

PR-B1 — `ClassFeatureTableEditor` widget. Rows = levels 1–20. Each row: feature add/remove, link to feat-effect DSL.
PR-B2 — `SpellcastingProgressionEditor`. Picks caster_kind, auto-fills SRD table; allow override.
PR-B3 — `EquipmentChoiceGroupEditor`. Group = "choose 1 of N", each option = item ref + qty.
PR-B4 — `MulticlassPrereqEditor`. Ability score floor map.

### 3.2 Subclass editor

Missing dedicated editor; currently generic entity form.

PR-B5 — `SubclassEditor` extends class-feature table at gated levels only. Bind to parent class via `parent_class_ref`. Validate gated level matches parent class's subclass-feature levels.

### 3.3 Race / species editor

Missing:
- Trait inheritance builder (auto-include subspecies traits).
- Darkvision range UI (numeric ft).
- Granted immunities/resistances visual selector (chip picker over damage type registry).
- Speed/size/age picker.

PR-B6 — `RaceTraitsEditor` with sectioned form: ability score increase, speed, size, languages, senses (darkvision range), resistances, immunities, traits list.
PR-B7 — `SubspeciesEditor` with parent-race ref + delta traits.

### 3.4 Background editor

Missing:
- Equipment choice group UI (same widget as PR-B3).
- Origin feat selector.
- Tool/skill proficiency choice UI.

PR-B8 — `BackgroundEditor` reusing equipment choice group widget.

### 3.5 Feat editor

Missing:
- Prerequisite UI (ability score, race, class, level).
- Feat type enum (origin / general / fighting style).
- featEffectList builder.

PR-B9 — `FeatEffectDslBuilder` — visual form for effect entries (grant proficiency, ASI, advantage on save, damage resist).
PR-B10 — `FeatPrereqEditor`.

### 3.6 Spell editor

Missing:
- Spell list category association.
- Scaling dice builder (at higher levels).
- Components UI (V/S/M with material cost).

PR-B11 — `SpellEffectEditor` with school/level/range/components/duration form + scaling table.

### 3.7 Monster editor

Missing:
- CR calculator (offensive/defensive CR formula).
- Action / reaction / legendary action organizer.
- Ability modifier auto-derive from ability scores.

PR-B12 — `StatBlockEditor` with grouped sections (actions, traits, legendary). Auto-compute modifiers + saves + skills.
PR-B13 — `CrCalculator` helper visible inside stat block editor.

### 3.8 Magic item editor

PR-B14 — `MagicItemEditor` — rarity enum, attunement bool, slot enum, effect DSL (reuse PR-B9).

### 3.9 Template / world schema editor

Template editor is read-only by design. Out of scope for this roadmap; revisit if community needs non-D&D systems.

## 4. Sequencing

Order priority by user-visible impact:

1. **PR-A1 + PR-A2** (1–2 days) — fix grant loading. Highest impact: existing SRD content suddenly works correctly on new chars.
2. **PR-A3 + PR-A4** (1 day) — level-up parity + tests.
3. **PR-B1 + PR-B5** (2–3 days) — class + subclass feature table editor. Biggest editor gap.
4. **PR-B6 + PR-B7** (1–2 days) — race/subspecies editor.
5. **PR-B8** (0.5 day) — background editor.
6. **PR-B9 + PR-B10 + PR-B11** (2–3 days) — feat + spell builders.
7. **PR-B2 + PR-B3 + PR-B4** (2 days) — class deep-detail editors.
8. **PR-B12 + PR-B13** (2–3 days) — monster builder.
9. **PR-B14** (0.5 day) — magic item editor.

Total ≈ 14–19 dev days.

## 5. Acceptance Criteria

- New Dwarf Barbarian created via wizard shows poison resistance + darkvision 60ft + Rage feature on sheet.
- New custom class with per-level feature `L1: Resilient (poison immunity)` granted via editor lands on PC at creation.
- New custom race with darkvision 120ft + cold resistance applied automatically.
- Level-up from L2 → L3 picks subclass; subclass feature appears.
- All editors round-trip: create → save → reopen → fields preserved.
- Wizard picker still merges SRD + custom entities (no regression).

## 6. Out of Scope

- Cross-system templates (Pathfinder/13th Age).
- Homebrew sharing/export.
- Visual rule scripting (turing-complete DSL). Effect DSL stays declarative.
