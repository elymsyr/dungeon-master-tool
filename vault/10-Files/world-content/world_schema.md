---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/world_schema.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_schema.dart`

> [!abstract] Primary Purpose
> The top-level Freezed schema model for a campaign/template. Holds all entity category definitions, encounter layouts/config, metadata, and the dual content-hash lineage fields that drive template-update detection.

## Inputs / Outputs
**Inputs**
- `WorldSchema.fromJson(Map)` — generated deserializer.

**Outputs**
- Immutable `WorldSchema` value type + `toJson()`; copyWith/equality.

## Dependencies & Links
- Depends on: [[entity_category_schema]], `encounter_config`, `encounter_layout`
- Used by: [[campaign_provider]], [[world_repository_impl]], [[package_import_service]], [[package_payload_importer]], `world_schema_hash` (`computeWorldSchemaContentHash`)
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Fields: `schemaId` (required), `name` (default `'D&D 5e (Default)'`), `version` (`'1.0.0'`), `baseSystem?`, `description`, `categories` (`List<EntityCategorySchema>`), `encounterLayouts`, `encounterConfig`, `metadata`, `createdAt`/`updatedAt` (required), `originalHash?`.
- **`originalHash`** is the lineage marker: content hash frozen at the template's first creation and NEVER updated by later edits (edits update the "current" hash via `computeWorldSchemaContentHash`). Computed from canonical JSON of gameplay-affecting fields only, so two installs that generate the SAME built-in template share the same `originalHash` (global, not per-install). Nullable for legacy templates; lazily backfilled on next save.
- Template-drift detection (see [[campaign_provider]] `applyTemplateUpdate`): compares the world's stored `template_hash` (current) and `template_original_hash` (lineage) against a candidate template.

## Notes
- Hashing helper lives in `world_schema_hash.dart` (not in this allow-list — referenced as plain `computeWorldSchemaContentHash`).
