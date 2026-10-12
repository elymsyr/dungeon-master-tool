---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_template.dart
layer: domain
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `free_template.dart`

> [!abstract] Primary Purpose
> The pure functions behind free templates (`docs/free-template/DESIGN.md`): the single gate `isFreeTemplate`, the SRD / free copy converter and the empty template. Built-in and free code paths branch only on `isFreeTemplate` (ROADMAP K3).

## Inputs / Outputs
**Inputs**
- A source `WorldSchema` (built-in or free), a new id, name and ISO timestamp.

**Outputs**
- `isFreeTemplate(schema)` — `schema.freeRootId != null`.
- `isSrdLineage(schema)` — lineage root is `builtinDnd5eV2SchemaId`.
- `builtinTier(slug)` — the codex sidebar group the built-in slug lists give a slug (0 lookups, 1 content, 2 DM; same rule as the sidebar's `_tierFor`).
- `copyAsFreeTemplate(source, id:, name:, now:)` → new free `WorldSchema`.
- `emptyFreeTemplate(id:, name:, playerCardName:, levelLabel:, poolLabel:, now:)` → template with only the player card and its two ready fields: Level (`characterLevel`, key `level`) and Pool (`autoResources`, key `auto_resources`; "Automatic resources" until Faz 7, D38) (DESIGN §10.1, D34).
- `freePlayerCard(schema)` — the `isPlayerCard` category.
- `freeCharacterSeed(playerCard)` — a new free character's values: level 1 (D35), an empty combat block.
- `characterLevelOf(playerCard, entity)` — the main level, or null when the card has no Level field.
- Summary chips (D40): `SheetChip` (`field`, `sub`, `icon`), `ownerChipField` (`_owner`), `sheetChipsOf(card)` (drops chips whose field is gone), `sheetChipChoices(card)` (short-value fields; a Combat stats block's HP and each value apart), `sheetChipValue(card, chip, fields, name)` (label and text: HP "31 / 38", a resource "c / m", cards by name, "—" when empty), `sheetChipJson`. The SRD copy's player card gets the built-in card's chips (HP, Species, Class, Level, AC, User); a new template Level and User. Drawn by `character_stat_chips.dart` `freeChipLines` / `characterChipLines` on the hub, the world's character list, the player tab and [[free_character_sheet]].
- `freeTemplateContentHash(schema)` — `computeWorldSchemaContentHash` without the `tags` / `cover_image_path` metadata keys (a new cover is not a template change).
- `pendingTemplateUpdate(world, templates, {dismissedHash, muted})` → the template a free world should be offered as an update, or null (Faz 3).
- `withoutDeletedCategories(entities, schema)` — free world: drops cards whose category is not in the schema (V5); built-in: returns the same map.

## Dependencies & Links
- Depends on: [[world_schema]], [[entity_category_schema]], [[field_schema]], [[free_field_styles]] (style specs of SRD copy v2), [[builtin_schema]] (id constant and the tier slug lists, read only)
- Used by: [[template_provider]], [[free_character_sheet]] (`free_character_provider.dart`: seed, player card, level), [[free_template_editor]] (`builtinTier` for the Tier setting), [[template_update_dialog]], [[world_repository_impl]] (`isSrdLineage`), [[campaign_provider]]; the free gates in `entity_provider.dart` (`worldSchemaProvider` skips the legacy patches), `visible_entity_provider.dart`, `entity_card.dart`, `entity_sidebar.dart`, `main_screen.dart`, `character_add_menu.dart` and the creation wizard
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §6.2, §6.4, §16; `docs/free-template/ROADMAP.md` Faz 1, Faz 3, Faz 6

## Key Logic / Variables
- **Lineage:** `freeRootId = source.freeRootId ?? source.schemaId`, so SRD → copy → copy-of-copy all point at the built-in id; an empty template points at itself.
- **SRD copy (v2, Faz 4a):** `player-character` gets `isPlayerCard: true`; every category gets `tier: builtinTier(slug)`; `_srdCopyField` per field: `crCalculator` dropped; `statBlock` → Stat table (STR–CHA, base 10, step 2; `ability_bonuses` without modifier); `proficiencyTable` → Skill table (rows = the SRD default rows, id = SRD name; reads the category's `stat_block`, a mark adds `proficiency_bonus`); `levelTable` (not `class_levels`, Faz 6) / `levelTextTable` → free-row Table (Level · Value / Text); `rangedSenseList`, `spellEffectList` → free-row Table with the SRD row keys as column keys; `equipmentChoiceGroups`, `playerChoices`, `subspeciesOptions` → Markdown. Column keys equal the SRD row keys, so card data is read as stored ([[free_field_styles]]). **v3 (Faz 6)**, through `_srdCopyFields` (one field may become several; the category is renumbered in card order): `combatStats` (player, NPC) → free Combat stats block (`_srdCombat`: HP / Max HP keep / fill, AC number, Initiative dice, XP number hidden in the encounter, Conditions card list → `condition`; `level`, `speed`, `cr` leave it) followed by **Speed** (integer, `srd_read: speed`) and, on the NPC, **CR** (float, `srd_read: cr`); monster / animal: `ac`, `hp_average`, `initiative_modifier` leave the layout and a `combat_stats` block takes `ac`'s place (values read from those flat fields, [[free_field_styles]] `combatStatsValue`); `class_levels` → Level (`level`); `spellSlotGrid` (`spell_slots`) → the Pool (label "Pool" since Faz 7a; the class's Level table grants the slots in Faz 7b); `slot` → Resource (boxes). Then `_withSrdPresets` (Faz 4b; Faz 6 adds the Combat Stats preset bound to player, NPC, monster, animal): Skills, Saving Throws and Ability Scores presets, each built from the player card's field, bound to every skill / save / `stat_block` field (not `ability_bonuses`); the fields keep their SRD keys (D33). Groups, encounter config and metadata are kept verbatim; a free → free copy keeps fields as they are. Later phases add the remaining rows of ROADMAP §6.
- Category/field ids are **kept** (scoped to the schema); every category's `schemaId` is rewritten to the new id.
- `originalHash` is frozen at creation = `computeWorldSchemaContentHash(copy)`.
- `isBuiltin` flags on copied categories/fields are left as is: nothing reads the schema-level flag (checked 2026-10-11; the `isBuiltin` reads in the app are about packages/cards).

- **Update check (Faz 3):** compares the template with the world's own copy by content (`freeTemplateContentHash` of both), not the recorded `template_hash` — that one includes the cover and tags. Same → nothing; equal to `dismissedHash` (the user's "Ignore") → nothing until the next change; template deleted → nothing (V2); built-in world → never (B2: its hash changes on every generate).

## Notes
- Test: `test/domain/services/free_template_test.dart`.
