---
type: system
domain: sync
updated: 2026-10-02
tags: [system, sync, multiplayer]
---

# Share-Broadcast Flow — DM'in paylaştığı, oyuncuya canlı

> [!summary] Bir cümlede
> Oyuncunun cihazına giden **her satır, DM'in bilinçli bir paylaşım eylemidir.** Dünyanın tamamı hiçbir zaman replike edilmez.

> [!warning] Kategoriye göre otomatik paylaşım kaldırıldı (2026-09-14)
> Publish tohumu artık Tier 0 / Tier 1 kuralına bakmıyor. Paylaşımın tek kaynağı DM'in kart başına koyduğu işaret: `world_settings.settings_json` → `shared_entities` ([[shared_entity_provider]]).
>
> İşaret **dünya offline'ken de** konulabiliyor. Orada hiçbir şey yapmaz; amacı DM'in dünyayı kurarken ileride neyin oyuncuya gideceğini önden seçmesi. Dünya online'a alındığında tohum tam olarak o seti yükler.

Bu not, kaldırılan `Share-Broadcast-Flow`'un yerine geçer. Eski model dünyanın tamamını (entity'ler, harita, oturumlar, ayarlar, mind-map) Postgres'e aynalıyor ve oyuncunun görmemesi gerekenleri yalnızca istemci tarafında, `visibleEntityProvider` ile gizliyordu — yani veri oyuncunun diskindeydi. Migration **077** o aynayı düşürdü.

Cihazdan cihaza taşıma bulut aynasının ([[cloud_push_service]] / [[cloud_pull_service]]) ya da `.dmtz`'nin işi; LAN Faz 6'da silindi. Yerel Drift kaynak-doğru.

## Kanal — abone olunan beş tablo

`WorldSyncService._mirrorTables` ([[world_sync_service]]) tek bir Supabase Realtime kanalı açar: `dmt:world:{worldId}`.

| Tablo | Taşıdığı | Yazan |
|---|---|---|
| `world_projection` | DM'in canlı yayını (projeksiyon manifesti) | DM — [[projection_output_online]] |
| `entity_shares` | Paylaşılan kartların izni (gövde Faz 5.5b'den beri `get_shared_entities`'ten) | DM — `entity_share_prepare.dart` |
| `world_characters` | Oyuncunun karakter sayfası, claim/assign | Oyuncu ve DM |
| `world_packages` | DM'in dünyaya paylaştığı paketler | DM — `world_packages_provider` |
| `world_members` | Üyelik / rol | RPC'ler |

(+ `worlds`, `id` filtresiyle — yalnızca dünya meta'sı.)

> [!warning] Bu listeye tablo eklemek
> Oyuncunun cihazına DM'in paylaşmadığı veri göndermek demektir. Önce paylaşım eyleminin ne olduğunu tanımla, sonra tabloyu ekle.

## Paylaşılan kartın gövdesi nereden geliyor

> [!info] Faz 5.5b (2026-10-02) — gövde DM'in bulut aynasından, oyuncuda yerelde
> `entity_shares` yalnız izin (`payload_json` migration **103**'te düştü); gövde DM'in `world_entities` satırından, sunucuda kırpılmış geliyor ve oyuncunun Drift'ine yazılıyor. Açılışta ve her sinyalde yalnız **doğrulama**: damga listesi (`get_shared_entity_stamps`, migration 102) yerelle karşılaştırılır, eksik/değişen kart id ile iner. DM'in düzeltmesi yeniden paylaşmadan gidiyor: push turu + sinyal.

```
DM "Paylaş" der
  └─ shareEntityWithPlayers()            entity_share_prepare.dart
       ├─ ilişki kapanışı (transitive)   — bağlantılı kartlar da paylaşılır
       └─ INSERT entity_shares(...)      — yalnız izin
DM'in push turu (CloudPushService)
  └─ world_entities satırı + dm_only_keys = dmOnlyKeysBySlug(şema)[slug]
       └─ world_revisions sinyali

Oyuncu — WorldMirrorApplier._syncShared → CloudPullService.syncSharedEntities
  tetik: açılış · entity_shares INSERT/UPDATE · world_revisions sinyali
         (1 sn sessizlikte birleşir — DM'in turu satır başına sinyal üretir)
  ├─ get_shared_entity_stamps(world)        → (id, updated_at, linked)
  ├─ yerel updated_at ile karşılaştır       → eksik / daha yeni, linked hariç
  ├─ get_shared_entities(world, 0, ids)     → yalnız onlar
  └─ Drift'e yaz (LWW) + açık dünyanın blob'una işle
```

- **Redaksiyon SQL'de, karar Dart'ta (§2.6).** `dmOnlyKeysBySlug` ([[entity_share_prepare]]) neyin sır olduğuna karar veren tek fonksiyon: bulut satırının `dm_only_keys`'i buradan gelir. RPC `dm_notes`'u hiç seçmiyor, `fields_json::jsonb - dm_only_keys` yapıyor; `dm_only_keys` NULL ise (şemada olmayan kategori) kart hiç dönmüyor. Oyuncuya giden kartta sır kalmadığının koruması: `test/application/services/shared_entity_redaction_test.dart` (gerçek SQL'inki `verify_094` §6 ve `verify_102`).
- `sharedEntityRowToRaw` RPC satırını `entityToRaw` şekline çevirir ([[entity_provider]]'ın `entityFromRaw`'ı okur). Round-trip koruması: `entity_share_payload_test.dart`.
- **Linked kart** RPC'den gelse de atlanır: gövdesi oyuncunun kurulu paketinden gelir. Paketteki `secrets` alanları zaten oyuncunun diskinde — paket dağıtımı ayrı bir problem.
- Medya: bulut satırı push'ta `dmt-content://{sha}{ext}`'e çevrilmiş; baytlar dünyanın R2 medyasında ([[world_media_sync]]), oyuncu imzalı URL'le çeker ([[asset_ref_resolver]]). Bkz. [[Media-Storage-Tiers]].
- DM'e gövde yazılmaz: [[world_mirror_applier]] rol DM ise atlar, buluttaki içerik ref'leri DM'in yerel dosya yollarını ezerdi.
- **Un-share = DELETE → oyuncudan silinir (2026-10-02, el testi).** DELETE event'i doğrulamayı tetikler; [[cloud_pull_service]] `syncSharedEntities` damga listesinde olmayan homebrew kartı oyuncunun Drift'inden siler (`removeUnsharedEntities`), [[world_mirror_applier]] açık blob'dan düşürür. DM'in **sildiği** kart da aynı yoldan gider (paylaşım satırı kalsa da damga listesinden düşer). Gri kart kalktı. *Eski hali:* **gövde silinmezdi (§2.5).** Kart oyuncunun Drift'inde kalır, gri ve "DM bu kartı artık paylaşmıyor" etiketiyle görünür — dünya yeniden açılınca da: `revokedSharedEntityIdsProvider` (`visible_entity_provider.dart`, hesabı saf `revokedSharedIds`) blob'daki her homebrew kartı paylaşım listesiyle **ve** son doğrulamanın görünür listesiyle (`sharedEntityStampIdsProvider`, `v_shared_entities`) karşılaştırır. İkincisi DM'in **sildiği** kartı yakalar: silme paylaşım satırını bırakıyor, kart buluttan gidince listeden düşer. Paylaşım listesi (`worldEntitySharesProvider`) hatayı yukarı iletir — boş liste her kartı griye çevirirdi. Yeniden paylaşılırsa doğrulama yeni halini indirir (geri çekiliyken düzenlenmiş olsa da — karşılaştırma kart başına `updated_at`). `REPLICA IDENTITY FULL` (migration 052) sayesinde DELETE payload'ı `world_id` taşır, realtime filtresine takılır.

## Paylaşım ne zaman tetiklenir

Dört giriş noktası, hepsi `entitySharerProvider` ([[entity_share_prepare]] içindeki `EntitySharer`) üzerinden — köprü, paylaşımın hem widget'lardan (`WidgetRef`) hem `EntityNotifier`'dan (`Ref`) çağrılabilmesi için var:

Hepsi `EntitySharer.setShared(entityId:, shared:, worldId:)` üzerinden geçer — **işaret her zaman yerele yazılır**, bulut satırı yalnızca dünya gerçekten online ve rol DM ise gider. Fonksiyon buluta yazıp yazmadığını `bool` döndürür; UI mesajını ona göre kurar ("Shared with all players" / "Marked to share — goes out when the world goes online").

1. **Kart menüsü** — açık karttaki "Share" toggle'ı (`entity_card.dart`). Artık DM + offline (rol `none`) için görünür; yalnız oyuncuda gizli — projeksiyon menüsüyle aynı kapı.
2. **Oluşturma kutucuğu** — "Yeni kart" diyaloğundaki *Share with players* checkbox'ı, dünya offline olsa da. Varsayılan **tier'a bağlı**: Tier 0 (lookup) ve Tier 1 (içerik) açık, Tier 2 (NPC, sahne, quest — DM'e ait kampanya içeriği) ve `seedExcludedSlugs` (canavar, loot) kapalı. Bu tier kuralı artık **yalnızca varsayılan kutucuk hâli**; paylaşımı kendisi yapmıyor. Kullanıcı kutuya dokunduysa seçim kategori değişse de korunur (`entity_sidebar._showCreateDialog`).
3. **Düzenleme** — paylaşım satırına dokunmaz (`_pushIfShared` 2026-10-02'de kalktı). Düzenleme bulut aynasına push turuyla çıkar, `world_revisions` sinyali oyuncunun doğrulamasını tetikler.

4. **Publish tohumu** — DM dünyayı online'a aldığında `seedAndAnnounceWorldContent` ([[online_world_widgets]]) → `seedSharedContentToPlayers` ([[entity_share_prepare]]) `shared_entities` setindeki kartları tek seferde yükler.
   - Seçim kuralı saf hâlde `seedShareIds(entities, markedIds)`: işaretler ∩ dünyada gerçekten duran kartlar. Silinmiş kartın artık işareti blob'da kalabiliyor; onu sokmak gövdesiz satır yazardı.
   - `allowedSlugs` parametresi **kaldırıldı** (2026-09-14). Kategori filtresi kalmadığı için kapanış davranışı her iki yolda aynı: DM bir kartı paylaştığında relation kapanışı da gider, yoksa oyuncuda dangling satır kalır.
   - `linked == true` kart da işaretliyse gider — DM bilinçli seçmiştir. Gövdesi oyuncunun kurulu paketinden gelir.
   - Bayrak yok: `unpublishWorld` bulut satırlarını cascade siliyor, tekrar online olmak sıfırdan tohumlamalı. İşaret seti yerelde durduğu için tohum aynı listeyi tekrar yükler.
   - **Publish'in İKİ girişi var** ve ikisi de bu yardımcıdan geçmek zorunda: dünya ayarları toggle'ı (`online_world_section._publish`, hub'dan aktif OLMAYAN bir dünya için de açılabiliyor) ve dünya içindeki "Make Online" (`save_sync_indicator._makeOnline`). Hub yolu `campaignData`'yı geçirir — kartlar, şema **ve işaret seti** o blob'dan okunur; provider'lar her zaman AKTİF kampanyayı okur, yani oradan tohumlamak yanlış dünyanın kartlarını paylaşırdı.
   - **Yazma toplu.** `EntityShareService.shareManyWithAll` tek `DELETE ... IN (...)` + 50'lik `INSERT` parçaları atar. Bir parça düşerse (4000 satır tavanı) o parça satır satır tekrar denenir ve yazılamayan id'ler `debugPrint`'e düşer — publish hiçbir durumda düşmez.
   - DM tek `AlertDialog` ile bilgilendirilir (`worldContentSharedTitle` / `...Body`). Koruma: `test/application/services/entity_share_seed_test.dart`.

## Paketlenmiş dünya işaretle gelir

`world-blueprint.json`'ın kökündeki **`shared`** listesi (`pinned` ile aynı `kategori/isim` biçimi) kurulumda entity id'lerine çözülüp `shared_entities` anahtarına yazılıyor — [[bundled_worlds_installer]] §5. Yani marketplace'ten indirilen ya da klasörden aktarılan dünyada DM hiçbir şey işaretlemeden doğru set hazır: yazarın "oyun başında oyuncunun bilmesi gereken" dediği kartlar. Ölçü dar tutuluyor: **yalnız Tier 0/1 oyuncu içeriği** — subclass, background, trait, resource-pool, sıradan eşya. **Tier 2 asla** (campaign, lore, location, npc, scene, encounter, quest, curse): o kartlar DM odaklı yazılıyor ve oyuncunun henüz bilmediğini bildiriyorlar. `seedExcludedSlugs`'ın canavar/loot seti de dışarıda, Tier 1 içinde sır taşıyan tekil kartlar da (Aegis'te `Direnç Şerbeti`, üç mühür, canavar trait'leri). Act 1'de 54 kart. Kural: `assets/worlds/aegis/README.md` §4.9.

## Eski dünyalar — tek seferlik geçiş

Tier tohumu kaldırılmadan önce online olmuş dünyalarda gerçek buluttaki `entity_shares` satırlarıydı, yerelde işaret yoktu. `SharedEntityNotifier._adoptCloudShares` ([[shared_entity_provider]]) anahtar yokken dünya online + rol DM ise o id'leri bir kez yerele alır. Olmasaydı DM o kartları "paylaşılmamış" görür, paylaşımı kapatamazdı. Offline dünyada hiçbir şey yazılmaz.

## Nerede görünüyor

- **Sidebar satırı** — kategori noktası paylaşıma işaretli kartlarda `Icons.public` (dünya) olur; pin varsa iğne kazanır, iki işaret birden gösterilmez ([[entity_sidebar]] `EntityRowTile`).
- **Sharing filtresi** — "Marked shared / Not shared / Built-in" chip'i artık **dünya offline'ken de** açık; yalnız oyuncuda gizli. DM neyi önden işaretlediğini publish etmeden görebilmeli.

## Yazma yolu — kuyruk yok, doğrudan yazma

Outbox + `SyncEngine` kaldırıldı. Kalan dört yazma yolu doğrudan yazar, last-write-wins, hata yutulur (yerel Drift kaynak-doğru):

- Karakter → Faz 5g'den beri doğrudan değil: karakter turu ([[cloud_push_provider]] `characterEdited` → 1 sn → [[cloud_push_service]] `pushCharacters`, medyası `characters/{id}/`). `world_characters` yine abone tablo; turun yazdığı satırın yankısı `markPushed` ile eleniyor
- Kart paylaşımı → `EntityShareService`
- Paket paylaşımı → `share_package_to_world` RPC
- Projeksiyon → `ProjectionOutputOnline._upsert` (120 ms / 500 ms kademeli debounce)

`PendingWriteBuffer` ([[pending_write_buffer]]) **yerinde kalır** — yerel debounce'u o yapıyor ve bulut `catchUp`'ı ile `.dmtz` `flush()`'una bağlı.

> [!note] Çevrimdışı telafisi
> Kalıcı kuyruk yok. `CharacterListNotifier.pushOwnedCharacters(worldId)` dünya açılışında sahip olunan karakterleri bir kez yeniden yazar; LWW olduğu için kaçan bir yazmayı yakalamaya yeter. Kodda `ponytail:` yorumu ile işaretli — gerçekten dayanıklı kuyruk gerekirse outbox deseni geri gelir.

## Dünyaya katılma

`WorldJoinService.joinWithCode` ([[world_join_service]]):
1. `redeem_world_invite` RPC → `(worldId, worldName)`
2. Yerel Drift'te **boş** bir dünya kabuğu + SRD bootstrap
3. `WorldMirrorApplier.applyInitialState` → paylaşılan kartlar, karakterler, projeksiyon manifesti tek seferlik seed (CDC yalnızca abonelikten sonrasını taşır)

Eskiden burada `worlds.state_json` indiriliyordu — DM'in tüm dünyası. O kolon 077'de düştü; `publish_world` artık içerik yüklemez, sadece `worlds` satırı + DM üyeliği yazar.

## İlgili
- [[cloud_push_service]] / [[cloud_pull_service]] — cihazdan cihaza taşıma (bulut aynası)
- [[Fog-of-War-and-Visibility]] — projeksiyon payload'ı kurulmadan önceki filtre
- [[Media-Storage-Tiers]] — paylaşılan görsellerin gittiği yer
- [[world_sync_service]] · [[world_mirror_applier]] · [[world_mirror_service]] · [[world_join_service]]
