---
type: system
domain: sync
updated: 2026-08-24
tags: [system, sync, multiplayer]
---

# Share-Broadcast Flow — DM'in paylaştığı, oyuncuya canlı

> [!summary] Bir cümlede
> Oyuncunun cihazına giden **her satır, DM'in bilinçli bir paylaşım eylemidir.** Dünyanın tamamı hiçbir zaman replike edilmez.

Bu not, kaldırılan `Share-Broadcast-Flow`'un yerine geçer. Eski model dünyanın tamamını (entity'ler, harita, oturumlar, ayarlar, mind-map) Postgres'e aynalıyor ve oyuncunun görmemesi gerekenleri yalnızca istemci tarafında, `visibleEntityProvider` ile gizliyordu — yani veri oyuncunun diskindeydi. Migration **077** o aynayı düşürdü.

Cihazdan cihaza taşıma artık [[LAN-Sync-Flow]]'un işi. Yerel Drift kaynak-doğru.

## Kanal — abone olunan beş tablo

`WorldSyncService._mirrorTables` ([[world_sync_service]]) tek bir Supabase Realtime kanalı açar: `dmt:world:{worldId}`.

| Tablo | Taşıdığı | Yazan |
|---|---|---|
| `world_projection` | DM'in canlı yayını (projeksiyon manifesti) | DM — [[projection_output_online]] |
| `entity_shares` | Paylaşılan kartlar + **gövdeleri** (`payload_json`) | DM — `entity_share_prepare.dart` |
| `world_characters` | Oyuncunun karakter sayfası, claim/assign | Oyuncu ve DM |
| `world_packages` | DM'in dünyaya paylaştığı paketler | DM — `world_packages_provider` |
| `world_members` | Üyelik / rol | RPC'ler |

(+ `worlds`, `id` filtresiyle — yalnızca dünya meta'sı.)

> [!warning] Bu listeye tablo eklemek
> Oyuncunun cihazına DM'in paylaşmadığı veri göndermek demektir. Önce paylaşım eyleminin ne olduğunu tanımla, sonra tabloyu ekle.

## Paylaşılan kartın gövdesi nereden geliyor

`world_entities` aynası olmadığı için `entity_shares` artık sadece bir işaret değil, **kartı taşıyan kanal**:

```
DM "Paylaş" der
  └─ shareEntityWithPlayers()            entity_share_prepare.dart
       ├─ ilişki kapanışı (transitive)   — bağlantılı kartlar da paylaşılır
       ├─ yerel görselleri R2/free-media'ya yükle → AssetRef'e çevir
       ├─ PendingWriteBuffer.flushPrefix('entity:{worldId}:')
       │     └─ bayat kopya paylaşılmasın diye
       └─ her kapanış üyesi için:
            EntityShareService.shareWithAll(
              entityId, worldId,
              payload: entityToRaw(entity),   ← linked kartlarda null
            )
                 └─ INSERT entity_shares(..., payload_json)
                        └─ CDC ──▶ oyuncu
                             WorldMirrorApplier._applyEntityShareEvent
                               ├─ payload_json decode
                               └─ data['entities'][id] = payload
```

- `entityToRaw` / `entityFromRaw` ([[entity_provider]]) simetrik çifttir; payload şekli campaign blob'undaki `entities` satırının şeklidir. Round-trip koruması: `test/application/services/entity_share_payload_test.dart`.
- **`payload_json = NULL` → linked (paket / built-in) kart.** Gövdesi oyuncunun kurulu paketinden gelir; kopyalamak fork-on-edit riski ve gereksiz trafik olurdu.
- Görseller `AssetRef`'e çevrilmeden paylaşılırsa oyuncu çözemez (RLS yok, dosya sistemi yok). `ProjectionOutputOnline._warnRawPaths` debug'da bunu yakalar.
- **Un-share = DELETE.** Applier gövdeyi de düşürür (`_removeSharedEntity`) — aksi halde oyuncuda erişilemez ama duran bir kopya kalırdı. `REPLICA IDENTITY FULL` (migration 052) sayesinde DELETE payload'ı `world_id` taşır, realtime filtresine takılır.

## Yazma yolu — kuyruk yok, doğrudan yazma

Outbox + `SyncEngine` kaldırıldı. Kalan dört yazma yolu doğrudan yazar, last-write-wins, hata yutulur (yerel Drift kaynak-doğru):

- Karakter → `CharacterListNotifier._pushCharacterToMirror` (medya bundle + `world_characters` upsert)
- Kart paylaşımı → `EntityShareService`
- Paket paylaşımı → `share_package_to_world` RPC
- Projeksiyon → `ProjectionOutputOnline._upsert` (120 ms / 500 ms kademeli debounce)

`PendingWriteBuffer` ([[pending_write_buffer]]) **yerinde kalır** — yerel debounce'u o yapıyor ve [[LAN-Sync-Flow]] `flush()`'una bağlı.

> [!note] Çevrimdışı telafisi
> Kalıcı kuyruk yok. `CharacterListNotifier.pushOwnedCharacters(worldId)` dünya açılışında sahip olunan karakterleri bir kez yeniden yazar; LWW olduğu için kaçan bir yazmayı yakalamaya yeter. Kodda `ponytail:` yorumu ile işaretli — gerçekten dayanıklı kuyruk gerekirse outbox deseni geri gelir.

## Dünyaya katılma

`WorldJoinService.joinWithCode` ([[world_join_service]]):
1. `redeem_world_invite` RPC → `(worldId, worldName)`
2. Yerel Drift'te **boş** bir dünya kabuğu + SRD bootstrap
3. `WorldMirrorApplier.applyInitialState` → paylaşılan kartlar, karakterler, projeksiyon manifesti tek seferlik seed (CDC yalnızca abonelikten sonrasını taşır)

Eskiden burada `worlds.state_json` indiriliyordu — DM'in tüm dünyası. O kolon 077'de düştü; `publish_world` artık içerik yüklemez, sadece `worlds` satırı + DM üyeliği yazar.

## İlgili
- [[LAN-Sync-Flow]] — cihazdan cihaza taşımanın tek yolu
- [[Fog-of-War-and-Visibility]] — projeksiyon payload'ı kurulmadan önceki filtre
- [[Media-Storage-Tiers]] — paylaşılan görsellerin gittiği yer
- [[world_sync_service]] · [[world_mirror_applier]] · [[world_mirror_service]] · [[world_join_service]]
