---
type: file-note
domain: world-content
path: flutter_app/lib/data/database/daos/user_templates_dao.dart
layer: data
language: dart
status: active
updated: 2026-10-11
tags: [file]
---

# `user_templates_dao.dart`

> [!abstract] Primary Purpose
> Storage for the user's free templates: the `user_templates` side table, one `WorldSchema` JSON per row. Per-user (lives in the per-user Drift DB), local only — never synced, shared or published (ROADMAP K6).

## Inputs / Outputs
**Inputs**
- `AppDatabase` (plain `DatabaseAccessor`, no Drift table class / codegen).

**Outputs**
- `allJson()` — schema JSON of every row, `ORDER BY created_at, id` (oldest first).
- `upsert(id, schemaJson)` — insert, or replace the JSON keeping the original `created_at`.
- `remove(id)` (not `delete`: that name is Drift's own accessor method).

## Dependencies & Links
- Depends on: `app_database.dart` `_sideTablesDDL` (`CREATE TABLE IF NOT EXISTS user_templates (id PK, schema_json, created_at)`, run in `beforeOpen`; no `schemaVersion` bump — ROADMAP K5)
- Used by: [[template_provider]]
- Domain map: [[World-and-Content]] · [[Data-Layer]]

## Key Logic / Variables
- `created_at` is microseconds since epoch, set on first insert only, so list order survives renames.

## Notes
- Round trip + reopen test: `test/application/providers/user_templates_provider_test.dart` (file-backed DB, closed and reopened).
