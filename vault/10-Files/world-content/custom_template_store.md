---
type: file-note
domain: world-content
path: flutter_app/lib/data/datasources/local/custom_template_store.dart
layer: data
language: dart
status: stable
updated: 2026-09-04
tags: [file]
---

# `custom_template_store.dart`

> [!abstract] Primary Purpose
> The user template library. Raw-SQL store over the `custom_templates` side table, holding whole `WorldSchema` documents that the user created or copied. The built-in template is never in here — it is generated from code.

## Inputs / Outputs
**Inputs**
- `upsert(WorldSchema)` — insert-or-replace keyed on `schema_id`.
- `delete(String schemaId)`.

**Outputs**
- `list()` → `List<WorldSchema>` ordered by name (`COLLATE NOCASE`). A row that fails to decode is skipped, never thrown.

## Dependencies & Links
- Depends on: [[app_database]] (`customSelect` / `customStatement`), [[world_schema]]
- Used by: `template_provider` (`customTemplateStoreProvider`, `allTemplatesProvider`, `TemplateLibrary`)
- Domain map: [[World-and-Content]], [[Data-Layer]]
- System flow: [[Template-System]]

## Key Logic / Variables
- Table `custom_templates(schema_id PK, name, schema_json, created_at, updated_at)` is declared in `_sideTablesDDL` and created idempotently in `beforeOpen` — **no Drift codegen and no `schemaVersion` bump**, mirroring `asset_refs` / `lan_paired_devices`. Bumping the version would rename every existing user's DB to `.legacy` and start them empty.
- Per-user DB path means the library is naturally scoped to the signed-in account.
- New template ids are `custom-<uuid v4>`; `TemplateLibrary.copyFrom` also clears `originalHash` so a copy starts a fresh lineage and template-drift detection never ties it back to its source.
- Deleting a template does not touch worlds built from it — a world carries its own schema snapshot in `world_settings.settings_json._world_schema` (see [[world_repository_impl]]).

## Notes
- Everything in this table is mechanics-free by construction; see [[template_mechanics]].
- Guard: `test/domain/template_authoring_test.dart`.
