---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_sync_service.dart
layer: application
language: dart
status: stable
updated: 2026-09-23
tags: [file]
---

# `world_sync_service.dart`

> [!abstract] Primary Purpose
> World-scoped Supabase Realtime orchestrator. Subscribes a live online world to its Supabase mirror tables, emits inbound CDC events on a merged broadcast stream, and manages channel lifecycle (resubscribe with backoff, channel cap). The inbound half of the sync spine — outbound mirroring lives in [[world_mirror_service]].

> [!note] Presence kalktı (Faz 5d, 2026-09-23)
> 2026-09-08'den beri kanal presence taşıyordu (`isSessionOpen` / `sessions` — "DM'in kanalında kendisi dışında en az bir üye"); tek okuyucusu transient havuza talep-üzerine yüklemenin kapısıydı. Medya artık multiplayer açılınca kalıcı olarak bulutta ([[world_media_sync]]), kapının koruyacağı bir şey kalmadı: kanal düz `client.channel('dmt:world:{id}')`, `track()` yok — Realtime mesajı da azaldı.

> [!warning] `_mirrorTables` beşe indi (2026-08-24)
> `world_projection`, `entity_shares`, `world_characters`, `world_packages`, `world_members` (+ `worlds`, id filtresiyle). `world_entities` / `world_map_data` / `world_sessions` / `world_settings` / `world_mind_map_*` abonelikleri kaldırıldı. **Bu listeye tablo eklemek, oyuncunun cihazına DM'in paylaşmadığı veri göndermek demektir.** Bkz. [[Share-Broadcast-Flow]].

> [!note] `world_revisions` sinyali — yalnız DM (2026-09-23, Faz 5b)
> `subscribe(..., onRevision:)` verilirse kanala `_mirrorTables` dışında bir binding daha eklenir: `world_revisions` (`world_id` filtresi). Tablo içerik taşımıyor, yalnız dünyanın bulut sayacı — bu yüzden yukarıdaki "listeye tablo eklemek veri sızdırır" kuralına takılmıyor, ama yine de yalnız DM veriyor: oyuncunun ayna kapısı yok (Faz 5.5), sinyal ona her DM yazmasında boşa mesaj olurdu. Callback `_onRevisionCbs`'te duruyor, resubscribe retry'ı binding'i oradan yeniden kuruyor; olay `events` akışına **düşmüyor** (applier'ın işi değil). Binding kanal kurulurken eklenir — açık bir kanala sonradan eklenmez. Tüketicisi [[cloud_push_provider]] (`onSignal`).

## Inputs / Outputs
**Inputs**
- Constructor dep: `SupabaseClient`.
- Triggers: `subscribe(worldId, onSubscribed, onRevision)` / `unsubscribe(worldId)`; channel `SUBSCRIBED` / `channelError` / `timedOut` status callbacks; reconnect.
- Supabase / CDC subscribed: `postgres_changes` on a world's mirror tables.

**Outputs**
- Public API: `events` (`Stream<WorldSyncEvent>` broadcast), `isSubscribed(worldId)`, `subscribe`, `unsubscribe`.
- Events emitted: `WorldSyncEvent` per inbound CDC payload — consumed by [[world_mirror_applier]] and roster hooks.

## Dependencies & Links
- Depends on: `SupabaseClient`.
- Used by: [[world_mirror_applier]] (applies events), [[world_mirror_service]] (`WorldSyncEvent` type), [[cloud_push_provider]] (DM'in `onSubscribed` → `catchUp`, `onRevision` → `onSignal`; bağlama `world_mirror_provider.dart`'ta).
- Domain map: [[Sync-and-Realtime]]
- System flow: [[Share-Broadcast-Flow]]

## Key Logic / Variables
- `postgres_changes` does **not** replay events missed during a disconnect → `onSubscribed` fires on first connect **and every reconnect** to trigger a catch-up (initial state + roster). Idempotent: a 2nd `subscribe` for the same world fires the callback immediately via `scheduleMicrotask`.
- Resubscribe on `channelError`/`timedOut` with exponential backoff (`_retryCounts`, `_resubTimers`).
- `_maxChannels = 6` defensive cap (R3) against channel leaks while world-hopping; active-world provider normally unsubscribes on dispose (~1 channel).
- `_disposed` guard makes post-dispose calls no-ops.

## Notes
- Skeleton from PR-O2; outbound mirror + reconcile wired in PR-O4. Source comments in Turkish.
