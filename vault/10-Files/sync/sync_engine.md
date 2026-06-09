---
type: file-note
domain: sync
path: flutter_app/lib/application/services/sync_engine.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `sync_engine.dart`

> [!abstract] Primary Purpose
> Persistent outbox drain worker (PR-D5 v12). Singleton owned by `syncEngineProvider`. App-wide mutations call its `enqueue*` helpers which route through `SyncOutboxDao.enqueueCoalesced`; the engine then drains the SQLite outbox in order and pushes each row to Supabase via `WorldMirrorService`. Survives offline windows because rows persist in SQLite until successfully pushed.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase _db`, `Ref _ref`.
- Providers watched: `connectivityStreamProvider` (false→true triggers `_tick`), `authProvider` (drain skipped if null), `isBetaActiveProvider` (gates personal-package + cloud_backup handlers).
- Reads: `[[sync_outbox_dao]]` (`readyBatch`, `enqueueCoalesced`, `markFailed`, `incrementAttempts`, `deleteById`).
- Events consumed: `PendingWriteBuffer.tick` ValueNotifier → `_scheduleDrain`.
- Triggers: `tick` listener (150ms micro-debounce), connectivity transition, 15s periodic retry timer.

**Outputs**
- Public API: `start`/`stop`/`pause`/`resume`, `forceTick` (UI "Retry now" — resets all rows' backoff), and the `enqueue*` family.
- Writes (Drift): `sync_outbox` (delete on success, markFailed/incrementAttempts on retry).
- Supabase pushed: indirectly via `[[world_mirror_service]]` (`pushEntity`, `pushCharacter`, `pushMapData`, `pushSession`, `pushSettings`, `pushWorldState`, `shareWorldPackage`, personal-package RPCs) and `cloudBackupRepositoryProvider.uploadBackup`.
- Media side-effect: each handler runs `MediaBundler` per-row before push (F4 per-row bundle; SHA-dedupes re-uploads).

## Dependencies & Links
- Depends on: [[sync_outbox_dao]], [[world_mirror_service]], [[pending_write_buffer]], [[sync_tier]], [[media_bundler]]
- Used by: [[pending_write_buffer]] (drives ticks via the buffer's `tick`), notifiers/repositories that enqueue, [[world_reconciler]] (push path), [[cloud_catchup_service]] (pull side)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[migrations-online-worlds]], [[rpc-reference]]

## Key Logic / Variables
- **Target tables (Postgres mirror names):** `world_entities`, `world_characters`, `world_map_data`, `world_sessions`, `world_settings`, `worlds`, `world_packages`, `personal_packages`, `personal_package_entities`, `cloud_backups`. opTypes: `upsert` / `delete`.
- **Tier-aware enqueue:** fast tier (all `world_*`) → `nextAttemptAt = now`, drains next tick. Slow tier (`personal_*`, `cloud_backups`) → `nextAttemptAt = now + SyncTier.slow.cloudDelay` (10s) so rapid edits coalesce before becoming drain-eligible. `_slowAttemptAt()` computes this.
- **Built-in package skip:** `_isBuiltinPackage(name) == srdCorePackageName` → SRD core package rows are NOT enqueued (seeded locally on every device; only linked refs propagate via `world_entities`).
- **Drain loop `_tick()`:** bails if `_running`/`_paused`/no-auth/offline. Pulls `readyBatch(now, limit=20)` repeatedly until a short batch; per row calls `_handle`. Reentrancy-guarded by `_running`.
- **`_handle`:** dead-letter check (`attempts >= _dlqAttempts=50` → log+skip, row left for inspection); switch on `targetTable` to the matching handler; on success `deleteById`; on `_isPermanentRejection` (PostgrestException code `42501` RLS deny or `PGRST116` no-rows) → drop row (no retry); else `_markRetry`.
- **Backoff:** `_markRetry` = exponential `min(maxBackoff, 2^attempts)` seconds, clamped 1..300s; `_maxBackoff = 5min`. Increments attempts + stamps lastError.
- **cloud_backup dedupe:** `_handleCloudBackup` SHA-256 hashes canonical `{type,item_id,data}`; fetches remote hash; skips upload when equal.
- **Constants:** `_batchSize=20`, `_dlqAttempts=50`, `_maxBackoff=5min`, `_drainMicroDebounce=150ms`, `_retryInterval=15s`, `WorldMirrorService` echo TTL=3s (informs why fast-tier zero delay is safe).
- `_newOpId()` = `op_<microsEpoch>_<seq>` monotonic per process.

## Notes
- Ordering invariant: rows drain `(nextAttemptAt ASC, createdAt ASC)` so dependencies (world create before world_entity insert) hold per-actor.
- Coalescing happens in the DAO, not here: same `(table, pk, opType)` overwrites payload — rapid typing never bloats the outbox.
- Related: SS-tier unification audit (`unified_debounce_refactor_may19`).
