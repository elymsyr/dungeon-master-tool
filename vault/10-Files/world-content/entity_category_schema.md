---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/entity_category_schema.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
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
- Fields: `categoryId`/`schemaId` (required), `name`, `slug`, `icon`, `color` (default `'#808080'`), `isBuiltin`, `isArchived`, `orderIndex`, `fields` (`List<FieldSchema>`), `allowedInSections` (`'encounter'|'mindmap'|'worldmap'|'projection'`), `filterFieldKeys` (sidebar filter fields), `fieldGroups` (`List<FieldGroup>` — visual grouping + grid layout), `createdAt`/`updatedAt` (required).
- `slug` is the stable category key matched against `Entity.categorySlug`; `name` is the human label that [[package_import_service]] matches packages on.
- `isBuiltin` flags the built-in v2 categories overlaid by [[world_repository_impl]] `_overlayMissingBuiltinCategories`; `isArchived` hides without deletion.

## Notes
- 35-line model.
