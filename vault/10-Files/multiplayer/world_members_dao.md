---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/database/daos/world_members_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_members_dao.dart`

> [!abstract] Primary Purpose
> Drift DAO over the local `WorldMembers` table — the offline-first mirror of `public.world_members`. Provides per-world / per-user queries, reactive watch streams, idempotent upserts, and scoped deletes used by the sync appliers.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`.
- Reads (Drift tables): `worldMembers`.

**Outputs**
- Public API:
  - `getByWorld(worldId)` / `watchByWorld(worldId)` (distinct stream)
  - `watchByUser(userId)` (distinct stream)
  - `get(worldId, userId)` → single or null
  - `upsert(WorldMembersCompanion)` / `upsertAll([...])` (batch, insertOnConflictUpdate)
  - `deleteOne(worldId, userId)` / `deleteByWorld(worldId)`
- Writes (Drift tables): `worldMembers`.

## Dependencies & Links
- Depends on: [[drift_database]], [[tables-worlds]]
- Used by: world sync appliers / world reconciler ([[world_mirror_applier]], [[world_reconciler]]); DM hub roster (local path)
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[CDC-Sync-Flow]], [[Sync-and-Realtime]]

## Key Logic / Variables
- `@DriftAccessor(tables: [WorldMembers])`; mixes in `_$WorldMembersDaoMixin`.
- Composite key is `(worldId, userId)` — `get`/`deleteOne` filter on both; upserts use `insertOnConflictUpdate` so applying the same CDC row twice is safe.
- Watch streams call `.distinct()` to suppress duplicate emissions.
- `deleteByWorld` is the bulk-clear used when a world is unpublished/leaves.

## Notes
- The Drift row type here (`WorldMember`) is generated from the table and is distinct from the network domain `WorldMember` in [[world_member]].
