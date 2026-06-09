---
type: file-note
domain: projection
path: flutter_app/lib/application/services/entity_snapshot_builder.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `entity_snapshot_builder.dart`

> [!abstract] Primary Purpose
> Pure builder that converts a live `Entity` + `WorldSchema` into a serializable `EntitySnapshot` for projection (showing an entity sheet on the player screen). It is the send-side privacy gate: DM-only / private fields and asset-path fields are stripped, relation ids are resolved to names, and mentions are flattened so the player never sees raw ids or internal markup.

## Inputs / Outputs
**Inputs**
- Args to `build()`: `Entity entity` (required), `WorldSchema schema` (required), `Map<String,Entity> entities` (for relation-id → name resolution), `Map<String,String> imageRemap` (projection injects transient AssetRefs without mutating the entity).
- Reads: schema category (`fields`, `fieldGroups`, `color`, `name`), entity `fields`/`imagePath`/`images`/`description`/`source`/`tags`.
- Supabase / CDC / events / triggers: none (pure).

**Outputs**
- Public API: `static EntitySnapshot build({...})`.
- Writes / Supabase / events: none.

## Dependencies & Links
- Depends on: [[entity]], [[entity_category_schema]], [[field_schema]], [[world_schema]]; `entity_snapshot.dart`, `relation_value.dart`, `mention_text.dart` (not in allow-list)
- Used by: `ProjectionController` (`projection_provider.dart`) when projecting an entity card
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[World-and-Content]]

## Key Logic / Variables
- Field rows built in `orderIndex` order. **Skipped**: `FieldVisibility.dmOnly`, `FieldVisibility.private_`, and asset types `FieldType.image`/`file`/`pdf` (never rendered as raw text). Null or empty-string values dropped.
- `FieldType.relation`: `extractRelationIds(raw)` → map each id to `entities[id]?.name`, drop unresolvable, join with `, ` (never shows a raw id).
- `text`/`textarea`/`markdown`: passed through `stripMentions(_stringify(raw))`.
- `groupLabel`: resolved from `cat.fieldGroups` by `field.groupId`.
- Image paths: `[imagePath, ...images]` with `imageRemap[path] ?? path` applied to each (transient-ref swap without entity mutation).
- `_stringify`: recursive — String passthrough, num/bool `.toString()`, List join `, `, Map → `k: v` pairs joined `, `.
- Output `EntitySnapshot`: id, name, categorySlug, categoryName (`cat?.name ?? slug`), categoryColorHex (`cat?.color ?? '#888888'`), description (mentions stripped), source, tags, imagePaths, fields.

## Notes
- `imageRemap` exists specifically for quota-full transient refs that are deliberately not persisted onto the entity.
