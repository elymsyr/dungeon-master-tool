---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/template_edit.dart
layer: domain
language: dart
status: active
updated: 2026-10-22
tags: [file]
---

# `template_edit.dart`

> [!abstract] Primary Purpose
> The pure edits behind the free template editor (`docs/free-template/DESIGN.md` §6.6, §7): fields, groups and categories in and out, reordering, field keys, and the style-change compatibility rule. Every function returns a new value; ids and timestamps come from the caller, so it is fully unit-tested without UI.

## Inputs / Outputs
**Inputs**
- An `EntityCategorySchema` (field / group edits) or a `WorldSchema` (category edits), plus ids, labels and an ISO timestamp.

**Outputs**
- `simpleFieldTypes` (14 simple styles, DESIGN §8), `isSimpleFieldType`, `canBeList`; `combinedFieldTypes` (Faz 4a: `table`, `statTable`, `skillTable`; Faz 6: `resource`, `combatStats`), `paletteFieldTypes` (both lists, what the palette offers), `isLegacyFieldType` (anything else but the player card's own fields: a kept SRD type).
- Faz 7a: `combinedFieldTypes` adds `grantHolder` (Grants), `progressionTable` (Level table) and `autoResources` (the Pool — any category now, D38); `playerCardFieldTypes` is only `characterLevel`; `hasFixedKey` (Level, Pool: added under `level` / `auto_resources`, no label asked); once per category: Combat stats, Level table (V9), Pool; `hasFixedStyle` adds those and Grants. `missingOwnFields(schema)` (D34: a Level table needs the player card's Level, Grants need its Pool), `ownFieldUsers(schema, type)` (the categories a deletion lists), `addOwnField` (the warning's [Add]: first group of the player card).
- Faz 6: `playerCardFieldTypes` (`characterLevel`, `autoResources`) and their fixed keys `playerCardFieldKey`; `hasFixedStyle` (those two and `combatStats`: no style dropdown) and `switchableFieldTypes`; `canAddFieldType(cat, type)` (one combat block per category; the player card's own fields only on the player card, once each, D34); `missingPlayerCardFields(cat)` (the palette's "Player card" section). `addField` takes an optional `key`; a new combat block / combat preset starts with an empty `styleConfig` (that is what marks it free); `canAddPreset` also refuses a second combat block; `withPreset` copies `subFields` too.
- `keyFromLabel(label, taken, {separator, fallback})` — folded ASCII words, `_2`/`_3` on a clash. Field keys use `_`, category slugs `-`.
- Fields: `fieldsIn(cat, groupId)`, `addField`, `moveField`, `removeField`, `replaceField`.
- Style change: `typeChangeOf(from, fromList, to, toList)` → `TypeChange.same | compatible | lossy | incompatible`; `changeFieldType(...)`.
- Groups: `sortedGroups`, `addGroup`, `replaceGroup`, `moveGroupFields`, `removeGroup`, `reorderGroups`.
- Categories: `canRemoveCategory`, `addCategory`, `removeCategory`, `replaceCategory`, `reorderCategories(schema, orderedIds)`.
- Presets (Faz 4b, DESIGN §9): `presetsOf`, `presetById`, `presetUses`, `withPreset`, `syncPresets`, `addPreset`, `replacePreset`, `saveAsPreset`, `canAddPreset`, `addPresetField`, `unlinkField`, `copyPreset`, `removePreset`.

## Dependencies & Links
- Depends on: [[world_schema]], [[entity_category_schema]], [[field_schema]]
- Used by: [[free_template_editor]] (through `TemplateEditController`)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/ROADMAP.md` Faz 2, Faz 4b; DESIGN §9, D33

## Key Logic / Variables
- **Keys never change (V3):** a field key is made once from the label it was created with; renaming touches only `label`.
- **Field order:** `orderIndex` is renumbered over buckets (ungrouped first, then groups in order). The card sorts by `orderIndex` inside each group, so only the in-group order matters. A field pointing at a missing group is treated as ungrouped (`_buckets`), so an edit never drops it.
- **Compatibility (DESIGN §6.6):** text/long text/markdown among themselves, integer → decimal, choice → text, single → list of the same style are `compatible`; relation list → single is `lossy` (first card kept); everything else `incompatible`. An incompatible change retires the field and adds a new one in the same slot with a new id and key (V4); the old key also leaves `filterFieldKeys`, and the new field starts without the old `styleConfig`. Table and Stat table change only incompatibly.
- **Presets:** a preset is a `FieldSchema` in `WorldSchema.presets`; a bound field names it in `presetId` and takes its label, style, `styleConfig`, help, placeholder, default, validation and required flag (`withPreset`) — never its card values. `replacePreset` / `removePreset` run `syncPresets`, so every bound field follows at once; a field whose preset is gone stays as it is, unbound (V7). A bound field's **key is its own** (D33): `addPresetField` starts it with the preset's key, the SRD copy and `saveAsPreset` keep the field's key. `canAddPreset`: once per category and not over a field with the preset's key (V8). A copy gets a key from its new label.
- **Groups:** removing a group moves its fields (default: ungrouped "Properties"); fields are never deleted with a group.
- **Lv tag:** `linksLevelCards(schema, field)` — a card link (list or single) to a category with a Level table; the canvas badge and the guide's field picker use it.
- **Player card:** `canRemoveCategory` is false for `isPlayerCard == true`; `removeCategory` ignores it.
- New categories get a unique slug, `workspaces` icon, a blue colour and sections `worldmap`, `mindmap`, `projection` (encounter is Faz 9).

## Notes
- Test: `test/domain/services/template_edit_test.dart` (includes "every SRD copy category survives a move" and the preset group: a change reaches every bound field and card marks stay (E4.6), break link, delete (V7), once per category (V8), save as preset / copy).
- A retired key is not remembered: a later field with the same label could get the old key back (and its hidden old-style data). Matters once worlds use free templates (Faz 3).
