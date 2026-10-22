---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_template.dart
layer: domain
language: dart
status: active
updated: 2026-10-22
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
- Depends on: [[world_schema]], [[entity_category_schema]], [[field_schema]], [[free_field_styles]] (style specs of SRD copy v2), [[free_grants]] (`LevelMode`), [[free_srd_levels]] (the `srd_read` kinds of v4), [[builtin_schema]] (id constant and the tier slug lists, read only)
- Used by: [[template_provider]], [[free_character_sheet]] (`free_character_provider.dart`: seed, player card, level), [[free_template_editor]] (`builtinTier` for the Tier setting), [[template_update_dialog]], [[world_repository_impl]] (`isSrdLineage`), [[campaign_provider]]; the free gates in `entity_provider.dart` (`worldSchemaProvider` skips the legacy patches), `visible_entity_provider.dart`, `entity_card.dart`, `entity_sidebar.dart`, `main_screen.dart`, `character_add_menu.dart` and the creation wizard
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §6.2, §6.4, §16; `docs/free-template/ROADMAP.md` Faz 1, Faz 3, Faz 6, Faz 7b

## Key Logic / Variables
- **Ready-made SRD free template (2026-10-22):** `srdFreeTemplate` = `copyAsFreeTemplate(builtin, id: srdFreeTemplateId)` with a fixed timestamp, built once per process from code and never stored; `isBuiltinTemplate` is true for it and the built-in one (view and copy only). A copy of it is a normal SRD-lineage free template.
- **Lineage:** `freeRootId = source.freeRootId ?? source.schemaId`, so SRD → copy → copy-of-copy all point at the built-in id; an empty template points at itself.
- **SRD copy (v2, Faz 4a):** `player-character` gets `isPlayerCard: true`; every category gets `tier: builtinTier(slug)`; `_srdCopyField` per field: `crCalculator` dropped; `statBlock` → Stat table (STR–CHA, base 10, step 2; `ability_bonuses` without modifier); `proficiencyTable` → Skill table (rows = the SRD default rows, id = SRD name; reads the category's `stat_block`, a mark adds `proficiency_bonus`); `levelTable` (not `class_levels`, Faz 6) / `levelTextTable` → free-row Table (Level · Value / Text); `rangedSenseList`, `spellEffectList` → free-row Table with the SRD row keys as column keys; `equipmentChoiceGroups`, `playerChoices`, `subspeciesOptions` → Markdown. Column keys equal the SRD row keys, so card data is read as stored ([[free_field_styles]]). **v3 (Faz 6)**, through `_srdCopyFields` (one field may become several; the category is renumbered in card order): `combatStats` (player, NPC) → free Combat stats block (`_srdCombat`: HP / Max HP keep / fill, AC number, Initiative dice, XP number hidden in the encounter, Conditions card list → `condition`; `level`, `speed`, `cr` leave it) followed by **Speed** (integer, `srd_read: speed`) and, on the NPC, **CR** (float, `srd_read: cr`); monster / animal: `ac`, `hp_average`, `initiative_modifier` leave the layout and a `combat_stats` block takes `ac`'s place (values read from those flat fields, [[free_field_styles]] `combatStatsValue`); `class_levels` → Level (`level`); `spellSlotGrid` (`spell_slots`) → the Pool (label "Pool" since Faz 7a; the class's Level table grants the slots in Faz 7b); `slot` → Resource (boxes). **v4 (Faz 7b):** `classFeatures` (class / subclass `features`) and `spellsAtLevel` (`granted_spells_at_level`) → Level table, `resourcePoolGrants` → Grants, each with `styleConfig.srd_read` so the card's SRD data is read by [[free_srd_levels]]; `spellSlotProgression` dropped (its slots are the class's rows); the Class category's `levelMode` is `separate` (subclass, species, feat, trait, magic item stay together, V24); the player card gets a **Subspecies** single link (`subspecies_ref` → `subspecies`, id `<species_ref id>-subspecies`) after Species, so a lineage's Level table (Drow's Faerie Fire) reaches the character. The player card's **Feats** list moves out of Identity into Traits & Actions, just above Traits (a card list like them, not compact chips). Then `_withSrdPresets` (Faz 4b; Faz 6 adds the Combat Stats preset bound to player, NPC, monster, animal): Skills, Saving Throws and Ability Scores presets, each built from the player card's field, bound to every skill / save / `stat_block` field (not `ability_bonuses`); the fields keep their SRD keys (D33). Groups and metadata are kept verbatim; a free → free copy keeps fields as they are. Every row of ROADMAP §6 is converted since v4.
- Category/field ids are **kept** (scoped to the schema); every category's `schemaId` is rewritten to the new id.
- `originalHash` is frozen at creation = `computeWorldSchemaContentHash(copy)`.
- `isBuiltin` flags on copied categories/fields are left as is: nothing reads the schema-level flag (checked 2026-10-11; the `isBuiltin` reads in the app are about packages/cards).

- **Encounter (Faz 9, DESIGN §14):** a copy from the built-in gets `EncounterConfig(combatPresetId: '<id>-preset-combat', battlemapFields: builtinBattlemapFields)` (the Combat Stats preset; sort by `initiative`, a Dice value, high to low; battle maps from Location's `battlemaps` / `map` / `map_per_era`) instead of the built-in columns, and `encounter` / `trap` (`_noCombatSlugs`) leave the encounter — they have no Combat stats block (the built-in encounter gives them a stand-in 10 HP / 10 AC). Read by [[free_encounter]].
- **Creation guide (Faz 8, DESIGN §13.2):** `guideOf(card)` reads the player card's `guide` as `GuideStep (id, field?, text)`, keeping a step whose field is gone; `guideStepJson`. A character's place is `guideKey` (`_guide`) `{step, open}`, read by `guideProgressOf` (step clamped to the guide, null when absent or the guide is empty). `freeCharacterSeed` adds `{step: 0, open: true}` when the card has a guide. The SRD copy (`copyAsFreeTemplate` from the built-in) comes with `_srdGuide`: 13 English steps in the SRD 5.2.1 creation order, each on a player-card field (ROADMAP Y6, changed 2026-10-22); copies made before keep their own guide. A guide edit is a content change (the guide lives on the category), so worlds are offered the update.
- **Update check (Faz 3):** compares the template with the world's own copy by content (`freeTemplateContentHash` of both), not the recorded `template_hash` — that one includes the cover and tags. Same → nothing; equal to `dismissedHash` (the user's "Ignore") → nothing until the next change; template deleted → nothing (V2); built-in world → never (B2: its hash changes on every generate).

## Notes
- Test: `test/domain/services/free_template_test.dart`.
