---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_sync_service.dart
layer: application
language: dart
status: stable
updated: 2026-09-08
tags: [file]
---

# `world_sync_service.dart`

> [!abstract] Primary Purpose
> World-scoped Supabase Realtime orchestrator. Subscribes a live online world to its Supabase mirror tables, emits inbound CDC events on a merged broadcast stream, and manages channel lifecycle (resubscribe with backoff, channel cap). The inbound half of the sync spine — outbound mirroring lives in [[world_mirror_service]].

> [!note] Oturum kapısı presence'ta (2026-09-08)
> Kanal `RealtimeChannelConfig(key: uid)` ile açılır, `SUBSCRIBED` sonrası `track({'uid'})` gönderilir, `onPresenceSync` → `isSessionOpen(worldId)` = "presence'ta benden başka anahtar var mı". **Oturum = DM'in kanalında kendisi dışında en az bir üye.** Düğme, kolon, RPC yok — DM oturum başlatmayı unutamaz. Sunucu tarafı zorlaması DEĞİL (presence Postgres'ten okunamaz); israf önleyici bir kapı, tek okuyucusu [[world_mirror_applier]]'ın transient upload'ı. Bkz. `docs/media-storage-redesign.md`.

> [!warning] `_mirrorTables` beşe indi (2026-08-24)
> `world_projection`, `entity_shares`, `world_characters`, `world_packages`, `world_members` (+ `worlds`, id filtresiyle). `world_entities` / `world_map_data` / `world_sessions` / `world_settings` / `world_mind_map_*` abonelikleri kaldırıldı. **Bu listeye tablo eklemek, oyuncunun cihazına DM'in paylaşmadığı veri göndermek demektir.** Bkz. [[Share-Broadcast-Flow]].

## Inputs / Outputs
**Inputs**
- Constructor dep: `SupabaseClient`.
- Triggers: `subscribe(worldId, onSubscribed)` / `unsubscribe(worldId)`; channel `SUBSCRIBED` / `channelError` / `timedOut` status callbacks; reconnect.
- Supabase / CDC subscribed: `postgres_changes` on a world's mirror tables.

**Outputs**
- Public API: `events` (`Stream<WorldSyncEvent>` broadcast), `sessions` (`Stream<({String worldId, bool open})>`), `isSessionOpen(worldId)`, `isSubscribed(worldId)`, `subscribe`, `unsubscribe`.
- Events emitted: `WorldSyncEvent` per inbound CDC payload — consumed by [[world_mirror_applier]] and roster hooks.

## Dependencies & Links
- Depends on: `SupabaseClient`.
- Used by: [[world_mirror_applier]] (applies events), [[world_mirror_service]] (`WorldSyncEvent` type).
- Domain map: [[Sync-and-Realtime]]
- System flow: [[Share-Broadcast-Flow]]

## Key Logic / Variables
- `postgres_changes` does **not** replay events missed during a disconnect → `onSubscribed` fires on first connect **and every reconnect** to trigger a catch-up (initial state + roster). Idempotent: a 2nd `subscribe` for the same world fires the callback immediately via `scheduleMicrotask`.
- Resubscribe on `channelError`/`timedOut` with exponential backoff (`_retryCounts`, `_resubTimers`).
- `_maxChannels = 6` defensive cap (R3) against channel leaks while world-hopping; active-world provider normally unsubscribes on dispose (~1 channel).
- `_disposed` guard makes post-dispose calls no-ops.

## Notes
- Skeleton from PR-O2; outbound mirror + reconcile wired in PR-O4. Source comments in Turkish.
