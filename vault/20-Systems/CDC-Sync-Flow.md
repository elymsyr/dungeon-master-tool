---
type: system
domain: sync
updated: 2026-06-09
tags: [system]
---

# CDC Sync Flow

> [!summary] What this is
> The 12-step path a local edit takes from a user keystroke to appearing on every peer's screen. Local Drift is the source of truth; Supabase Postgres is the mirror; CDC (change data capture) replicates back. Owned by [[Sync-and-Realtime]].

## Participants
- [[pending_write_buffer]] — debounce per `WriteKind`.
- [[sync_engine]] — drain orchestrator.
- [[sync_tier]] — fast/slow gating.
- [[sync_outbox_dao]] — coalescing outbox.
- [[world_mirror_service]] — push + echo suppression.
- [[world_mirror_applier]] — inbound apply.
- [[world_reconciler]] — post-reconnect merge.

## Flow
1. User edits → `PendingWriteBuffer.schedule(kind, key, closure)`.
2. Debounce fires (750–2000 ms per `WriteKind`) → closure runs.
3. Closure calls `SyncEngine.enqueueWorldEntity/Character(...)`.
4. Engine → `SyncOutboxDao.enqueueCoalesced(targetTable, targetPk, opType, payloadJson)`.
5. **Coalesce:** same `(table, pk, op)` overwrites + resets timer; else insert.
6. **Tier:** `fast` (world entities) eligible now; `slow` (personal packages) delayed `cloudDelay` ≈ 10 s.
7. Drain triggers: buffer tick → 150 ms micro-debounce; connectivity false→true; 15 s safety timer.
8. `readyBatch(now)` → rows where `nextAttemptAt ≤ now`, ordered `(nextAttemptAt ASC, createdAt ASC)` (preserves dependency order).
9. Retry: exponential backoff capped 5 min; >50 attempts → dead-lettered.
10. Push: Supabase table insert/update via [[world_mirror_service]].
11. Inbound: Postgres CDC → client → [[world_mirror_applier]] patches local Drift.
12. **Echo suppression:** last-pushed timestamp per entity id (3 s window) → skip own writes.

## Key Constants / Invariants
- Debounce 750–2000 ms · micro-debounce 150 ms · safety 15 s · backoff cap 5 min · dead-letter @50 · echo window 3 s.
- Coalescing key = `(targetTable, targetPk, opType)`. Drain order is dependency-safe.

## Related
- MoCs: [[Sync-and-Realtime]], [[Backend-Infra]], [[Data-Layer]]
- Source Docs: `flutter_app/docs/auto_save_sync_redesign_may17.md`
