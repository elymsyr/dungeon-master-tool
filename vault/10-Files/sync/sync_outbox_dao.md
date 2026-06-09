---
type: file-note
domain: sync
path: flutter_app/lib/data/database/daos/sync_outbox_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `sync_outbox_dao.dart`

> [!abstract] Primary Purpose
> Drift accessor for the v12 `sync_outbox` table — the durable, per-row pending-cloud-write queue. Its defining feature is **coalescing enqueue**: before inserting, an existing pending row with the same `(target_table, target_pk, op_type)` is overwritten (payload + timestamps refreshed) instead of appended, so rapid typing on one entity never bloats the outbox. `[[sync_engine]]` drains rows from here.

## Inputs / Outputs
**Inputs**
- `@DriftAccessor(tables: [SyncOutbox])` on `AppDatabase`.
- Callers: `[[sync_engine]]` (`enqueueCoalesced`, `readyBatch`, `markFailed`, `incrementAttempts`, `deleteById`).

**Outputs**
- Reads: `readyBatch`, `findPending`, `watchPendingCount` (stream for UI sync badge).
- Writes: `enqueueCoalesced` (insert or overwrite), `markFailed`, `incrementAttempts`, `deleteById`, `deleteAll`.

## Dependencies & Links
- Depends on: `SyncOutbox` table (`[[tables-sync]]`), `[[drift_database]]`
- Used by: [[sync_engine]]
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[tables-sync]], [[daos-index]]

## Key Logic / Variables
- **`readyBatch({now, limit=100})`** — rows where `nextAttemptAt <= now`, ordered `(nextAttemptAt ASC, createdAt ASC)`, limited. This ordering is what gives the drain its dependency-preserving sequence.
- **`findPending({targetTable, targetPk, opType})`** — earliest matching pending row (the coalesce target).
- **`enqueueCoalesced(...)`** in a `transaction`:
  - If `findPending` hits → `update` that row: overwrite `payloadJson`, `payloadBytes`, `scopeId`, reset `attempts=0`, clear `lastError`/`lastAttemptAt`, set `nextAttemptAt=attemptAt`, set `createdAt=ts`. Returns the existing `opId`.
  - Else → `insert` a fresh row with the supplied `opId`. Returns it.
  - `nextAttemptAt` defaults to `now` (immediate eligibility); slow-tier callers pass `now + cloudDelay` to batch before eligibility. `createdAt` always = real enqueue moment so drain order stays stable.
- **`markFailed(opId, error, nextAttemptAt)`** — stamps `lastError`/`lastAttemptAt`, pushes out `nextAttemptAt` (backoff).
- **`incrementAttempts(opId)`** — raw `customUpdate` bumping `attempts` and `last_attempt_at`.
- **`watchPendingCount()`** — `selectOnly` COUNT, `watchSingle().distinct()` — for the UI pending/dirty indicator.

## Notes
- Coalescing rule (PR-D5 enqueue path) is the table's reason for existing; pairs with `[[pending_write_buffer]]` local debounce so both layers collapse rapid edits.
