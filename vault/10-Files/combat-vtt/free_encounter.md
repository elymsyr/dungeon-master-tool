---
type: file-note
domain: combat-vtt
path: flutter_app/lib/domain/services/free_encounter.dart
layer: domain
language: dart
status: active
updated: 2026-10-22
tags: [file]
---

# `free_encounter.dart`

> [!abstract] Primary Purpose
> What a free template's session tab reads from the template instead of the built-in path's fixed keys and slugs (`docs/free-template/DESIGN.md` §14, §18; ROADMAP Faz 9): the encounter's categories, columns, sort and roll, the Conditions list and where battle maps come from. Built-in schemas pass through unchanged, so every caller can route through it (ROADMAP K3). Pure.

## Inputs / Outputs
**Inputs**
- A `WorldSchema` (its categories' Combat stats blocks and `encounterConfig`), an `Entity` card, a combatant's stats map.

**Outputs**
- `encounterSection` (`'encounter'` in `allowedInSections`), `encounterConditionsColumn` (`__conditions__`, the session table's sentinel), `builtinBattlemapFields` (`location` → `battlemaps`, `map`, `map_per_era`).
- `combatBlockOf(cat)`, `combatBlockKey(schema, slug)` — a category's free Combat stats block / its key.
- `encounterCategories(schema)` — player card always, plus every category with `encounter`.
- `encounterPreset(schema)` — the Combat stats preset `encounterConfig.combatPresetId` names (required in the editor; null = only HP).
- `encounterValues(schema)` — that preset's values, in its order; `encounterSortValue` (one of its Number / Dice values), `encounterConditionsValue`.
- `encounterConfigOf(schema)` — built-in: `schema.encounterConfig`; free: columns = sort value, other shown values (`CombatValue.encounter`), HP (−/+, always), Conditions (when the block's card list is shown); `initiativeSubField` = `sortBySubField` = the sort key (`''` = none).
- `canRollEncounter(schema)` — V18: a Dice sort value, or a Number one with `sortDice`.
- `freeCombatantValues(schema, entity)` → `(hp, maxHp, stats)`: the block read like the card (`combatStatsValue`, SRD monster flat fields), blank HP = Max HP, no block = empty HP (0 / 0).
- `freeSortSpec(schema, stats)` — the roll as a dice spec: Dice as is, Number as `sortDice+N` (just `N` without dice).
- `battlemapFieldsOf(schema)`, `battlemapImages(entity, keys)`, `isBattlemapFieldType`.

## Dependencies & Links
- Depends on: [[free_field_styles]] (`CombatStatsSpec`, `combatStatsValue`), [[free_template]] (`isFreeTemplate`), [[world_schema]] (`EncounterConfig.sortDice` / `battlemapFields`)
- Used by: [[combat_provider]], `session_screen.dart`, `add_condition_dialog.dart`, `battlemap_picker_flow.dart`, [[free_template_editor]] (`TemplateEncounterForm`), [[template_edit]] (`addCombatBlock` caller side), [[free_template]] (SRD copy defaults)
- Domain map: [[Combat-and-VTT]]
- Spec / reference: `docs/free-template/DESIGN.md` §14; `docs/free-template/ROADMAP.md` Faz 9

## Key Logic / Variables
- The columns are not stored: they come from the preset every time, so a preset edit that reaches the world (template update) changes the table.
- One preset drives the table (user decision 2026-10-22): every card's block is bound to it, so a key means the same column in every row; labels / widths come from the preset.
- The sort column is shown even when its value's "Show in the encounter" is off.
- `EncounterConfig.combatPresetId` / `sortDice` / `battlemapFields` are nullable and `includeIfNull: false` (K2): the built-in schema's JSON is unchanged.

## Notes
- Trail colour (V20) is in `battle_map_screen.dart` `_trailColor`: free → player card green, other cards their category colour, rows without a card white.
