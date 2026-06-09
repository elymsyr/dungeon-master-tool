---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/entity.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `entity.dart`

> [!abstract] Primary Purpose
> The Freezed domain model for a single schema-driven world content record. A category-agnostic container: common columns are typed fields; all category/type-specific data lives in the dynamic `fields` map keyed by `FieldSchema.fieldKey`.

## Inputs / Outputs
**Inputs**
- `Entity.fromJson(Map)` — generated deserializer.

**Outputs**
- Immutable `Entity` value type + `_$Entity` copyWith/equality; `toJson()`.

## Dependencies & Links
- Depends on: `freezed_annotation` (codegen), [[field_schema]] (`fields` keyed by fieldKey)
- Used by: [[package_import_service]], [[entity_category_schema]], `EntityNotifier`, [[world_repository_impl]] (via map round-trip)
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference:

## Key Logic / Variables
- Fields: `id` (required), `name` (default `'New Record'`), `categorySlug` (required), `source`, `description`, `images` (List<String>), `imagePath`, `tags`, `dmNotes`, `pdfs`, `locationId?`, `fields` (`Map<String,dynamic>`, default `{}`), `packageId?`, `packageEntityId?`, `linked` (default `false`).
- `linked` distinguishes a live package-linked copy (overwritten on sync) from a detached homebrew copy — see [[package_sync_service]].
- `categorySlug` is the lowercased, hyphenated category key (e.g. `npc`); maps to an [[entity_category_schema]] in the active [[world_schema]].

## Notes
- 29-line model; the persistence-side shape (`WorldEntity` Drift row) intentionally mirrors these fields — keep the two in sync when adding columns.
