---
type: file-note
domain: sync          # sync | chargen | combat-vtt | projection | world-content | multiplayer | media | backend | content-pipeline | data-layer | deployment
path: flutter_app/lib/application/services/sync_engine.dart
layer: application    # presentation | application | domain | data | core | backend | tool
language: dart        # dart | sql | typescript | python | yaml
status: stable        # stable | active | legacy | stub
updated: 2026-06-09
tags: [file]
---

# `sync_engine.dart`

> [!abstract] Primary Purpose
> High-level summary of what this script/config achieves. One paragraph. The "why it exists".

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps:
- Reads (DAOs / Drift tables):
- Supabase / CDC subscribed:
- Events consumed (EventBus / ChangeBus):
- Triggers (timers, connectivity, lifecycle):

**Outputs**
- Providers / public API exposed:
- Writes (Drift tables):
- Supabase pushed / RPC called:
- Events emitted:

## Dependencies & Links
- Depends on: [[sync_outbox_dao]], [[pending_write_buffer]]
- Used by: [[world_mirror_service]]
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference:

## Key Logic / Variables
- Distilled core algorithm (the part that lets us skip re-reading the file).
- Key constants / thresholds (e.g. debounce 750–2000ms, backoff cap 5 min, dead-letter @50 attempts, echo window 3 s).
- Invariants / gotchas.

## Notes
- TODOs, open questions, related audits in `flutter_app/docs/`.
