---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/{builtin_dnd5e_v2_schema.dart,lookups.dart,content.dart,dm.dart}
layer: domain
language: dart
status: stable
updated: 2026-08-23
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
  - `schema`: `WorldSchema` (version `2.8.0` — 2.5.0 added `monster.alignment_note` (audit **B10**), 2.5.1 relabelled `pack.content_quantities` to say its key is the `content_refs` **index**, not an entity id (audit **T2-3**, cosmetic, no migration), 2.6.0 added the four fields the statblock had nowhere to put (**R3**): `monster.resistance_note` / `immunity_note` / `language_note` and `creature-action.legendary_action_cost` (integer 1–5) — additive, no migration; see [[mapper_monster]]), 2.6.1 widened `background.granted_language_count` to `max: 10` because the source says "Any six" and a ceiling that truncates a real count is as wrong as inventing one (**R4**, permissive, no migration; see [[mapper_chargen]]), 2.7.0 gave the four chargen mechanics of **R5** a home — `background.granted_languages` (the named half of a language line, same key the class pass reads), `background.asi_fixed_ability_ref` + `asi_free_bonus_count` (A5E's "+1 X **and** one other": the mandatory bump leaves `ability_score_options`, which goes back to being the free pick's menu), `subclass.caster_kind` (makes `CasterKind.third` reachable — an archetype casting on a non-caster class; read through `effectiveCasterKind`, where an absent/None subclass value can never downgrade the class), and `always_prepared_spell_refs` on the `classFeatures` row (a domain/circle spell list, gated by the row's own level; the `FieldType.classFeatures` doc comment and the row editor list it too) — additive, no migration; 2.8.0 added the two Tier-2 reference categories `lore` and `campaign` — each with exactly two list fields: `pages` (markdown list, campaign guides/lore text) and `pdfs` (pdf list); `allowedInSections` is empty so documents never land in encounter/map/mindmap sections — additive, no migration; baseSystem `dnd5e`) with all categories + a default encounter layout/config.
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
- **Actual category counts** (verified): **Tier 0 = 39** (`lookups.dart` `tier0Slugs`), **Tier 1 = 22** (`content.dart`), **Tier 2 = 15** (`dm.dart`) → **76 categories total**.
- **Tier 0 (39 lookups, seeded)**: `ability`, `skill`, `damage-type`, `condition`, `creature-type`, `language`, `weapon-property`, `weapon-mastery`, `spell-school`, `magic-item-category`, `sense`, `hazard`, `arcane-focus`, `druidic-focus`, `holy-symbol`, `size`, `rarity`, `coin`, `lifestyle`, `duration-unit`, `body-slot`, `alignment`, `weapon-category`, `armor-category`, `tool-category`, `feat-category`, `action`, `area-shape`, `attitude`, `illumination`, `travel-pace`, `plane`, `casting-component`, `casting-time-unit`, `speed-type`, `cover`, `tier-of-play`, `character-state`, `resource-pool`. These are the canonical names everything else references (Open5e `_lookup` placeholders, SRD `lookup()` calls) and are seeded as `isBuiltin=true` Entity rows on first launch.
- **Tier 1 (22 content shapes, rows external)**: `class`, `subclass`, `species`, `subspecies`, `background`, `feat`, `spell`, `weapon`, `armor`, `tool`, `adventuring-gear`, `ammunition`, `pack`, `mount`, `vehicle`, `trinket`, `magic-item`, `monster`, `trait`, `creature-action`, `animal`, `starter-bundle`. Rows come from the SRD core pack ([[srd-pack-content]]) or installed packages; the schema ships shape only.
- **Tier 2 (15 DM categories, never seeded)**: `npc`, `player-character`, `applied-condition`, `location`, `scene`, `quest`, `encounter`, `trap`, `poison`, `curse`, `environmental-effect`, `hireling`, `service`, `lore`, `campaign`. The last two are reference-material documents (guides, handouts): each has only `pages` (markdown list) + `pdfs` (pdf list) and an empty `allowedInSections`.
- Tier-1 relation fields reference Tier-0 slugs via `FieldValidation.allowedTypes`; `groups.dart` defines shared `FieldGroup` ids (grpIdentity, grpCombat, grpSpellcasting, …) so the editor renders the same layout across installs.
- Encounter config/layout: `combat_stats` field key, initiative-desc sort, columns Lvl/Init/AC/HP; conditions read from the catalog at runtime (left empty in config).

## Notes
- v2 lives beside the v1 template (`builtin-dnd5e-default`); old campaigns keep v1, new ones opt into v2. Tier-0 seed rows are the only authored data in this group — Tier-1 row content is the SRD pack's job.
- **Seed rows link to other Tier-0 rows with the `{'_lookup': slug, 'name': …}` placeholder, never with a bespoke key.** `synthesizeWorldBuiltins` ([[builtin_synth]]) resolves it at read time via `PackageImportService.resolveLookupPlaceholder` against a `slug → name → synth id` index built from the pack rows; built-in Tier-0 rows are never materialised in `world_entities` (F1 decouple), so this is the *only* resolution path. Audit T2-1 (2026-08-14): the 18 `skill` rows used to write `_ability_name_: 'Dexterity'` "for the bootstrap" — no such bootstrap existed, the required `ability_ref` stayed empty and the wizard's ability-mod chip never rendered. Now on the placeholder, pinned by `test/domain/skill_ability_ref_test.dart`. Any new cross-Tier-0 link uses the same shape.
