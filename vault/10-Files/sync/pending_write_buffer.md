---
type: file-note
domain: sync
path: flutter_app/lib/application/services/pending_write_buffer.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `pending_write_buffer.dart`

> [!abstract] Primary Purpose
> Debounced, row-level write coalescer. Callers schedule a write under a stable `key` with a `WriteKind`; a later schedule for the same key resets the timer and replaces the action closure (only the last fire runs). When a timer fires (or on `immediate`), the action writes to local Drift, then bumps a `tick` ValueNotifier that `[[sync_engine]]` listens to in order to drain the cloud outbox. Also serves as the CDC race guard: appliers check `isPending(key)` so a remote event never overwrites an un-flushed local edit (trailing local fire = last-writer-wins).

## Inputs / Outputs
**Inputs**
- Constructor: `Ref _ref` (currently unused field).
- `schedule({key, kind, action})` from notifiers/editors.
- `flush()` / `flushPrefix(prefix)` from app-close, world-close, dispose hooks.

**Outputs**
- Provider: `pendingWriteBufferProvider`.
- `tick` (`ValueNotifier<int>`) — bumped on every schedule and fire; drives `SyncEngine._scheduleDrain` and UI dirty/saved indicators.
- Query API: `hasPending`, `pendingCount`, `isPending(key)`, `hasPendingPrefix(prefix)`, `pendingKeysWithPrefix(prefix)`.
- Side effect: timer fire runs the supplied `action` (writes to local Drift), timed by `PerfProbe.saveCommit`.

## Dependencies & Links
- Depends on: `PerfProbe` (perf instrumentation, no-op in release)
- Used by: [[sync_engine]] (`tick` listener), [[world_mirror_applier]] (`isPending` / `pendingKeysWithPrefix` CDC race guard), character/world/combat/package notifiers (`schedule`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]

## Key Logic / Variables
- **`WriteKind` windows** (effective debounce = `kind.window`): `shortNumber` 750ms (HP/AC/level/CR), `shortText` 800ms (name/source), `longText` 1200ms (description/dm_notes), `listEdit` 1000ms (tags/pdfs/images/refs), `spatial` 1000ms (pin drag, node move), `combatTick` 500ms (combat_state), `viewport` 2000ms (pan/zoom — pair with `saveSettingsPatchLocalOnly`, local-only, never enters outbox), `immediate` 0ms (import/paste/delete → fires synchronously now).
- **schedule:** cancels+replaces the existing `_pending[key]` timer; `immediate`/zero-duration fires immediately via `_run`; else sets a `Timer(window)` that on fire removes the entry, runs the action, bumps tick.
- **`_run`:** sync actions complete inline; async actions are tracked in `_inFlight` set so `flush`/`flushPrefix` await in-flight writes (so a world-close / app-pause never drops a half-written Drift write).
- **flush:** cancels all timers, awaits all pending actions sequentially, then `_drainInFlight` (loops while `_inFlight` non-empty, catching newly-scheduled writes).
- **flushPrefix:** same but only keys starting with `prefix` (e.g. `flushPrefix("world:$worldId")` on world close).
- **Key conventions:** `"entity:$worldId:$entityId"`, `"character:$id"`, `"settings:$worldId:$subkey"`, `"settings:$worldId:map_data"`. Appliers split on these to detect pending subkeys.

## Notes
- Invariant: trailing local fire always wins over an inbound remote CDC event for the same key (race guard). See `[[world_mirror_applier]]` `_buffer.isPending` checks.
- SS-5 trimmed shortText/longText windows so the "saved" indicator clears faster; re-validate against `PerfProbe.save_commit_ms` before further tuning.
