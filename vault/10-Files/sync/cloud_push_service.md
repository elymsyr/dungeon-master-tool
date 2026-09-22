---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_push_service.dart
layer: application
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `cloud_push_service.dart`

> [!abstract] Primary Purpose
> Faz 4a'nın giden yolu: yereldeki **dünya satırlarını** Supabase ayna tablolarına yazar. Kuyruk tutmaz — gönderilecek işin listesi yerine "nereye kadar gidildi" tarihini hatırlar (`worlds.last_cloud_push_at`), her turda `updated_at > damga` olan satırları tarar. Çevrimdışıyken tur hiç koşmaz, damga ilerlemez, satırlar yerinde birikir; ağ dönünce aynı tarama onları bulur.

> [!warning] Bu `SyncEngine` değil
> Eski bulut sync'in 998 satırlık outbox motoru **geri gelmedi** ve gelmeyecek. Yazma noktalarında `enqueue` çağrısı yok; tek girdi satırın kendi `updated_at`'i. Kararın gerekçesi ve outbox ile karşılaştırması: `docs/online-sync-redesign.md` §4.6.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase db`, `SupabaseClient client`, `SharedMediaCourier? courier`.
- Reads (Drift): `worlds` (bayrak + damga), `world_entities`, `world_settings`, `world_map_data`, `world_sessions`, `world_mind_map_nodes/_edges`, `encounters`, `combatants`, `combat_conditions`, `map_pins`, `timeline_pins`, `installed_packages`, `sync_tombstones`.
- Çağıran: [[cloud_push_provider]] (`CloudPushPump.push`), `save_sync_indicator.dart` ilk yayında `full: true`.

**Outputs**
- Supabase `upsert`: 11 ayna tablosu (`world_*` + `world_combatants`); `delete`: tombstone'ların işaret ettiği satırlar.
- Writes (Drift): `worlds.last_cloud_push_at` (tur temiz bittiyse), `sync_tombstones` temizliği, dirilen satırın `updated_at` tazelemesi.
- Public API: `pushWorld(worldId, {dmOnlyKeys, full})` → `CloudPushResult`; `collect(worldId, since, dmOnlyKeys)` → `List<CloudPushBatch>` (**ağsız** ara adım, testin girdiği kapı).

## Dependencies & Links
- Depends on: [[drift_database]], [[shared_media_courier]] (`refFor` → `dmt-content://`), `isOfflineError`.
- Used by: [[cloud_push_provider]], [[save_sync_indicator]].
- Damga/tombstone sözleşmesi: `sync_stamp.dart` — DAO'lar `stampedNow` ile upsert damgalar, `recordTombstone(s)` ile silme kaydeder.
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.3 (CDC değil artımlı çekme), §2.8 (düzenleme zamanı), §4.6 (Faz 4a).

## Key Logic / Variables
- **Turun sırası:** `cutoff = now()` taramadan **önce** alınır (tur sürerken düzenlenen satır bir sonraki tura kalsın) → tombstone'lar → tablo tablo upsert → damga `cutoff`'a çekilir. Hata çıkarsa damga **ilerlemez**: aynı satırlar bir sonraki turda yeniden gider, upsert idempotent olduğu için zararsız.
- **`_mirrorTables`:** yerel→bulut eşlemesi bildirimsel bir liste. Kolon adları iki tarafta aynı (Drift SQL'i snake_case üretiyor), o yüzden eşleme bir isim listesi + üç dönüşüm bayrağı: `dateCols` (unix saniye → ISO), `boolCols` (SQLite 0/1 → `boolean`), `mediaCols` (yerel yol → `dmt-content://`).
- **Combatant ayrı:** yerel `combatants`'ta `world_id` yok (encounter üzerinden gelir) ve durum etkileri bulutta ayrı satır değil, `conditions_json` kolonu. `_collectCombatants` JOIN'li sorguyu ve koşul katlamasını yapar.
- **`dm_only_keys` (§2.6):** kategori şemada **yoksa** buluta `NULL` gider ve `get_shared_entities` o kartı oyuncuya hiç döndürmez. Boş liste "sır yok" demektir — ikisi karıştırılmamalı.
- **Reddedilen satır:** parça reddedilirse (kota, 256 KB, RLS) suçlu tek tek denenerek bulunur, `rejected`'e yazılır ve **atlanır**; damga yine ilerler. Tek bir dev kart bütün dünyanın senkronunu kilitlemesin.
- **Diriltme koruması:** tombstone yazıldıktan sonra aynı id yerelde geri geldiyse (import / full-replace) bulut satırı silinmez — kayıt düşülür ve satır **şimdiyle damgalanır** ki bu turun taramasına girsin. Sadece atlamak yetmezdi: geri gelen satır eski `updated_at` taşıyor olabilir.
- **Medya:** gövdeler şemasız geziliyor; mutlak yol taşıyan her string `SharedMediaCourier.refFor` ile içerik ref'ine çevriliyor. Yerel satır yolunu korur, çeviri yalnız giden kopyada (Faz 3.5 sözleşmesi).

## Notes
- Test: `test/application/services/cloud_push_collect_test.dart` — `collect` üzerinden, ağsız.
- Bilinçli sınırlar (§4.6): `revision` istemcide yazılmıyor, reddedilen satır kullanıcıya gösterilmiyor, uygulama kapanırken "son tur" yok, `updated_at` için ayrı indeks yok.
