---
type: system
domain: sync
updated: 2026-08-25
tags: [system]
---

# LAN Sync Flow

> [!summary] What this is
> Kullanıcının **kendi cihazları** arasında, aynı yerel ağda, manuel ve çift
> yönlü içerik eşlemesi. Supabase ve R2'ye hiç dokunmaz — içerik "online
> yapılmadan" telefon ile bilgisayar arasında taşınır. [[Share-Broadcast-Flow]]'un LAN
> kardeşi ama outbox'ı kullanmaz; cloud-backup round-trip'ini
> (`repository.load` → blob → `repository.save`) ikinci bir "bulut" üzerinden
> konuşur. Owned by [[Sync-and-Realtime]].

## Neden outbox değil
`SyncEngine` outbox satırları Postgres tablosuna yazmak için var
(`_handle*` → [[world_mirror_service]] → Supabase) ve [[world_mirror_applier]]
gelen değişikliği *aktif kampanya* blob'una uygular — arka planda rastgele bir
world'e uygulanamaz. LAN peer'ını sahte bir Postgres'e çevirmek gerekirdi. Onun
yerine `CloudBackupNotifier.restoreBackup`'ın kanıtlanmış "payload map → yerel
kayıt" yolu yeniden kullanıldı; yeni merge mantığı yazılmadı.

## Participants
- [[lan_sync_protocol]] — DTO'lar, LWW diff, HMAC, QR daveti, presence paketi.
- [[lan_device_store]] — bu cihazın kimliği + kalıcı eşleşme kayıtları.
- [[lan_sync_server]] — host: `HttpServer` + presence beacon + eşleşme uçları.
- [[lan_sync_client]] — imzalı çağrılar, `/pair` el sıkışması, presence dinleyici.
- [[lan_sync_session]] — manifest, item okuma/uygulama, medya + yol yeniden yazımı.
- `lan_sync_provider.dart` — durum makinesi; `syncAll()` ve eşleşme aksiyonları.
- `lan_sync_dialog.dart` — tek ekran: QR + cihaz listesi + **Eşle** / **Cihaz ekle**.

## Eşleşme (bir kez, kalıcı)
1. Panel açılır → sunucu ayağa kalkar, `/pair` açılır, 32 baytlık `pairToken`
   (3 dk'da bir döner), 6 haneli PIN ve QR üretilir.
2. QR metni: `dmt2:<base64url(json)>` → `{i: deviceId, n: name, a: [ip…], p: port, t: pairToken, u: uid}`.
3. Diğer cihaz QR'ı okutur **ya da** `IP:port` + PIN girer. PIN yolunda
   imzasız `GET /hello` nonce'u verir (`pairing:false` ise "orada paneli aç" der).
4. `POST /pair` → `{deviceId, name, uid, half}`, geçici anahtarla imzalı.
5. Host `uid`'yi kendisininkiyle karşılaştırır; tutmazsa **403 `account_mismatch`**.
6. Host kendi `half`'ini üretir, `shared = base64(sha256("clientHalf|hostHalf"))`
   hesaplayıp karşı cihazı kaydeder, `{deviceId, name, half}` döner.
7. İstemci aynı `shared`'ı hesaplar ve host'u kaydeder → **iki tarafta simetrik kayıt.**

Bundan sonra bütün istekler `shared` ile imzalanır; arayanın kimliği
`X-DMT-Device` başlığından bulunur (imzasız başlık — yanlışsa imza tutmaz).

## Sync (tek tuş)
"Eşle" → **her** eşleşmiş cihaz için sırayla: `GET /manifest` → `diffManifests`
(LWW) → pull/push. Önizleme adımı yok; ilerleme satırı + sonunda
"N içerik · M cihaz" özeti. Ulaşılamayan cihaz akışı durdurmaz, sonunda listelenir.

Presence'e güvenip "offline" görünenler atlanmaz — UDP engelli ağlarda yanlış
offline yüzünden sync hiç çalışmasın istenmiyor.

## Ne taşınır — world item'ının kapsamı
`campaignRepository.load(name)` blob'u (cloud-backup ile birebir aynı kontrat):
entity'ler, world schema, `combat_state` (encounter'lar + battlemap + session
notları), `mind_maps`, `map_data`, `sessions`, `pdf_library` manifest'i.
Medya olarak iki kaynak taranır:
1. `{worldsDir}/{worldName}/` altındaki her dosya (haritalar, görseller,
   `pdfs/`) — yerel yollu (offline dünya) medya buradadır.
   Buraya **girmesi** de garanti altında: seçicinin verdiği ham yol
   (`.../Downloads/map.png`) veri kökünün dışında kaldığı için taşınamıyordu.
   Kural artık koşulsuz — **seçilen her dosya kopyalanır**, bulut yüklemesi
   başarılı olsa da olmasa da; yükleme de kopyadan yapılır. Ham yol hiçbir
   yerde saklanmıyor. Kopya bulut yüklemesi başarılıyken de duruyor: R2 nesnesi
   temizlenir ya da içerik önbelleği boşalırsa resim yine açılabilsin.
   Kapsanan seçim noktaları: `uploadMapImage` (battle map / world map /
   mindmap), `eagerUploadEntityImages` (entity resimleri),
   `MetadataEditorSection._pickCover` (dünya/paket/karakter kapağı),
   `CharacterRepository.save` (portre — tek çıkış kapısı olduğu için editör,
   sihirbaz ve içe aktarma birlikte kapsanıyor), entity `file`/`pdf` alanları
   (`localizeEntityFiles` → `files/`). Ayrıca `loadItem` içinde tek bir onarım
   geçişi (`LocalMediaLocalizer.localizeWorldPayload`) eski dünyalarda kalmış
   ham yolları da içeri alıyor. Bu olmadan battle map arka planları ve mindmap
   not resimleri karşı cihaza hiç gitmiyordu.
   Karakter medyası düz `{charactersDir}` altında durup `{id}_` önekiyle
   süzüldüğü için kopya o adla açılıyor (`localizeCharacterImage`).
   Bedeli: bulut yüklemesi başarılıyken aynı baytlar hem `media/` altında hem
   içerik önbelleğinde duruyor, yani disk ve LAN transferi bir miktar
   yineleniyor. Bilinçli takas — resmin kaybolmaması önceliği.
   **Çöp toplama:** resmi kaldırma yolları yalnız bulut nesnesini siliyor, yerel
   kopya sahipsiz kalıyordu — ve dünya klasörünün tamamı taşındığı için o çöp
   her cihaza yayılıyordu. `UnusedMediaSweeper` dünya açılışında ve kapanışında
   `media/` + `files/` altında referanssız dosyaları siliyor; çöp kutusundaki
   snapshot'lar da referans sayılıyor ve son 10 dakikada yazılmış dosyalara
   dokunulmuyor (payload'dan önce inen eşleme dosyaları için).
2. Payload'daki bulut ref'lerinin (`dmt-asset://`, `dmt-public://`,
   `dmt-transient://`) **baytları**: `cache/content/{sha}.bin`. Online bir
   dünyada resim yüklendiği anda R2/Storage'a gidiyor ve yerelde yalnız bu
   içerik-adresli önbellekte kalıyor; ref'in kendisi cihazdan bağımsız olduğu
   için yol yeniden yazımı ona dokunmuyor. Baytlar taşınmadığı sürece karşı
   cihaz resmi ancak internete çıkıp indirebiliyordu — LAN eşlemesinin vaadi
   ise tam tersi. Blob içerik-adresli olduğu için yeniden hash'lenmez; dosya
   adındaki sha zaten `LanMediaEntry.sha256`'dır.

Alıcıda `AssetRefResolver` önce `ContentStore`'a bakar (servis katmanına hiç
uğramadan), böylece eşlenen resim giriş yapılmamış / offline durumda da açılır.

Blob'un **dışında** kalan ama dünyaya ait olan iki şey `LanItemPayload.extras`
ile taşınır — blob cloud-backup kontratı olduğu için genişletilmedi:
- `installed_packages` — dünya ↔ paket bağlantıları. Taşınmazsa karşı cihaz
  dünyayı paketlerinden kopuk görür (built-in SRD sentezi boş kalır);
  paketlerin kendisi zaten ayrı item.
- `ui_view` — "o an ne açıktı": açık kartlar (sol/sağ panel + aktif sekme),
  panel filtreleri/sıralaması, açık PDF sekmeleri, sağ sidebar (PDF / Soundpad
  / karakterler), ana ve session sekmesi. Bkz. `exportWorldUiView`
  (`ui_state_provider.dart`). Cihaza özgü olanlar (genişlikler, splitter
  oranları, tema, dil, ses) **taşınmaz**.

`extras` da `rewriteRoots`'tan geçer — açık PDF yolları alıcının veri köküne
çevrilir.

> [!warning] Blob round-trip'i simetrik olmalı
> `_loadFromDb` `map_data`'yı `world_map_data`, `sessions`'ı `world_sessions`
> satırlarından okur ve bunları `settings_json`'a **tercih eder**; ama
> `_saveToDb` uzun süre yalnız `settings_json`'a yazıyordu. Sonuç: hedef
> cihazda o satırlar zaten varsa (yani haritası/oturumu bir kez kullanılmış
> her gerçek dünyada) gelen harita ve oturumlar sessizce görünmez kalıyordu —
> hem LAN eşlemesinde hem **cloud restore**'da. [[world_repository_impl]]
> `save()` artık anahtar geldiğinde granular satırları da yazıyor (sessions
> full-replace, `entities` semantiği). Bir alan granular tabloya taşınırsa
> `_saveToDb`'ye yazma yolu eklemek zorunlu.

Eşleme sırasında dünya **açıksa** `activeCampaignProvider.reload()` çağrılır —
aksi hâlde bellekteki bayat kopya bir sonraki otomatik kayıtta senkronize
edilen içeriğin üzerine yazıyordu.

### Görünümün zaman damgası
İçerik hiç değişmeden yalnız "ne açık" değiştiğinde de eşleme tetiklensin diye
manifest satırında ikinci bir alan var: `LanItemRef.viewUpdatedAt`
(`UiState.viewTouchedByWorld[worldName]`). LWW karşılaştırması
`effectiveUpdatedAt = max(updatedAt, viewUpdatedAt)` üzerinden yapılır; alıcı
world satırının **içerik** zaman damgasını kirletmez (aksi hâlde sırf sekme
açmak buluta yeniden yükleme tetiklerdi).

### Yeniden adlandırma zaman damgası
`LanItemRef.renamedAt` — world, package ve character item'larında taşınır.
`renameWorld()` / `renamePackage()` çağrıldığında ilgili tablonun
`renamed_at` kolonu `DateTime.now()` ile damgalanır; klasör de yeniden
adlandırılır. Karakterlerde `renamed_at`, `CharacterRepository.save()`
tarafından mevcut değer korunarak taşınır; isim değişikliğinde
`_applyCharacter()` tarafından LWW ile güncellenir. Alıcı tarafta peer'ın
`renamedAt`'i local'den daha yeniyse DB + dosya sistemi yeniden adlandırılır;
içerik birleştirilmeden önce isim eşitlenir.

Görünüm dünya başına saklandığı için (`UiState.worldViewByWorld`) eşleme
sırasında başka bir dünyada oturan kullanıcının ekranı yerinden oynamaz —
kayıt, dünya bir sonraki açılışında `MainScreen.initState`'te restore edilir.
Açık dünya eşlenirse global alanlara da uygulanır.

## Birleştirme — bölüm bazlı LWW
Alıcı gelen payload'ı **tam değiştirme** ile yazıyordu; A'da savaş notu,
B'de mindmap düzenlendiyse yalnız LWW kazananı hayatta kalıyor, diğerinin işi
tamamen siliniyordu. Artık dünya iki tarafta da varsa
`mergeWorldPayloads` (`lan_sync/world_merge.dart`, saf fonksiyon) her bölümü
kendi damgasıyla ayrı yarıştırıyor:

| bölüm | damga kaynağı |
|---|---|
| `entities` | `world_entities.updated_at` (id bazında birleşim) |
| `sessions` | `world_sessions.updated_at` (id bazında birleşim) |
| `map_data` | `world_map_data.updated_at` |
| settings üst anahtarları (`combat_state`, `mind_maps`, `map_view`, …) | blob içindeki `_section_updated_at` haritası |
| `world_schema`, `template_*` | item seviyesi `updatedAt` (bölüm damgası yok) |

Damgalar `LanItemPayload.extras.section_stamps` ile taşınıyor; alanı olmayan
(eski sürüm) eşten gelen item'da harita boş kalır ve karşılaştırma item
seviyesindeki `updatedAt`'e — yani eski davranışa — düşer. Eşitlikte **yerel**
kazanır, böylece iki cihaz arasında ping-pong olmuyor.

`_section_updated_at` `world_settings.settings_json`'ın içinde duruyor:
şema migration'ı gerektirmiyor ve payload ile kendiliğinden taşınıyor.
Damgayı `saveSettingsPatch` basıyor — `touchWorld: false` olan motion-class
yazımlar (viewport) damgalamıyor.

Birleştirme deterministik ve idempotent. Bu yüzden `_syncWith` iki tarafta da
bulunan dünyalar için **önce çekip sonra gönderiyor**: `diffManifests` item'ı
tek bir yöne koyuyor, tek yön kalırsa kaybeden tarafın bölümleri karşıya hiç
ulaşmazdı. Gönderim öncesi manifest tazeleniyor, yoksa birleşim sonrası
değişen damga yerine eskisi gitiyordu.

### Bekleyen yazımlar önce boşaltılır
`buildManifest` / `loadItem` / `applyItem` girişinde
`PendingWriteBuffer.flush()` var. `combat_state` 500 ms, `mind_maps` 1000 ms,
viewport 2000 ms gecikmeyle yazılıyor; eşleme o pencerede başlarsa hem payload
hem `worlds.updatedAt` bayat okunuyor ve karşı cihaz "ben daha yeniyim" deyip
**taze veriyi eziyordu**. Uygulama tarafında da gerekli — yoksa bekleyen yerel
yazım apply'dan sonra fire edip geleni geri yazar.

## Presence (arka planda, "arama" değil)
- Eşleşmesi olan her cihaz 5 sn'de bir UDP broadcast: `{dmt:2, id, p, uh}`.
  `uh` = `sha256("dmt-lan-uid:"+uid)[0:8]` — ham `uid` tele çıkmaz.
- Dinleyen taraf `device_id` eşleşirse `last_address` + `last_seen_at` tazeler.
- 15 sn içinde duyulan = **● online**, değilse ○ + "son görülme".
- UDP engelliyse panel açılışında saklı adrese `GET /ping` — ikinci, ucuz yol.

## Kalıcılık — `lan_paired_devices`
Yan tablo, `_sideTablesDDL` içinde `beforeOpen`'da idempotent kurulur:
**schemaVersion bump yok, codegen yok**. Kolonlar: `device_id` (PK), `name`,
`last_address`, `shared_secret`, `paired_at`, `last_seen_at`.

DB zaten `AppPaths.dataRoot/users/{uid}/db/dmt.sqlite` altında olduğu için
eşleşmeler **hesap başına izole**; `uid` karşılaştırması bunun üstüne net bir
hata mesajı ekler.

Cihaz kimliği (`deviceId`) hesaptan bağımsızdır — `shared_preferences`'ta durur,
böylece kullanıcı çıkış yapıp girse de karşı taraf aynı cihazı görür.

## Sunucu yaşam döngüsü
Sabit port **45456** (doluysa ephemeral'a düşer; doğru adres presence ile yayılır).

Dinler ⇔ *giriş yapılmış* **ve** (*en az bir eşleşmiş cihaz var* **veya** *panel
açık*). Eşleşmesi olmayan kullanıcıda hiç soket açılmaz.
`startup_sync_gate` başlatır (fire-and-forget, startup ceiling'ini bekletmez).

## Güvenlik modeli
- Kalıcı uçlar: cihazın `shared_secret`'ı ile `HMAC-SHA256(method|path|ts|nonce|sha256(body))`.
- `/pair`: yalnız panel açıkken, QR token'ı **veya** PIN'den türeyen geçici anahtarla.
- Reddedilir: private olmayan kaynak IP, saat sapması > 60 sn, tekrar nonce,
  bozuk imza, `uid` uyuşmazlığı.
- `/pair`'e IP başına 3 deneme → 30 sn blok + QR/PIN yakılır. **Kurulmuş
  eşleşmeler etkilenmez** — üçüncü bir cihaz süren eşlemeyi düşüremesin.
- Protokolde query string yok; parametreler gövdede, imza ayrışamaz.
- `LanSyncSession.resolveMedia` veri kökü dışına çıkan yolu reddeder; yüklenen
  medya sha256 doğrulanmadan diske yazılmaz.
- **Şifreleme yok, kimlik doğrulama var.** v1'deki 6 haneli PIN yerine artık
  256-bit kalıcı sır kullanıldığı için eşik yükseldi. Üst yol: TLS ya da AES
  gövde şifrelemesi (`crypto` paketi AES içermiyor).

## Key Constants / Invariants
- Presence portu 45455 · duyuru 5 sn · online penceresi 15 sn · HTTP portu 45456.
- `pairToken` TTL 3 dk · PIN 6 hane · saat sapması 60 sn · blok 30 sn · 3 deneme.
- Manifest kimliği `(type, id)` — **id**, ad değil. Ad çakışması `Ad (2)` ile ayrışır.
- `worlds.updatedAt` Drift'te **unix saniye** — LWW çözünürlüğü 1 sn. İki cihaz
  aynı saniye içinde düzenlenmişse eşitlik sayılır ve hiçbir şey taşınmaz.
  Görünüm damgası (`viewUpdatedAt`) ms hassasiyetinde.
- Built-in SRD paketi manifest dışında (her cihazda koddan üretiliyor).
- Medya yolları kullanıcı köküne (`dirname(worldsDir)`) relatif, POSIX ayırıcılı.

## Bilinçli sınırlar (ponytail)
- **Silme yayılmaz** — yalnız ekleme/güncelleme. Tombstone gerekirse manifest'e
  ölü satır + `trash_items`'a `deleted_at`.
- **Yeniden adlandırma taşınır** — `worlds.renamed_at`, `packages.renamed_at`,
  `world_characters.renamed_at` zaman damgaları LWW ile çözülür. Peer'ın
  `renamedAt`'i local'den daha yeniyse alıcı hem DB'yi hem dosya sistemini
  (world/package klasörü) yeniden adlandırır. Karakterlerde isim
  `payloadJson.entity.name` içinde taşınır; `renamed_at` LWW çatışmasında
  hangi ismin kazanacağını belirler. Eşitlikte yerel kazanır.
- **Silme birleştirmede de yayılmaz** — bölüm bazlı birleşim tombstone'suz
  olduğu için A'da silinmiş bir entity'yi B hâlâ tutuyorsa geri gelir. Eski
  tam-değiştirme davranışında kazanan tarafın silmesi yayılıyordu; veri
  kaybetmemeyi hayalet satıra tercih ediyoruz.
- Bölüm damgaları granüler tablolardan geldiği için birleştirme sonrası
  `_restoreSectionStamps` ile geri yazılır — bulk `save()` satırları silip
  yeniden eklediğinden hepsi `now()` olur ve "hangi cihaz düzenledi" bilgisi
  kaybolurdu.
- Medya yüklemesi base64 (%33 şişme) — tek kod yolu bırakıyor.
- **Soundpad içeriği taşınmaz** — `AppPaths.soundpadRoot` kullanıcı veri
  kökünün dışında (bundle'lanmış `assets/soundpad/` olabilir) ve GB'larca ses
  dosyası demek; paketler zaten soundpack kataloğundan indiriliyor. Çalan
  tema/ambience hiç kalıcı değil (`SoundpadNotifier` yalnız bellekte), o yüzden
  eşlenecek bir "soundpad durumu" da yok.
- Masaüstünde QR **okuma** yok (`mobile_scanner` Android/iOS/macOS); masaüstü
  QR'ı gösterir, telefon okur. IP+PIN her yerde çalışır.

## Related
- MoCs: [[Sync-and-Realtime]], [[Data-Layer]], [[Media-and-Assets]]
- Sistem: [[Share-Broadcast-Flow]] (bulut kardeşi)
- Test: `flutter_app/test/application/services/lan_sync/` — protokol birim
  testleri + gerçek soket üzerinden eşleşme/sync loopback testi.
