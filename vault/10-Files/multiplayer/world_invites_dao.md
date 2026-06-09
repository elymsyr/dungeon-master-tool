---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/database/daos/world_invites_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_invites_dao.dart`

> [!abstract] Primary Purpose
> Drift DAO over the local `WorldInvites` table — the offline-first mirror of `public.world_invites`. Provides code lookup, a per-world reactive stream, idempotent upserts, and scoped deletes.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`.
- Reads (Drift tables): `worldInvites`.

**Outputs**
- Public API:
  - `getByCode(code)` → single or null
  - `watchByWorld(worldId)` (distinct stream)
  - `upsert(WorldInvitesCompanion)` / `upsertAll([...])` (batch, insertOnConflictUpdate)
  - `deleteByCode(code)` / `deleteByWorld(worldId)`
- Writes (Drift tables): `worldInvites`.

## Dependencies & Links
- Depends on: [[drift_database]], [[tables-worlds]]
- Used by: world sync appliers / reconciler ([[world_mirror_applier]], [[world_reconciler]]); DM invite UI (local path)
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[CDC-Sync-Flow]], [[Sync-and-Realtime]]

## Key Logic / Variables
- `@DriftAccessor(tables: [WorldInvites])`; mixes in `_$WorldInvitesDaoMixin`.
- Primary key is `code`; upserts use `insertOnConflictUpdate` for replay-safety.
- `deleteByWorld` clears all invites when a world is unpublished; `deleteByCode` mirrors a revoke.

## Notes
- Drift row type `WorldInvite` (generated) is distinct from the network domain `WorldInvite` in [[world_invite]].
