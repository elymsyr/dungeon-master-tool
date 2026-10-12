---
type: file-note
domain: chargen
path: flutter_app/lib/presentation/screens/characters/free_character_sheet.dart
layer: presentation
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `free_character_sheet.dart`

> [!abstract] Primary Purpose
> The character sheet of a free template character (`docs/free-template/DESIGN.md` §10.2, ROADMAP Faz 6): the player card's own layout drawn with the ordinary field widgets, the main level in the header, and **Short rest** / **Long rest**. It is a separate screen (ROADMAP K3): the built-in [[character_editor_screen]] only routes here, and none of its parts (resolved grants, class resource tracker, derived AC / HP, wizard) exist on this path. Its companion `application/providers/free_character_provider.dart` finds the schema and creates the character.

## Inputs / Outputs
**Inputs**
- `characterId`, the `WorldSchema` to draw with, optional `onClose` (embedded in the DM sidebar / player tab).
- `characterByIdProvider` (outside changes, e.g. the encounter writing HP, are taken only while no local edit is pending); `entityProvider` when the character's world is the open one (card links), else no cards.

**Outputs**
- Edits → `pendingWriteBufferProvider.schedule(key: 'character:$id', kind: shortText)` → `characterListProvider.update`; close flushes that key first (same key the built-in editor's `dispose` flushes).
- Rest → [[free_field_styles]] `restPatch` over the player card's fields, then a snackbar.

`free_character_provider.dart`:
- `readWorldSchema(db, worldId)` — a world's own copy (`world_settings._world_schema`) without opening it.
- `freeCharacterSchemaProvider((worldId, templateId))` — the schema a free character is drawn with (DESIGN §18): the open world's live `worldSchemaProvider`, another world's stored copy, or — worldless — the free template from `userTemplatesProvider`; null for a built-in character.
- `createFreeCharacter(notifier, schema:, name:, worldId:)` — `CharacterListNotifier.create` with [[free_template]] `freeCharacterSeed` (level 1, D35).

## Dependencies & Links
- Depends on: [[free_field_styles]], [[free_template]] (`freePlayerCard`, `characterLevelOf`, `freeCharacterSeed`), [[template_edit]] (`fieldsIn`, `sortedGroups`), `field_widget_factory.dart`, `entity_card.dart` (`EntityCardCollapsibleGroupCard`, `splitFieldRows`), [[pending_write_buffer]]
- Used by: [[character_editor_screen]] (gate: `templateId != builtinDnd5eV2SchemaId` and the provider gives a free schema), `character_add_menu.dart` (in a free world "Create" makes a blank character and opens it), the creation wizard (picking a free world or a free template leaves the wizard for a blank sheet)
- Domain map: [[Character-System]]
- Spec / reference: `docs/free-template/DESIGN.md` §10.2, §12.3, §18; `docs/free-template/ROADMAP.md` Faz 6

## Key Logic / Variables
- **Layout:** name field; ungrouped fields; then each group in template order as a collapsible group card, `gridColumns` columns on desktop / tablet and one on a phone, a field as wide as its span (short rows padded).
- **Values** go through `freeFieldValue`, so an SRD shape the copy replaced still shows.
- **Header:** "Level N" from the player card's Level field — nothing when the template deleted it (D34). [Level up] arrives in Faz 7, [Guide] in Faz 8.
- **Rest** touches every Resource field and the combat block's HP, nothing else (DESIGN §12.3); hit-dice healing and the like are the player's (§12.4).

## Notes
- Known limit: a sheet opened from the hub while its world is closed has no world cards for its card links (names of stored soft refs still show).
- Tests: `test/presentation/free_character_sheet_test.dart` (world character on the world's copy at level 1; built-in world → not free; worldless → template; editor routes to this sheet; short rest leaves HP, long rest fills it).
