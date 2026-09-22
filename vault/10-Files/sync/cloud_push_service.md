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
> Push'un giden yolu: yereldeki satırları Supabase ayna tablolarına yazar. Kuyruk tutmaz — gönderilecek işin listesi yerine "nereye kadar gidildi" tarihini hatırlar, her turda `updated_at > damga` olan satırları tarar. Çevrimdışıyken tur hiç koşmaz, damga ilerlemez, satırlar yerinde birikir; ağ dönünce aynı tarama onları bulur.
>
> **İki kapsam:** dünya (`pushWorld`, damga `worlds.last_cloud_push_at`) ve paket (`pushPackage`, damga `packages.last_cloud_push_at`, satırlar `owner_id`'ye bağlı). Faz 4b'den beri karakterler de dünya turunda.

> [!warning] Bu `SyncEngine` değil
> Eski bulut sync'in 998 satırlık outbox motoru **geri gelmedi** ve gelmeyecek. Yazma noktalarında `enqueue` çağrısı yok; tek girdi satırın kendi `updated_at`'i. Kararın gerekçesi ve outbox ile karşılaştırması: `docs/online-sync-redesign.md` §4.6–§4.7.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase db`, `SupabaseClient client`, `SharedMediaCourier? courier`.
- Reads (Drift): `worlds` / `packages` (bayrak + damga), `world_entities`, `world_settings`, `world_map_data`, `world_sessions`, `world_mind_map_nodes/_edges`, `encounters`, `combatants`, `combat_conditions`, `map_pins`, `timeline_pins`, `installed_packages`, `world_characters`, `package_entities`, `package_schemas`, `sync_tombstones`.
- Çağıran: [[cloud_push_provider]] (`CloudPushPump.push` / `pushPackage`), `save_sync_indicator.dart` ilk yayında `full: true`.

**Outputs**
- Supabase `upsert`: 12 dünya tablosu (`world_*` + `world_combatants` + `world_characters`) ve 3 paket tablosu (`user_packages`, `user_package_schemas`, `user_package_entities`); `delete`: tombstone'ların işaret ettiği satırlar, `unpublishPackage`'ta paketin kendisi.
- Writes (Drift): `worlds.last_cloud_push_at` / `packages.last_cloud_push_at` (tur temiz bittiyse), `sync_tombstones` temizliği, dirilen satırın `updated_at` tazelemesi.
- Public API: `pushWorld(worldId, {dmOnlyKeys, full})` / `pushPackage(packageId, {full})` → `CloudPushResult`; `unpublishPackage(packageId)`; `collect(worldId, since, dmOnlyKeys)` ve `collectPackage(packageId, since, ownerId)` → `List<CloudPushBatch>` (**ağsız** ara adım, testin girdiği kapı).

## Dependencies & Links
- Depends on: [[drift_database]], [[shared_media_courier]] (`refFor` → `dmt-content://`), `isOfflineError`.
- Used by: [[cloud_push_provider]], [[save_sync_indicator]].
- Damga/tombstone sözleşmesi: `sync_stamp.dart` — DAO'lar `stampedNow` ile upsert damgalar, `recordTombstone(s)` ile silme kaydeder.
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.3 (CDC değil artımlı çekme), §2.8 (düzenleme zamanı), §4.6 (Faz 4a), §4.7 (Faz 4b).

## Key Logic / Variables
- **Turun sırası:** `cutoff = now()` taramadan **önce** alınır (tur sürerken düzenlenen satır bir sonraki tura kalsın) → tombstone'lar → tablo tablo upsert → damga `cutoff`'a çekilir. Hata çıkarsa damga **ilerlemez**: aynı satırlar bir sonraki turda yeniden gider, upsert idempotent olduğu için zararsız.
- **`_mirrorTables` / `_packageTables`:** yerel→bulut eşlemesi bildirimsel iki liste. Kolon adları çoğunlukla iki tarafta aynı (Drift SQL'i snake_case üretiyor), o yüzden eşleme bir isim listesi + dönüşüm bayrakları: `dateCols` (unix saniye → ISO), `boolCols` (SQLite 0/1 → `boolean`), `mediaCols` (yerel yol → `dmt-content://`), `jsonCols` (TEXT → `jsonb`), `rename` (ayrışan kolon adı), `scope` (tarama kolonu: `world_id` / `package_id` / `id`), `owner` (`owner_id`'nin kaynağı: satırın kendisi / NULL / oturumdaki kullanıcı), `sinceAll` (damgayı yok say).
- **Paket ebeveyni her tur gider:** `user_packages` satırı çocukların FK hedefi. Damgaya baksaydı, yalnız bir kart değişen turda ebeveyn gitmez ve bulutta satır yoksa çocuklar reddedilirdi. Tek satır, ihmal edilebilir maliyet.
- **Karakterin blob'u açılmıyor:** `payload_json` `mediaCols`'ta **yok** — byte-for-byte koruma kuralı (bkz. `world_characters_dao`) medya çevirisine ağır basıyor. `referenced_entity_ids_json` ise `jsonCols` + `rename` ile `referenced_entity_ids` (jsonb) olarak gidiyor.
- **Combatant ayrı:** yerel `combatants`'ta `world_id` yok (encounter üzerinden gelir) ve durum etkileri bulutta ayrı satır değil, `conditions_json` kolonu. `_collectCombatants` JOIN'li sorguyu ve koşul katlamasını yapar.
- **`dm_only_keys` (§2.6):** kategori şemada **yoksa** buluta `NULL` gider ve `get_shared_entities` o kartı oyuncuya hiç döndürmez. Boş liste "sır yok" demektir — ikisi karıştırılmamalı.
- **Reddedilen satır:** parça reddedilirse (kota, 256 KB, RLS) suçlu tek tek denenerek bulunur, `rejected`'e yazılır ve **atlanır**; damga yine ilerler. Tek bir dev kart bütün dünyanın senkronunu kilitlemesin.
- **Diriltme koruması:** tombstone yazıldıktan sonra aynı id yerelde geri geldiyse (import / full-replace) bulut satırı silinmez — kayıt düşülür ve satır **şimdiyle damgalanır** ki bu turun taramasına girsin. Sadece atlamak yetmezdi: geri gelen satır eski `updated_at` taşıyor olabilir.
- **Medya:** gövdeler şemasız geziliyor; mutlak yol taşıyan her string `SharedMediaCourier.refFor` ile içerik ref'ine çevriliyor. Yerel satır yolunu korur, çeviri yalnız giden kopyada (Faz 3.5 sözleşmesi).

## Notes
- Test: `test/application/services/cloud_push_collect_test.dart` (15 test) — `collect` / `collectPackage` üzerinden, ağsız.
- Bilinçli sınırlar (§4.6, §4.7): `revision` istemcide yazılmıyor, reddedilen satır kullanıcıya gösterilmiyor, uygulama kapanırken "son tur" yok, `updated_at` için ayrı indeks yok, paketin **silinmesi** buluta gitmiyor (bulut kopyasını düşüren tek yol "Yerele al"), `world_characters.is_online` kolonu okunmuyor (Faz 5.5).
- `sync_tombstones.world_id` artık "kapsam id'si" demek: dünya turunda dünya, paket turunda paket. Kolonu yeniden adlandırmak yan tablonun idempotent DDL'ini kırardı.
