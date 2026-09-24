---
type: moc
domain: sync
updated: 2026-09-24
tags: [moc]
---

# Sync & Realtime — Map of Content

> [!summary] Scope
> Üç kol var. İkisi buluta içerik kopyalamaz; üçüncüsü (Faz 4a–4b) **kullanıcı isterse** kopyalar. LAN kolu Faz 6'da (2026-09-24) silindi; hesapsız, internetsiz taşımayı artık yalnız `.dmtz` yapıyor.
>
> **`.dmtz` dosya aktarımı** — hesapsız, internetsiz: dünya/paket/karakter zip'e girer, başka bir kurulumda açılır ([[content_codec]]).
>
> **Paylaşım yayını** — online oyunda DM'in paylaştıklarının oyuncuya canlı akışı. Push doğrudan yazma + echo suppression, inbound Supabase Realtime CDC.
>
> **Bulut aynası** — "Online yap" denen **dünyanın** (kartlar, savaş, pinler, karakterler) ve **paketin** (`user_package*`) satırlarını Supabase'e gönderir; Faz 5a'dan beri dünyayı geri de okur, Faz 5b'den beri **canlı**. Kuyruk yok, CDC yok: giderken `updated_at > son push damgası` taraması, gelirken `get_world_delta(world, since)` tek çağrısı; ikisinin arasında yalnız bir sayı akıyor (`world_revisions` sinyali). Çatışmada son düzenleyen kazanır — istemcide pull, bulutta 097'nin trigger'ları. Faz 5c'den beri ikinci cihaz dünyayı ve paketi hub'dan indirebiliyor ("Bulutta, bu cihazda yok"); paket de pull alıyor (canlı değil, açılışta).
>
> Supabase şemasının kendisi ([[Backend-Infra]]) ve tablo tanımları ([[Data-Layer]]) bu domainin değil.

> [!warning] Bulut sync kaldırıldı (2026-08-24)
> Dünyanın tamamını Postgres'e aynalayan CDC mirror — outbox, `SyncEngine`, `WorldReconciler`, `CloudCatchupService`, `cloud_backups`, personal-package "Make Online" — tamamen silindi. Yerel Drift kaynak-doğru. Migration **077**.

## Key Files

**`.dmtz` codec'i** (`application/services/content_transfer/`):
- [[content_codec]] — manifest, item okuma/uygulama, medya + yol yeniden yazımı.
- [[content_item]] — veri sözleşmesi: `ContentItemRef` / `ContentItemPayload` / `ContentMediaEntry`.
- [[world_merge]] — bölüm bazlı birleştirme; aynı id iki tarafta da varsa çakışma çözümü.
- [[content_archive]] — `.dmtz` zip yazma/okuma.
- [[content_archive_menu]] — hub sekmelerindeki "Aktar" düğmesi ve karakter düzenleyicideki dışa aktarma düğmesi.

**Bulut aynası** (Faz 4a–5a — `docs/online-sync-redesign.md` §4.6–§4.8):
- [[cloud_mirror_tables]] — yerel ↔ bulut kolon eşlemesinin **tek** bildirimi; iki servis de bunu okuyor.
- [[cloud_push_service]] — giden yön: watermark taraması, tombstone'lar, reddedilen satır kuralı. İki kapsam: dünya (`pushWorld`) ve paket (`pushPackage`, `owner_id` kapsamlı).
- [[cloud_pull_service]] — gelen yön: `get_world_delta` sayfaları, LWW uzlaştırması, tombstone uygulaması, `dmt-content://` → yerel yol.
- [[cloud_push_provider]] — turu ne zaman koşacağına karar veren tetikleyici; `tick` → dünya turu → paket turu, dünya açılışında bir kez `syncOnOpen` (**önce push, sonra pull**).
- [[cloud_sync_status_provider]] (Faz 9) — turların kullanıcıya görünen hali: eşitleniyor · çevrimdışı bekliyor · sorun N; Save & Sync göstergesi ve diyaloğu okur.

**Paylaşım yayını** ([[Share-Broadcast-Flow]]):
- [[world_sync_service]] — beş tabloya Realtime abonelik + birleşik CDC event stream'i.
- [[world_mirror_applier]] — inbound event'leri yerel state'e uygular; paylaşılan kartın gövdesini `payload_json`'dan yazar.
- [[world_mirror_service]] — doğrudan push (karakter, paket paylaşımı) + 3 sn echo damgası.
- [[projection_output_online]] — DM'in canlı yayını (`world_projection` manifesti).

**Ortak:**
- [[pending_write_buffer]] — yerel debounce, `WriteKind` başına 750–2000 ms. Bulut `catchUp`'ı ve `.dmtz` dışa aktarımı önce `flush()` çağırıyor; **kaldırılamaz**.

## Data Flow

**Yerel yazma:** Edit → [[pending_write_buffer]] debounce → Drift. Bitti. Kuyruk yok, bulut yok.

**Bulut aynası:** DM'in dünya kanalı `SUBSCRIBED` (açılış · reconnect · uygulama öne gelir) → `catchUp`: tampon flush → push turu (`updated_at > damga` → upsert) → pull turu (`get_world_delta(world, cloud_revision)` → LWW uygula → damgayı ilerlet) → satır indiyse `ActiveCampaignNotifier.reload()` (blob'u Drift'ten tazeler, yoksa inen veri ekrana çıkmaz). Sıra bağlayıcı; gerekçesi [[cloud_pull_service]]. Karşı cihaz yazınca: `world_revisions` sinyali → 1 sn debounce → sayaç yerel damgadan büyükse aynı `catchUp`. Kendi push'umuzun sinyali eşik altında kalır: push, bulutta boşluksuz bir revizyon dizisi bıraktıysa damgayı dizinin sonuna çekiyor ([[cloud_push_service]] `ownRunEnd`).

**Paylaşım:** DM "Paylaş" → görseller `AssetRef`'e → `entity_shares` satırı **gövdesiyle** → CDC → oyuncunun [[world_mirror_applier]]'ı blob'a yazar. Adımlar: [[Share-Broadcast-Flow]].

**`.dmtz`:** Dışa aktar → `ContentCodec.loadItem` → zip (manifest + payload + extras + medya, diskten akıtılarak). İçe aktar → format kontrolü → medya sha doğrulamasıyla diske → `ContentCodec.applyItem` (aynı id varsa [[world_merge]] ile birleştirir). Yol taşınabilirliği `manifest.data_root` + `rewriteRoots`.

## Related Domains
- [[Data-Layer]] (DAO'lar, yerel tablolar) · [[Backend-Infra]] (Supabase Realtime) · [[Multiplayer-and-Online]] (kim alıyor).

## Source Docs
- `flutter_app/docs/auto_save_sync_redesign_may17.md`, `auto_save_sync_roadmap_may17.md` — **tarihsel**: outbox/tier modelini anlatır, artık geçerli değil.
