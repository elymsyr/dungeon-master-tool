---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/builtin_content_names.dart
layer: domain
language: dart
status: stable
updated: 2026-08-31
tags: [file]
---

# `builtin_content_names.dart`

> [!abstract] Primary Purpose
> Derives, from the schema itself, the three catalogues [[world_blueprint_converter]]
> validates against: what names already exist, which categories a blueprint may carry,
> and which field keys each category accepts. Everything here is derived — the whole
> class of "hand-maintained list drifted from the schema" bug is gone.

## Inputs / Outputs
**Inputs**
- `generateBuiltinDnd5eV2Schema()` — categories, field keys, Tier-0 seed rows.
- `srdRawRowsBySlug()` — SRD 5.2.1 Tier-1 rows (names only; deliberately not `buildSrdCorePack()`, which would mint ~2000 UUIDs for nothing).
- `tier0Slugs` from `builtin/lookups.dart`.

**Outputs**
- `builtinContentNames()` → `slug → {name}` (Tier-0 seeds + SRD pack).
- `blueprintContentSlugs()` → every schema category minus Tier-0.
- `blueprintTier0Slugs()` → the Tier-0 set.
- `blueprintFieldKeys()` → `slug → {field key}` incl. the base entity keys (`name`, `description`, `imagePath`, `images`, `dmNotes`, `tags`, `pdfs`, `locationId`).

## Dependencies & Links
- Used by: [[world_blueprint_converter]] callers — [[bundled_worlds_installer]], [[convert_blueprint]]
- Depends on: [[builtin_schema]], [[srd_core_pack]]
- Domain map: [[World-and-Content]]

## Key Logic / Variables
- Name matching is exact and case-sensitive; `findEntityIdByName` only adds a trailing-parenthetical fallback at read time.
- Adding a category or field to the built-in schema immediately widens what blueprints may declare — no second list to update.

## Notes
- Building the schema + raw SRD rows costs one pass; both installer and CLI call it once per run.
