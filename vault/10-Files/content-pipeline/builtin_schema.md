---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/{builtin_dnd5e_v2_schema.dart,lookups.dart,content.dart,dm.dart}
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Built-in D&D 5e v2 Schema (GROUP)

> [!abstract] Primary Purpose
> Generates the built-in `WorldSchema` ("D&D 5e (SRD 5.2.1)", id `builtin-dnd5e-default-v2`) — the category/field definitions every new campaign opts into. Split across three tiers: Tier 0 lookup catalogs (with seed rows), Tier 1 content shapes (rows ship separately via the SRD core pack), and Tier 2 DM-authored categories (never seeded). `builtin_dnd5e_v2_schema.dart` is the orchestrator that stitches the three tier builders into one schema + the Tier-0 seed-row map the bootstrap inserts on first launch.

## Inputs / Outputs
**Inputs**
- `schemaId`, `now` timestamp, `startOrderIndex` (each tier builder is offset by the prior tiers' lengths).

**Outputs**
- `generateBuiltinDnd5eV2Schema()` → `BuiltinDnd5eV2Build{schema, seedRows}`.
  - `schema`: `WorldSchema` (version `2.4.0`, baseSystem `dnd5e`) with all categories + a default encounter layout/config.
  - `seedRows`: `slug → List<row>` — only Tier-0 categories carry rows; Tier-1 and Tier-2 ship shape-only (empty rows).
- `buildTier0Lookups({schemaId, now})` → `List<Tier0CategoryBuild>` (category + canonical seed rows). Also exports `tier0Slugs` (the canonical ordered slug list).
- `buildTier1Content({schemaId, now, startOrderIndex})` → Tier-1 `EntityCategorySchema` list.
- `buildTier2Dm({...})` → Tier-2 `EntityCategorySchema` list.

## Dependencies & Links
- Depends on: `entity_category_schema`, `world_schema`, `field_schema`, `field_group` (`groups.dart` shared FieldGroup ids), `encounter_config`, `encounter_layout`.
- Used by: `bundled_packs_bootstrap` / schema bootstrap, [[normalize]] (`buildTier0Lookups` is the Open5e Normalizer's source of truth), [[srd-pack-content]] (Tier-1 shapes the SRD rows fill), `world_schema`.
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- **Actual category counts** (verified): **Tier 0 = 39** (`lookups.dart` `tier0Slugs`), **Tier 1 = 22** (`content.dart`), **Tier 2 = 13** (`dm.dart`) → **74 categories total**. (The in-code doc comment "36+18+13=67" and the "73-category" label are both stale.)
- **Tier 0 (39 lookups, seeded)**: `ability`, `skill`, `damage-type`, `condition`, `creature-type`, `language`, `weapon-property`, `weapon-mastery`, `spell-school`, `magic-item-category`, `sense`, `hazard`, `arcane-focus`, `druidic-focus`, `holy-symbol`, `size`, `rarity`, `coin`, `lifestyle`, `duration-unit`, `body-slot`, `alignment`, `weapon-category`, `armor-category`, `tool-category`, `feat-category`, `action`, `area-shape`, `attitude`, `illumination`, `travel-pace`, `plane`, `casting-component`, `casting-time-unit`, `speed-type`, `cover`, `tier-of-play`, `character-state`, `resource-pool`. These are the canonical names everything else references (Open5e `_lookup` placeholders, SRD `lookup()` calls) and are seeded as `isBuiltin=true` Entity rows on first launch.
- **Tier 1 (22 content shapes, rows external)**: `class`, `subclass`, `species`, `subspecies`, `background`, `feat`, `spell`, `weapon`, `armor`, `tool`, `adventuring-gear`, `ammunition`, `pack`, `mount`, `vehicle`, `trinket`, `magic-item`, `monster`, `trait`, `creature-action`, `animal`, `starter-bundle`. Rows come from the SRD core pack ([[srd-pack-content]]) or installed packages; the schema ships shape only.
- **Tier 2 (13 DM categories, never seeded)**: `npc`, `player-character`, `applied-condition`, `location`, `scene`, `quest`, `encounter`, `trap`, `poison`, `curse`, `environmental-effect`, `hireling`, `service`.
- Tier-1 relation fields reference Tier-0 slugs via `FieldValidation.allowedTypes`; `groups.dart` defines shared `FieldGroup` ids (grpIdentity, grpCombat, grpSpellcasting, …) so the editor renders the same layout across installs.
- Encounter config/layout: `combat_stats` field key, initiative-desc sort, columns Lvl/Init/AC/HP; conditions read from the catalog at runtime (left empty in config).

## Notes
- v2 lives beside the v1 template (`builtin-dnd5e-default`); old campaigns keep v1, new ones opt into v2. Tier-0 seed rows are the only authored data in this group — Tier-1 row content is the SRD pack's job.
