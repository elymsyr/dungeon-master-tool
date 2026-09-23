---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_push_service.dart
layer: application
language: dart
status: active
updated: 2026-09-23
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
- Constructor: `AppDatabase db`, `SupabaseClient client`, `ContentRefIndex? index` (Faz 5d'ye kadar `SharedMediaCourier`).
- Reads (Drift): `worlds` / `packages` (bayrak + damga), `world_entities`, `world_settings`, `world_map_data`, `world_sessions`, `world_mind_map_nodes/_edges`, `encounters`, `combatants`, `combat_conditions`, `map_pins`, `timeline_pins`, `installed_packages`, `world_characters`, `package_entities`, `package_schemas`, `sync_tombstones`.
- Çağıran: [[cloud_push_provider]] (`CloudPushPump.push` / `pushPackage`), `save_sync_indicator.dart` ilk yayında `full: true`.

**Outputs**
- Supabase `upsert`: 12 dünya tablosu (`world_*` + `world_combatants` + `world_characters`) ve 3 paket tablosu (`user_packages`, `user_package_schemas`, `user_package_entities`); `delete`: tombstone'ların işaret ettiği satırlar, `unpublishPackage`'ta paketin kendisi.
- Writes (Drift): `worlds.last_cloud_push_at` / `packages.last_cloud_push_at` (tur temiz bittiyse), `sync_tombstones` temizliği, dirilen satırın `updated_at` tazelemesi.
- Public API: `pushWorld(worldId, {dmOnlyKeys, full, beforeRows})` / `pushPackage(packageId, {full})` → `CloudPushResult` (Faz 5d: `beforeRows` turun satırlarının andığı medyayla **upsert'ten önce** çağrılır — pompa baytları satırdan önce buluta çıkarıyor); `worldMediaRefs(worldId)` (dünyanın **bütün** satırlarının medyası, ağsız); `unpublishPackage(packageId)`; `collect(worldId, since, dmOnlyKeys)` ve `collectPackage(packageId, since, ownerId)` → `List<CloudPushBatch>` (**ağsız** ara adım, testin girdiği kapı); top-level `mediaRefsOf(batches)`.

## Dependencies & Links
- Depends on: [[cloud_mirror_tables]] (tablo eşlemesi), [[drift_database]], [[content_ref_index]] (`refFor` → `dmt-content://`), [[world_media_sync]] (`WorldMediaRef`, `worldMediaKindOf`), `isOfflineError`.
- Used by: [[cloud_push_provider]], [[save_sync_indicator]].
- Karşı yön (gelen): [[cloud_pull_service]].
- Damga/tombstone sözleşmesi: `sync_stamp.dart` — DAO'lar `stampedNow` ile upsert damgalar, `recordTombstone(s)` ile silme kaydeder.
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.3 (CDC değil artımlı çekme), §2.8 (düzenleme zamanı), §4.6 (Faz 4a), §4.7 (Faz 4b).

## Key Logic / Variables
- **Turun sırası:** `cutoff = now()` taramadan **önce** alınır (tur sürerken düzenlenen satır bir sonraki tura kalsın) → tombstone'lar → tablo tablo upsert → damga `cutoff`'a çekilir. Hata çıkarsa damga **ilerlemez**: aynı satırlar bir sonraki turda yeniden gider, upsert idempotent olduğu için zararsız.
- **`mirrorTables` / `packageTables`:** yerel→bulut eşlemesi bildirimsel iki liste, Faz 5a'da [[cloud_mirror_tables]]'a taşındı (pull aynı bildirimi ters yönde okuyor). Kolon adları çoğunlukla iki tarafta aynı (Drift SQL'i snake_case üretiyor), o yüzden eşleme bir isim listesi + dönüşüm bayrakları: `dateCols` (unix saniye → ISO), `boolCols` (SQLite 0/1 → `boolean`), `mediaCols` (yerel yol → `dmt-content://`), `jsonCols` (TEXT → `jsonb`), `rename` (ayrışan kolon adı), `scope` (tarama kolonu: `world_id` / `package_id` / `id`), `owner` (`owner_id`'nin kaynağı: satırın kendisi / NULL / oturumdaki kullanıcı), `sinceAll` (damgayı yok say).
- **Paket ebeveyni her tur gider:** `user_packages` satırı çocukların FK hedefi. Damgaya baksaydı, yalnız bir kart değişen turda ebeveyn gitmez ve bulutta satır yoksa çocuklar reddedilirdi. Tek satır, ihmal edilebilir maliyet.
- **Karakterin blob'u açılmıyor:** `payload_json` `mediaCols`'ta **yok** — byte-for-byte koruma kuralı (bkz. `world_characters_dao`) medya çevirisine ağır basıyor. `referenced_entity_ids_json` ise `jsonCols` + `rename` ile `referenced_entity_ids` (jsonb) olarak gidiyor.
- **Combatant ayrı:** yerel `combatants`'ta `world_id` yok (encounter üzerinden gelir) ve durum etkileri bulutta ayrı satır değil, `conditions_json` kolonu. `_collectCombatants` JOIN'li sorguyu ve koşul katlamasını yapar.
- **`dm_only_keys` (§2.6):** kategori şemada **yoksa** buluta `NULL` gider ve `get_shared_entities` o kartı oyuncuya hiç döndürmez. Boş liste "sır yok" demektir — ikisi karıştırılmamalı.
- **Reddedilen satır:** parça reddedilirse (kota, 256 KB, RLS) suçlu tek tek denenerek bulunur, `rejected`'e yazılır ve **atlanır**; damga yine ilerler. Tek bir dev kart bütün dünyanın senkronunu kilitlemesin.
- **Diriltme koruması:** tombstone yazıldıktan sonra aynı id yerelde geri geldiyse (import / full-replace) bulut satırı silinmez — kayıt düşülür ve satır **şimdiyle damgalanır** ki bu turun taramasına girsin. Sadece atlamak yetmezdi: geri gelen satır eski `updated_at` taşıyor olabilir.
- **Medya:** gövdeler şemasız geziliyor; mutlak yol taşıyan her string `ContentRefIndex.refFor` ile içerik ref'ine çevriliyor. Yerel satır yolunu korur, çeviri yalnız giden kopyada (Faz 3.5 sözleşmesi).
- **`mediaRefsOf` (Faz 5d)** giden satırların `mediaCols`'unu (düz ref ya da JSON metni) gezip her `dmt-content://` için sha → `WorldMediaRef(ext, kind)` çıkarır. Sınıf: `.pdf` / ses uzantısı önce; sonra tablo — `world_map_data` ve `world_encounters` harita (10 MB), geri kalan "diğer" (5 MB). Aynı sha iki yerdeyse harita kazanır, sıra fark etmez. Medya kolonu olmayan kolondaki ref sayılmaz. Pompa bunu `beforeRows` üzerinden [[world_media_sync]]'e verir; bayt yükleme bu serviste değil.
- **Kendi yankısını elemek — `ownRunEnd` (Faz 5b).** Sayaç her yazmada artıyor ve Realtime sinyali yazan cihaza da geliyor; önlem olmasa DM'in her düzenlemesi kendi pull'unda geri inerdi. Upsert `select('revision')` ile yazılan satırların revizyonlarını döndürüyor (097'nin LWW guard'ının atladığı satır dönmüyor). Tur temiz bittiyse ve **silme yoksa**, `ownRunEnd(base, revs)` bu revizyonlar `worlds.cloud_revision`'ın hemen ardından boşluksuz bir dizi mi diye bakıyor: öyleyse aradaki her yazma bizim, yerel zaten o halde → damga dizinin sonuna **koşullu** UPDATE ile ilerliyor (`WHERE cloud_revision = base`, tur sürerken bir pull ilerlettiyse dokunmuyor). Bir boşluk başka bir yazar demek, damga yerinde kalır ve pull onu getirir. `base`'den küçük revizyonlar echo guard'ın yazmadığı satırlar, sayılmıyor. Silmeli turda ilerleme yok: tombstone'un revizyonu DELETE'ten dönmüyor. Yalnız dünyada; paket pull'u yok (Faz 5c). **097 C'ye bağlı:** o düzeltme olmadan upsert'in INSERT dalı her güncellemede ölü bir revizyon yakıyordu ve dizi hiç boşluksuz çıkmazdı.
- **Paketin satırı ilk yayından sonra yalnız UPDATE (Faz 5c).** `user_packages` her tur gidiyor (çocukların FK hedefi, `sinceAll`); upsert'le gitseydi öbür cihazın buluttan sildiği ya da "Yerele al" dediği paketi bu cihazın ilk turu yeniden yaratırdı. `full` ya da `last_cloud_push_at` boşsa upsert (ilk yayın), değilse `_updatePackageRow`: PATCH → boşsa bir GET daha (boş dönüş 097'nin LWW atlaması da olabilir, silme sanılmasın) → satır gerçekten yoksa `setOnline(false)` ve tur `skipped`. Dünyada bu yok: `worlds` satırını yalnız `publish_world` RPC'si yaratıyor.
- **Sunucu tarafı LWW (097).** Push hâlâ düz upsert ama bulut artık `NEW.updated_at < OLD.updated_at` olan satırı ve tombstone'dan eski bir düzenlemenin INSERT'ini sessizce atlıyor. İstemci tarafında değişen bir şey yok: atlanan satır `rejected`'e **düşmez** (hata değil), yalnız revizyon listesinde görünmez — ve o boşluk `ownRunEnd`'i durdurur, pull bulutun daha yeni halini getirir.

## Notes
- Test: `test/application/services/cloud_push_collect_test.dart` (16 test) — `collect` / `collectPackage` üzerinden, ağsız; `ownRunEnd` saf fonksiyon olarak.
- Bilinçli sınırlar (§4.6, §4.7): `revision` istemcide yazılmıyor, reddedilen satır kullanıcıya gösterilmiyor, uygulama kapanırken "son tur" yok, `updated_at` için ayrı indeks yok, paketin **silinmesi** buluta gitmiyor (bulut kopyasını düşüren tek yol "Yerele al"), `world_characters.is_online` kolonu okunmuyor (Faz 5.5).
- Migration `095` (karakterin sunucu damgasını düşüren trigger) ve `096` (echo guard) **2026-09-22'de deploy edildi**, `097` (sunucu LWW) deploy bekliyor; **gerçek projede uçtan uca doğrulama hâlâ bekliyor** — koşulacak adımlar `docs/online-sync-redesign.md` §4.7 "Bekleyen doğrulama".
- `sync_tombstones.world_id` artık "kapsam id'si" demek: dünya turunda dünya, paket turunda paket. Kolonu yeniden adlandırmak yan tablonun idempotent DDL'ini kırardı.
