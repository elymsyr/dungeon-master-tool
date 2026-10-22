---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/entity_category_schema.dart
layer: domain
language: dart
status: stable
updated: 2026-10-22
tags: [file]
---

# `entity_category_schema.dart`

> [!abstract] Primary Purpose
> Freezed model for one entity category within a `WorldSchema` (NPC, Monster, Spell, ... or custom). Defines the category's identity, presentation, and the ordered list of `FieldSchema` field definitions plus field grouping and section-availability metadata.

## Inputs / Outputs
**Inputs**
- `EntityCategorySchema.fromJson(Map)`.

**Outputs**
- Immutable `EntityCategorySchema` value type + `toJson()`.

## Dependencies & Links
- Depends on: [[field_schema]], `field_group`
- Used by: [[world_schema]], [[package_import_service]] (category-by-name matching), entity editors
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference:

## Key Logic / Variables
- Fields: `categoryId`/`schemaId` (required), `name`, `slug`, `icon`, `color` (default `'#808080'`), `isBuiltin`, `isArchived`, `orderIndex`, `fields` (`List<FieldSchema>`), `allowedInSections` (`'encounter'|'mindmap'|'worldmap'|'projection'`), `filterFieldKeys` (sidebar filter fields), `fieldGroups` (`List<FieldGroup>` — visual grouping + grid layout), `isPlayerCard?`, `tier?`, `levelMode?`, `summaryChips?`, `guide?`, `createdAt`/`updatedAt` (required).
- `slug` is the stable category key matched against `Entity.categorySlug`; `name` is the human label that [[package_import_service]] matches packages on.
- `isBuiltin` flags the built-in v2 categories overlaid by [[world_repository_impl]] `_overlayMissingBuiltinCategories`; `isArchived` hides without deletion.

- **`isPlayerCard`** (free template work, 2026-10-11): `true` on a free template's player card category, null everywhere else; `@JsonKey(includeIfNull: false)` keeps it out of the built-in JSON. Set by [[free_template]].
- **`tier`** (free template Faz 2 UI pass, 2026-10-11): the codex sidebar group a free template gives the category (0 lookups, 1 content, 2 DM); null → `builtinTier(slug)` from [[free_template]]. `includeIfNull: false`, so the built-in JSON is unchanged. Chosen in [[free_template_editor]]; the sidebar starts reading it in Faz 3.
- **`summaryChips`** (free template, D40, 2026-10-12): on the player card, the chips character cards and the sheet header show — `[{field, sub?, icon}]` (`sub`: a Combat stats value key, none = HP; `field: _owner` = the user). `includeIfNull: false`; null = none. Read by [[free_template]] `sheetChipsOf`; picked in the player card's category settings.
- **`guide`** (free template Faz 8, 2026-10-22): on the player card, the character creation guide — `[{id, field?, text}]` in order (DESIGN §13.2). `includeIfNull: false`; null = none. Read by [[free_template]] `guideOf`; edited in [[free_template_editor]].
- **`levelMode`** (free template Faz 7a, 2026-10-12): `separate` or `together` (null) — how the cards of a category with a Level table level up (DESIGN §11.2). `includeIfNull: false`. Read by [[free_grants]] `levelModeOf`; set in the category settings of [[free_template_editor]].

## Notes
- 35-line model.
