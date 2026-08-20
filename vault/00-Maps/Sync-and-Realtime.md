---
type: moc
domain: sync
updated: 2026-08-20
tags: [moc]
---

# Sync & Realtime — Map of Content

> [!summary] Scope
> Offline-first sync between local Drift and the Supabase Postgres mirror. Owns the coalescing outbox, tier-aware batching, push with echo-suppression, inbound CDC apply, and post-reconnect reconciliation. Ayrıca **buluta hiç uğramayan** ikinci bir kol: aynı ağdaki iki cihaz arasında manuel LAN eşlemesi. Does **not** own the Supabase schema itself ([[Backend-Infra]]) or the table definitions ([[Data-Layer]]).

## Key Files
- [[sync_engine]] — persistent outbox drain orchestrator (start / tick / drain).
- [[sync_tier]] — fast (realtime) vs slow (10 s batched) classification + cloud delay.
- [[pending_write_buffer]] — client-side debounce per `WriteKind` (750–2000 ms).
- [[sync_outbox_dao]] — coalescing upsert + `readyBatch()` drain ordering.
- [[world_sync_service]] — Supabase Realtime subscribe + merged CDC event stream (inbound half).
- [[world_mirror_service]] — push to Supabase + echo suppression (3 s window).
- [[world_mirror_applier]] — apply inbound CDC patches to local Drift.
- [[world_reconciler]] — conflict resolution after reconnect.
- [[cloud_catchup_service]] — replay missed changes on reconnect.

**LAN kolu** (bulutu atlar, manuel, kalıcı cihaz eşleşmesi — [[LAN-Sync-Flow]]):
- [[lan_sync_protocol]] — tel formatı, LWW diff, HMAC, QR daveti, presence paketi.
- [[lan_device_store]] — cihaz kimliği + `lan_paired_devices` kayıtları.
- [[lan_sync_server]] — host: HttpServer + presence beacon + eşleşme uçları.
- [[lan_sync_client]] — `/pair` el sıkışması, imzalı çağrılar, presence dinleyici.
- [[lan_sync_session]] — manifest, item okuma/uygulama, medya + yol yeniden yazımı.

## Data Flow
Edit → [[pending_write_buffer]] debounce → [[sync_engine]] enqueue → [[sync_outbox_dao]] coalesce → tier-gated drain → [[world_mirror_service]] push → Supabase CDC → peers' [[world_mirror_applier]]. Full 12 steps: [[CDC-Sync-Flow]].

LAN: QR okut (ya da IP+PIN) → `/pair` el sıkışması → iki tarafta kalıcı kayıt. Sonra tek tuş: her eşleşmiş cihazla manifest → `diffManifests` (LWW) → item item `repository.load`/`save` + medya. Outbox'a hiçbir şey yazılmaz, aynı hesap zorunlu. Adımlar: [[LAN-Sync-Flow]].

## Related Domains
- [[Data-Layer]] (outbox table, DAOs) · [[Backend-Infra]] (Supabase CDC) · [[Multiplayer-and-Online]] (who receives).

## Source Docs
- `flutter_app/docs/auto_save_sync_redesign_may17.md`, `auto_save_sync_roadmap_may17.md`, unified-debounce + realtime-redesign notes.
