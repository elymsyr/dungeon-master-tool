---
type: file-note
domain: sync
path: flutter_app/lib/application/services/sync_tier.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `sync_tier.dart`

> [!abstract] Primary Purpose
> Two-value enum + extension classifying how a mutation reaches the cloud. `fast` = realtime row-level mirror with immediate outbox drain; `slow` = cloud-save only (no realtime CDC subscribe) with a delayed push so rapid edits batch. Tiny file (21 lines) but it is the single source for the cloud-push delay constant consumed by `[[sync_engine]]`.

## Inputs / Outputs
**Inputs**
- None (pure enum + extension getter).

**Outputs**
- Public API: `enum SyncTier { fast, slow }` and extension `SyncTierWindows.cloudDelay`.

## Dependencies & Links
- Depends on: (none — leaf enum)
- Used by: [[sync_engine]] (`SyncTier.slow.cloudDelay` for `_slowAttemptAt`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]

## Key Logic / Variables
- `SyncTier.fast` → `cloudDelay = Duration.zero` (drains on next outbox tick, ~150ms after a `tick` bump). Covers world entities, world-bound characters, world settings/map/sessions, `world_packages`.
- `SyncTier.slow` → `cloudDelay = Duration(seconds: 10)`. Covers personal packages + entities, worldless characters (via `cloud_backups`). The 10s delay lets the outbox coalesce rapid edits before the row becomes drain-eligible.
- **Gotcha (dead code removed):** tier no longer multiplies the *local* debounce window. Local debounce is decided solely by `WriteKind.window` in `[[pending_write_buffer]]`; tier only affects the *cloud* push delay (the `nextAttemptAt` offset in the outbox).

## Notes
- Note the doc comment says "30s" in `sync_engine` prose but the actual constant here is 10s — the constant is authoritative.
