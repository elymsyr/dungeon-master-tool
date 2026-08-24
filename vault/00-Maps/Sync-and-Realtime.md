---
type: moc
domain: sync
updated: 2026-08-24
tags: [moc]
---

# Sync & Realtime — Map of Content

> [!summary] Scope
> İki kol var ve ikisi de **buluta dünya kopyalamaz.**
>
> **LAN** — cihazdan cihaza taşımanın tek yolu. Aynı ağdaki iki cihaz arasında manuel, kalıcı eşleşmeli, buluta hiç uğramayan senkron.
>
> **Paylaşım yayını** — online oyunda DM'in paylaştıklarının oyuncuya canlı akışı. Push doğrudan yazma + echo suppression, inbound Supabase Realtime CDC.
>
> Supabase şemasının kendisi ([[Backend-Infra]]) ve tablo tanımları ([[Data-Layer]]) bu domainin değil.

> [!warning] Bulut sync kaldırıldı (2026-08-24)
> Dünyanın tamamını Postgres'e aynalayan CDC mirror — outbox, `SyncEngine`, `WorldReconciler`, `CloudCatchupService`, `cloud_backups`, personal-package "Make Online" — tamamen silindi. Yerel Drift kaynak-doğru. Migration **077**.

## Key Files

**LAN kolu** (bulutu atlar, manuel, kalıcı cihaz eşleşmesi — [[LAN-Sync-Flow]]):
- [[lan_sync_protocol]] — tel formatı, LWW diff, HMAC, QR daveti, presence paketi.
- [[lan_device_store]] — cihaz kimliği + `lan_paired_devices` kayıtları.
- [[lan_sync_server]] — host: HttpServer + presence beacon + eşleşme uçları.
- [[lan_sync_client]] — `/pair` el sıkışması, imzalı çağrılar, presence dinleyici.
- [[lan_sync_session]] — manifest, item okuma/uygulama, medya + yol yeniden yazımı.

**Paylaşım yayını** ([[Share-Broadcast-Flow]]):
- [[world_sync_service]] — beş tabloya Realtime abonelik + birleşik CDC event stream'i.
- [[world_mirror_applier]] — inbound event'leri yerel state'e uygular; paylaşılan kartın gövdesini `payload_json`'dan yazar.
- [[world_mirror_service]] — doğrudan push (karakter, paket paylaşımı) + 3 sn echo damgası.
- [[projection_output_online]] — DM'in canlı yayını (`world_projection` manifesti).

**Ortak:**
- [[pending_write_buffer]] — yerel debounce, `WriteKind` başına 750–2000 ms. LAN `flush()`'una bağlı; **kaldırılamaz**.

## Data Flow

**Yerel yazma:** Edit → [[pending_write_buffer]] debounce → Drift. Bitti. Kuyruk yok, bulut yok.

**Paylaşım:** DM "Paylaş" → görseller `AssetRef`'e → `entity_shares` satırı **gövdesiyle** → CDC → oyuncunun [[world_mirror_applier]]'ı blob'a yazar. Adımlar: [[Share-Broadcast-Flow]].

**LAN:** QR okut (ya da IP+PIN) → `/pair` el sıkışması → iki tarafta kalıcı kayıt. Sonra tek tuş: her eşleşmiş cihazla manifest → `diffManifests` (LWW) → item item `repository.load`/`save` + medya. Aynı hesap zorunlu. Adımlar: [[LAN-Sync-Flow]].

## Related Domains
- [[Data-Layer]] (DAO'lar, yerel tablolar) · [[Backend-Infra]] (Supabase Realtime) · [[Multiplayer-and-Online]] (kim alıyor).

## Source Docs
- `flutter_app/docs/auto_save_sync_redesign_may17.md`, `auto_save_sync_roadmap_may17.md` — **tarihsel**: outbox/tier modelini anlatır, artık geçerli değil.
