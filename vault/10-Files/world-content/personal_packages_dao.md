---
type: file-note
domain: world-content
path: flutter_app/lib/data/database/daos/personal_packages_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `personal_packages_dao.dart`

> [!abstract] Primary Purpose
> Drift accessor for the `personal_packages` table — per-user cloud-owned package records keyed by `(ownerId, packageName)`. The owner-scoped layer distinct from the local catalog (`packages`), backing the personal-package cloud sync path.

## Inputs / Outputs
**Inputs**
- Reads (Drift table): `personal_packages` (`PersonalPackage` row).

**Outputs**
- Public API: `get(ownerId, packageName)`, `watchByOwner(ownerId)` (distinct), `upsert(row)` / `upsertAll(rows)` (batch), `deleteOne(ownerId, packageName)`.
- Writes (Drift): `personal_packages`.

## Dependencies & Links
- Depends on: [[tables-packages]], [[drift_database]]
- Used by: personal-package sync service, [[auth_provider]]-scoped flows
- Domain map: [[World-and-Content]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- Composite key on `(ownerId, packageName)` — `get`/`deleteOne` AND both columns; `watchByOwner` streams a user's whole personal library.
- All upserts `insertOnConflictUpdate`; batch via Drift `batch(...)`.

## Notes
- 40-line accessor; no business logic. The owner/cloud distinction is the reason this is separate from [[packages_dao]] — built-in packs link-only, personal packages sync per-entity via RPC (row-level migration design).
