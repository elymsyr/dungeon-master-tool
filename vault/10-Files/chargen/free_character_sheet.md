---
type: file-note
domain: chargen
path: flutter_app/lib/presentation/screens/characters/free_character_sheet.dart
layer: presentation
language: dart
status: active
updated: 2026-10-13
tags: [file]
---

# `free_character_sheet.dart`

> [!abstract] Primary Purpose
> The character sheet of a free template character (`docs/free-template/DESIGN.md` §10.2, D40, ROADMAP Faz 6, Faz 7a): the built-in character screen's look — portrait, name, "template · world", description, summary chips, view / edit, undo / redo, save & sync, DM notes, section jump pad, dice button — with the player card's own groups drawn by the ordinary field widgets, **Level up**, **Short rest** / **Long rest**, and what the character's cards grant (§11) — cards into lists, the Pool. It is a separate screen (ROADMAP K3): the built-in [[character_editor_screen]] only routes here (and lends its public `CharacterSaveSyncButton` / `CharacterSaveSyncDialog`); none of its rules (resolved grants, class resource tracker, derived AC / HP, wizard) exist on this path. Its companion `application/providers/free_character_provider.dart` finds the schema and creates the character.

## Inputs / Outputs
**Inputs**
- `characterId`, the `WorldSchema` to draw with, optional `onClose` (embedded in the DM sidebar / player tab).
- `characterByIdProvider` (outside changes, e.g. the encounter writing HP, are taken only while no local edit is pending); `entityProvider` when the character's world is the open one (card links), else no cards.

**Outputs**
- Edits → `_edit` (undo baseline, coalesced after 400 ms like the built-in editor) → `pendingWriteBufferProvider.schedule(key: 'character:$id', kind: shortText)` → `characterListProvider.update`, only when the user may edit (owner or the online world's DM — the built-in `_canEdit`); close flushes that key and saves under the global loading overlay.
- Rest → [[free_field_styles]] `restPatch` over the player card's fields plus [[free_grants]] `poolAfterRest` for the Pool's resources, then a snackbar.
- A card link list change, Level up and the levels dialog go through [[free_grants]] `settleGrants`: granted cards join their lists (labelled), a summary dialog shows what came (always after a level up), and labelled cards nothing grants any more are offered for removal (V12).
- `freeReachedLevelsProvider` (in `free_character_provider.dart`): the open character's reached levels by card id, **only for the cards opened from the sheet** (its body is an [[entity_link]] `EntityOpenScope`; `_opened` collects the ids), written after a frame, cleared in `deactivate`; `entity_card.dart` marks a Level table's reached rows from it (DESIGN §11.8). A card opened from the sidebar shows no marks.

`free_character_provider.dart`:
- `readWorldSchema(db, worldId)` — a world's own copy (`world_settings._world_schema`) without opening it.
- `freeCharacterSchemaProvider((worldId, templateId))` — the schema a free character is drawn with (DESIGN §18): the open world's live `worldSchemaProvider`, another world's stored copy, or — worldless — the free template from `userTemplatesProvider`; null for a built-in character.
- `createFreeCharacter(notifier, schema:, name:, worldId:)` — `CharacterListNotifier.create` with [[free_template]] `freeCharacterSeed` (level 1, D35).

## Dependencies & Links
- Depends on: [[free_field_styles]], [[free_template]] (`freePlayerCard`, `characterLevelOf`, `freeCharacterSeed`), [[template_edit]] (`fieldsIn`, `sortedGroups`), `field_widget_factory.dart`, `entity_card.dart` (`EntityCardCollapsibleGroupCard`, `splitFieldRows`), [[pending_write_buffer]]
- Used by: [[character_editor_screen]] (gate: `templateId != builtinDnd5eV2SchemaId` and the provider gives a free schema), `character_add_menu.dart` (in a free world "Create" makes a blank character and opens it), the creation wizard (picking a free world or a free template says there is no wizard — `freeNoWizardTitle` / `freeNoWizardBody`, Cancel / Continue — then leaves it for a blank sheet)
- Domain map: [[Character-System]]
- Spec / reference: `docs/free-template/DESIGN.md` §10.2, §12.3, §18; `docs/free-template/ROADMAP.md` Faz 6

## Key Logic / Variables
- **Layout:** parchment, centred at 760 px, lazy rows: header (200×260 portrait — picked in edit mode, its replaced cloud copy cleaned up —, red serif name, subtitle that opens the world, markdown description, `CharacterStatChips` from `freeChipLines` — the player card's summary chips, [[free_template]] `sheetChipsOf`), the action row, ungrouped fields under "Properties", each group in template order as a collapsible group card (`gridColumns` columns on desktop / tablet, one on a phone, a field as wide as its span), DM notes. Group names and labels go through the SRD content translator like the built-in sheet. Opens in view mode; the toggle needs edit rights.
- **Play fields in view mode** (Faz 7a+): fields go through the factory with `play: true`, so a checkbox, a Resource's current value / boxes, the Pool's resources and the combat block's HP and editable numbers change without edit mode; names, text, maxima, lists and structure stay edit-mode only.
- **Values** go through `freeFieldValue`, so an SRD shape the copy replaced still shows.
- **Action row** (works in view mode too, as the built-in one): [Level up] only with a Level field (D34) → `free_level_dialogs.dart`: one pick per separate category with own cards (V13: a single card is picked), "+ add a new one" joins at 1; then `levelUp` + `settleGrants` + the summary. [Short rest], [Long rest]. In edit mode tapping the Level field opens the levels dialog (main level, own separate cards' levels). [Guide] arrives in Faz 8.
- **Level field** is read-only on the sheet: a level changes only through those dialogs, so a typed intermediate value never takes cards back.
- **Captions** under listed cards: "From X · level N" (granted) or "Level N" (own card in a separate category), through the field factory's `itemCaptions`.
- Without the world's cards (world closed) nothing is granted or taken back; Level up and the levels dialog are disabled.
- **Rest** touches every Resource field and the combat block's HP, nothing else (DESIGN §12.3); hit-dice healing and the like are the player's (§12.4).

## Notes
- The hub's Characters tab loads the character's world by id before opening (it used the world's name, so the world never loaded and the sheet had no cards); a world missing on disk still leaves the sheet without them.
- Tests: `test/presentation/free_character_sheet_test.dart` (world character on the world's copy at level 1; built-in world → not free; worldless → template; editor routes to this sheet; short rest leaves HP, long rest fills it; Faz 7a: Level up grants Action Surge, the summary lists it, it is captioned with its giver and level; the Level and HP summary chips; HP typed in view mode saves). Factory-level play checks: `test/presentation/free_play_fields_test.dart`.
