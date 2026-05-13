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

## 6. Implementation Log

### 2026-05-13 — PR-A2 + PR-A3 shipped

**PR-A2 — Sheet display with source labels.**
- `EffectiveCharacter` gained `grantSources: Map<String, List<String>>` (id → ordered list of source names).
- `CharacterResolver` populates per-id via `noteSource(id, source)` at every site that adds to `senses` / `damageResistanceIds` / `damageImmunityIds` / `damageVulnerabilityIds` / `conditionImmunityIds`. Source tag form `kind:name` (`species:Dwarf`, `subclass:Berserker`) is stripped to a clean display label via `cleanSource`. Subspecies tags (`subspecies:Dwarf/Hill`) collapse to `Hill Dwarf`.
- `pendingFeatureEffects` reshaped to `List<({Map<String, dynamic> eff, String source})>` so feature-row effects carry their owning class/subclass through Pass 4.
- `ResolvedGrantsCard` renders chip label `<grant> — <sources joined by ', '>` (e.g. "Poison — Dwarf"). Falls back to plain name when source data missing.

**PR-A3 — Level-up subclass-pick parity.**
- `absorbFeatureRowsInRange` in `character_editor_screen.dart` now takes a `fullWindow` flag. Class side uses the (fromLvl, toLvl] slice (unchanged). Subclass side calls with `fullWindow: true` so a first-time subclass pick at L3 (or class-defined gate) absorbs every previously-gated row, not just the row whose level equals the new character level. Idempotency (`existing.contains(id)`) keeps repeat absorption safe.
- Added `absorbTopLevelGrants(subclassEntity)` block — top-level `granted_*` fields on the subclass entity (not per-feature rows) now land at level-up. Closes the gap where a subclass picked after wizard finalize never delivered its top-level resistances/immunities/senses.

All 485 tests green. `dart analyze` clean against touched files (3 pre-existing `unused_element` warnings in `feats_class.dart` unrelated to this work).

### 2026-05-13 — PR-B2 shipped

**SpellcastingProgressionEditor + override pipeline.**

- New `FieldType.spellSlotProgression` (`field_schema.dart`) — 2D slot grid keyed by `Map<level, Map<spellLevel, count>>` with JSON-friendly stringified keys.
- Class schema `spell_slots_by_level` (`content.dart:367`) switched from generic `levelTable` (which only held a single int per level) to `spellSlotProgression` so authors can override slot counts per character level × spell level. Helper `fb.spellSlotProgression(k, l)` added to the schema builder.
- `caster_progression.dart` gained `slotsByLevelOverride(raw, level)` (parses the 2D map into the per-level slot count map) and `spellSlotsForClass(cls, level)` (override first, SRD preset fallback). Both are dependency-free helpers tested via `caster_progression_test.dart` (14 new assertions).
- Callers wired: `character_creation_wizard_screen.dart` finalize path uses `spellSlotsForClass`; `level_up_planner.dart` collapses its inline `_slotsAt` into the shared helper (`kind` arg dropped from private signature).
- Multiclass blend in `multiclass_helper.dart` deliberately stays on the SRD full-caster table — that's the SRD §1.10 prescription, not an author-overridable curve.
- New `_SpellSlotProgressionFieldWidget` renders a 20-row × 9-column DataTable with placeholder hints from the `caster_kind` SRD preset. "Auto-fill SRD" button seeds the grid; "Clear" wipes the override and falls back to runtime defaults. Each cell is a small `TextField` accepting an int (0 / empty clears that cell). Read-only mode honored.

All 495 tests green (10 newly added — 4 over `slotsByLevelOverride`, 5 over `spellSlotsForClass`, 1 over the SRD parity fallback). `dart analyze` baseline unchanged (3 pre-existing warnings).

### 2026-05-13 — PR-B3 shipped (EquipmentChoiceGroupEditor authoring)

`EquipmentChoiceGroupsFieldWidget` (`structured_list_field_widgets.dart:1166`) was read-only — entity card just rendered the groups so it didn't dump raw maps. Authors had no way to create new "Choose A or B" groups outside the wizard's runtime picker. Now fully editable:

- Top-level `+ Add Group` button. Each group gets an auto-generated `group_id` (`grp-<ms36>`), editable `label` + `prompt`, per-group delete button.
- Per-group `+ Add Option` button. Each option carries auto-generated `option_id` (`opt-<ms36>`), editable label, optional `gold_gp` int, per-option delete.
- Per-option `+ Add Item` button. Items pick an entity via `_MiniRelationField` (reuses `showEntitySelectorDialog`) constrained to `_kItemPickAllowedTypes` — adventuring-gear / weapon / armor / tool / pack / ammunition, matching the schema's `default_inventory_refs` registry. Quantity is a small int field defaulted to 1.
- Read-only path preserves the original display (no edit affordances). Field-widget factory now passes `ref` so the dialog can route through the active Riverpod scope.

No tests added — the widget's structure-only edits live behind UI affordances best validated via integration tests; the data shape round-trips through the same `_coerceGroups` helper the read-only path already exercises. All 495 existing tests still green; `dart analyze` clean on touched files.

### 2026-05-13 — PR-B7 shipped (SubspeciesEditor authoring)

`subspecies_options` on species was declared as `markdown` and rendered read-only in the entity card. Custom species couldn't author lineage rows.

- New `FieldType.subspeciesOptions`. Schema field type promoted (`content.dart:459`). Helper `fb.subspeciesOptions(k, l)` added.
- `SubspeciesOptionsFieldWidget` in `structured_list_field_widgets.dart` — `ExpansionTile` per row, name/description text fields, 11 relation-list pickers (senses / 4 damage-type lists / condition_immunities / languages / skills / actions / bonus_actions / reactions / traits) backed by a reusable `_RelationListChips` helper that chips out existing values and routes "+ Add" through `showEntitySelectorDialog`. Read-only mode keeps the existing display.
- The `_RelationListChips` helper sits next to the subspecies widget but is general-purpose — drop-in replacement anywhere a structured row carries multi-relation grant lists.

All 495 tests green. `dart analyze` clean on touched files.

### 2026-05-13 — PR-B6 shipped (RaceTraitsEditor consolidated layout)

Species fields were all rendered in a flat two-column dump under a single `grpIdentity` group. Authors had to scroll through senses / resistances / actions / lineages without visual grouping. Reorganized into six semantic field groups (`content.dart:431`):

1. **Identity** — size, creature type, lifespan.
2. **Movement** — five speed fields (walk + 4 specialised).
3. **Senses & Languages** — granted senses / languages.
4. **Resistances & Immunities** — damage resistances / immunities / vulnerabilities + condition immunities.
5. **Traits & Actions** — trait refs, granted action / bonus-action / reaction refs, skill proficiencies, granted modifiers DSL.
6. **Lineage Options** — `subspecies_options` (the PR-B7 editor).

No schema-shape changes; pure layout. All 495 tests still green; `dart analyze` clean.

### 2026-05-13 — PR-B13 shipped (CR Calculator)

DMG p.273-275 monster CR estimator. Two halves:

- **Pure helpers** in `flutter_app/lib/application/character_creation/cr_calculator.dart` — `defensiveCrFromAcHp(ac, hp)`, `offensiveCrFromAtkDpr(atkBonus, dpr)`, `combinedCr(defCr, offCr)`, `xpForCr(cr)`. Defensive table is keyed on HP brackets with the expected AC for that bracket; ±2 AC from the bracket's expected value shifts the result one CR step. Offensive table mirrors with DPR + attack bonus. Combined CR averages defensive + offensive in numeric CR space (1/8 → 0.125, 1/4 → 0.25, …) then snaps to the nearest canonical ladder notch. XP lookup is the SRD canonical table.
- **Field widget**: new `FieldType.crCalculator` + `_CrCalculatorFieldWidget` (`field_widget_factory.dart`). Reads `ac` + `hp_average` from `entityFields`, stores `{atk_bonus, dpr_avg, save_dc}` as its own value, renders Defensive / Offensive / Suggested CR + XP. Author copies the suggestion into the existing `cr` + `xp` fields by hand — field widgets don't write to sibling keys.
- Monster schema gains a `cr_helper` field declared in `grpMeta` (`content.dart:996`) so the calculator sits next to the SRD CR / XP / proficiency_bonus fields.

14 new pure-function tests in `test/application/character_creation/cr_calculator_test.dart` lock the bracket math. All 509 tests green; `dart analyze` clean on touched files.

---

**B-stream summary** — As of 2026-05-13 every PR-B# either ships (B1, B2, B3, B5, B6, B7, B9, B11, B12, B13 via dedicated widgets / pure helpers) or shipped earlier via generic schema fields (B4, B8, B10, B14). No remaining gaps from the original 14-item list.

## 7. Out of Scope

- Cross-system templates (Pathfinder/13th Age).
- Homebrew sharing/export.
- Visual rule scripting (turing-complete DSL). Effect DSL stays declarative.
