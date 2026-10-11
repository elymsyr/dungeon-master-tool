---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/template_edit.dart
layer: domain
language: dart
status: active
updated: 2026-10-11
tags: [file]
---

# `template_edit.dart`

> [!abstract] Primary Purpose
> The pure edits behind the free template editor (`docs/free-template/DESIGN.md` §6.6, §7): fields, groups and categories in and out, reordering, field keys, and the style-change compatibility rule. Every function returns a new value; ids and timestamps come from the caller, so it is fully unit-tested without UI.

## Inputs / Outputs
**Inputs**
- An `EntityCategorySchema` (field / group edits) or a `WorldSchema` (category edits), plus ids, labels and an ISO timestamp.

**Outputs**
- `simpleFieldTypes` (the palette's 14 styles, DESIGN §8), `isSimpleFieldType`, `canBeList`.
- `keyFromLabel(label, taken, {separator, fallback})` — folded ASCII words, `_2`/`_3` on a clash. Field keys use `_`, category slugs `-`.
- Fields: `fieldsIn(cat, groupId)`, `addField`, `moveField`, `removeField`, `replaceField`.
- Style change: `typeChangeOf(from, fromList, to, toList)` → `TypeChange.same | compatible | lossy | incompatible`; `changeFieldType(...)`.
- Groups: `sortedGroups`, `addGroup`, `replaceGroup`, `moveGroupFields`, `removeGroup`, `reorderGroups`.
- Categories: `canRemoveCategory`, `addCategory`, `removeCategory`, `replaceCategory`, `reorderCategories(schema, orderedIds)`.

## Dependencies & Links
- Depends on: [[world_schema]], [[entity_category_schema]], [[field_schema]]
- Used by: [[free_template_editor]] (through `TemplateEditController`)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/ROADMAP.md` Faz 2

## Key Logic / Variables
- **Keys never change (V3):** a field key is made once from the label it was created with; renaming touches only `label`.
- **Field order:** `orderIndex` is renumbered over buckets (ungrouped first, then groups in order). The card sorts by `orderIndex` inside each group, so only the in-group order matters. A field pointing at a missing group is treated as ungrouped (`_buckets`), so an edit never drops it.
- **Compatibility (DESIGN §6.6):** text/long text/markdown among themselves, integer → decimal, choice → text, single → list of the same style are `compatible`; relation list → single is `lossy` (first card kept); everything else `incompatible`. An incompatible change retires the field and adds a new one in the same slot with a new id and key (V4); the old key also leaves `filterFieldKeys`.
- **Groups:** removing a group moves its fields (default: ungrouped "Properties"); fields are never deleted with a group.
- **Player card:** `canRemoveCategory` is false for `isPlayerCard == true`; `removeCategory` ignores it.
- New categories get a unique slug, `workspaces` icon, a blue colour and sections `worldmap`, `mindmap`, `projection` (encounter is Faz 9).

## Notes
- Test: `test/domain/services/template_edit_test.dart` (includes "every SRD copy category survives a move").
- A retired key is not remembered: a later field with the same label could get the old key back (and its hidden old-style data). Matters once worlds use free templates (Faz 3).
