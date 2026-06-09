---
type: file-note
domain: combat-vtt
path: flutter_app/lib/application/services/battlemap_marks_protocol.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `battlemap_marks_protocol.dart`

> [!abstract] Primary Purpose
> Append-only ops protocol (F8) for battle-map marks (strokes/fog/shapes). Instead of re-uploading the whole `world_battlemap_marks` state JSON on every change (payload grows unboundedly, player rebuild storms during long encounters), each change appends a tiny event row to `world_battlemap_mark_ops`. Clients keep a local mirror and merge ops with a base snapshot at render time. The DM periodically compacts (writes a fresh snapshot, deletes old ops). This class is the MVP plumbing; caller wiring (the `battlemap_marks_service` refactor) was deferred to a later PR.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`, `SupabaseClient? supabase`.
- Reads (Drift): local table `bm_mark_ops_local` (raw SQL via `customSelect`/`customStatement`).
- Supabase / CDC subscribed: none here — designed to RECEIVE ops via `applyOp` from the realtime/CDC layer.
- Events consumed: none.
- Triggers: none internal — all methods are caller-driven.

**Outputs**
- Public API: `battlemapMarksProtocolProvider` (`Provider<BattleMapMarksProtocol>`). Methods: `pushOp`, `applyOp`, `loadOpsForEncounter`, `opCount`, `compact`. Plus the `MarkOp` value class.
- Writes (Drift): `INSERT OR IGNORE` / `DELETE` on `bm_mark_ops_local`.
- Supabase pushed / RPC: `world_battlemap_mark_ops` table `.insert(...)` (best-effort); `compact_battlemap_marks` RPC for cloud-side compaction.
- Events emitted: none.

## Dependencies & Links
- Depends on: [[drift_database]], [[rpc-reference]]
- Used by: [[combat_provider]], [[grid_canvas]], [[CDC-Sync-Flow]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[CDC-Sync-Flow]]

## Key Logic / Variables
- `compactionInterval = Duration(minutes: 5)`, `compactionOpThreshold = 500` — DM triggers compaction when either is exceeded.
- `MarkOp` fields: `opId`, `worldId`, `encounterId`, `authorId`, `kind`, `payload` (Map), `seq`, `createdAt`. `seq = DateTime.now().microsecondsSinceEpoch` — monotonic ordering key.
- `pushOp`: generates `opId` via `newId()`, writes local mirror, then best-effort cloud insert into `world_battlemap_mark_ops` (caught, logged, never throws). Outbox routing was a future PR — currently a direct upsert.
- `applyOp`: idempotent — `INSERT OR IGNORE` keyed on `op_id`; a duplicate op (same id arriving twice via CDC) is a no-op.
- `loadOpsForEncounter`: `SELECT ... WHERE world_id=? AND encounter_id=? [AND seq > sinceSeq] ORDER BY seq ASC`. Decodes `payload_json` defensively (bad JSON → empty map). Render layer merges these atop the base snapshot.
- `opCount`: `COUNT(*)` for the encounter — the compaction-trigger metric.
- `compact`: deletes local ops `WHERE seq <= highWaterSeq`, then calls cloud RPC `compact_battlemap_marks(p_world_id, p_encounter_id, p_high_water)`.
- `created_at` is stored as epoch millis in the local mirror but ISO-8601 in the Supabase row.

## Notes
- MVP — header explicitly states caller wiring (battlemap_marks_service refactor) is a follow-up PR; the protocol itself is push/apply/compact/snapshot-reload ready.
- Cloud writes are guarded by `SupabaseConfig.isConfigured` and a null `_sb`; offline degrades to local-mirror-only.
