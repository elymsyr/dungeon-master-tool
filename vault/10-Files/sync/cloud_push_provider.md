---
type: file-note
domain: sync
path: flutter_app/lib/application/providers/cloud_push_provider.dart
layer: application
language: dart
status: active
updated: 2026-09-23
tags: [file]
---

# `cloud_push_provider.dart`

> [!abstract] Primary Purpose
> Bulut aynasının **ne zaman** koşacağına karar veren ince katman. `PendingWriteBuffer.tick`'i dinler, 3 sn sessizlikten sonra açık olanın push turunu başlatır — önce dünya, sonra paket. Ayrıca turun girdilerini toplar: açık içeriğin kimliği ve şemadan türeyen `dm_only_keys` haritası.
>
> Faz 5a'dan beri pull da buradan, Faz 5b'den beri **canlı**: dünya kanalı her `SUBSCRIBED`'da `catchUp`'ı, her `world_revisions` sinyalinde `onSignal`'ı çağırıyor ([[world_mirror_applier]] provider'ı bağlıyor). Push ve pull tek şeritten geçiyor.

## Inputs / Outputs
**Inputs**
- `pendingWriteBufferProvider.tick` (ValueNotifier) — tek tetikleyici.
- `activeCampaignProvider` — "açık içeriğin anahtarı"; pakette paket adı tutar, o durumda dünya turu satır bulamaz ve atlanır.
- `activePackageProvider` — açık paketin **adı**; id tablodan bulunur (`packagesDao.getByName`).
- `currentWorldRoleProvider` — DM değilse tur atlanır (ayna tabloları RLS'te DM-only).
- `worldSchemaProvider` — `dmOnly` / `private_` alan anahtarları.

**Outputs**
- `cloudPushServiceProvider` → [[cloud_push_service]] (Supabase yapılandırılmamışsa / oturum yoksa `null`).
- `cloudPushPumpProvider` → `CloudPushPump`; `push({full, worldId})` ve `pushPackage({full, packageName, packageId})` → `CloudPushResult`; `pull({full, worldId})` → `CloudPullResult`; `catchUp(worldId)`; `onSignal(worldId, revision)`.
- `cloudPullServiceProvider` → [[cloud_pull_service]] (aynı null kapısı).
- `cloudOnlyWorldsProvider` / `cloudOnlyPackagesProvider` (Faz 5c) → bulutta olup bu cihazda olmayanlar; yerel liste (`campaignInfoListProvider` / `packageListProvider`) değişince yeniden sorulur, çevrimdışıyken boş. Tüketicisi hub'daki ortak `CloudOnlySection` widget'ı (`presentation/widgets/cloud_only_section.dart`: satır başına İndir + ilerleme, tek seferde tek indirme).
- `CloudPushPump.syncPackage(name)` (Faz 5c) — paket açılmadan önce push → pull; paketin Realtime sinyali yok, uzlaştırma anı açılış. En çok 8 sn beklenir, sonra paket yerel haliyle açılır.

## Dependencies & Links
- Depends on: [[cloud_push_service]], [[cloud_pull_service]], [[pending_write_buffer]], [[world_media_sync]], [[content_ref_index]], [[campaign_provider]] (`reload()`).
- Used by: `main_screen.dart` ve `package_screen.dart` (açıkken keep-alive `ref.watch`; `MainScreen` ayrıca `worldMediaNoticeProvider`'ı dinleyip "oyunculara gitmeyecek" der), `online_world_widgets.turnMultiplayerOn` (dünya ilk yayınında `push(full: true)` + `syncWorldMedia`; iki giriş — [[save_sync_indicator]] ve hub ayar diyaloğu — ortak), paketin ilk yayınında `full: true`, `world_mirror_provider.dart` (DM kanalının `onSubscribed` → `catchUp`, `onRevision` → `onSignal`; bkz. [[world_sync_service]]).
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §4.6 (Faz 4a), §4.7 (Faz 4b), §4.8 (Faz 5a), §4.8.1 (Faz 5b), §4.8.3 (Faz 5d).

## Key Logic / Variables
- **İki katmanlı debounce:** tampon zaten 750–2000 ms bekliyor; buradaki 3 sn onun üstüne biniyor — kart düzenlerken her tuşta değil, eli çektikten sonra tek tur.
- **Keep-alive kalıbı:** `MainScreen` `ref.watch(cloudPushPumpProvider)` ile pompayı dünya açıkken hayatta tutuyor; aynı kalıp [[world_mirror_applier]] için de kullanılıyor.
- **`CloudSync:` tanı satırları** (debugPrint): rol çözümü ([[world_sync_service]] aboneliği öncesi, `role_provider`'ın yuttuğu ağ hatası dahil), `catchUp`, debounce sonrası sinyal (`rev` / `yerel`), her push (`↑` yazılan, `✕` silinen) ve pull (`+` uygulanan, `-` silinen) — rol kapısında atlanan tur da. Başarılı tur önceden hiç iz bırakmıyordu; iki cihazlı testte zincirin nerede koptuğu `grep CloudSync` ile görünüyor.
- **Rol kapısı yalnız dünyada:** ayna tabloları RLS'te DM-only. Faz 5d'den beri rol **beklenir** (`_roleOf`: açık dünya → `currentWorldRoleProvider.future`, değilse `worldRoleProvider(id).future`) — eskiden `valueOrNull` okunuyordu ve yeni invalidate edilmiş rol önceki `none` değerini döndürdüğü için "multiplayer aç"ın ilk tam push'u sessizce atlanıyordu; hub'dan açılan (aktif olmayan) dünya da hiç DM sayılmıyordu. Paket turunda rol kontrolü **yok** — paket kullanıcı kapsamlı, RLS `owner_id`'ye bakıyor.
- **Medya (Faz 5d):** artımlı turda **satırlardan önce** — `push` servise `beforeRows: _uploadNew` verir, turun satırlarının andığı ve bulutta olmayan medya upsert'ten önce yüklenir; öbür cihaz satırı gördüğünde bayt bulutta. Hata atmaz, yüklenemese de satırlar gider. Tam tur (`full`, "multiplayer aç") bunu atlar: medyası overlay'de ayrıca yükleniyor, yoksa satırlar bütün medyayı beklerdi. Dünyanın tam uzlaştırması kendi şeridinde (`_media`): `_round` dünya uzlaştırılmamışsa (`_mediaSynced`) tam tarama; `catchUp` push → pull → **sonra** tam uzlaştırma + oturumda bir kez yetim temizliği (`_pruned`) — temizlik pull'dan önce koşsaydı öbür cihazın yeni görselini anan satır buraya inmeden görsel silinirdi. `_mediaSynced` yalnız reddedilen dosya kalmadıysa işaretlenir.
- **Yeniden deneme (`_scheduleMediaRetry`):** medya işi hata verirse ya da dosya reddedilirse `_mediaSynced` düşer ve dünya için tek bir zamanlayıcı kurulur — 30 sn, her başarısızlıkta iki katı, en çok 10 dk; ateşlenince dünya hâlâ online ise `catchUp`. Başarıda sayaç sıfırlanır. Kota dolduysa kurulmaz (beklemek yer açmaz). Eskiden yarım kalan yükleme ancak bir sonraki düzenlemede ya da yeniden açılışta sürüyordu. `syncWorldMedia` de başarısızlıkta kurar, hatayı yine çağırana verir. Limit aşan yeni dosya `worldMediaNoticeProvider`'a (oturumda her ad bir kez); tam uzlaştırmanın bulduğu eski dosyalar sessiz.
- **Satır şeridi:** push ve pull `_rows`'dan geçiyor — bir Future zinciri, işler sırayla koşuyor, bir işin hatası şeridi tıkamıyor. Eski `_guarded`/`_pendingRound` kapısı üst üste gelen isteği *atlıyordu* ("skipped"); şerit hiçbirini düşürmüyor. `_round()` dünyayı ve paketi sıra sıra deniyor, açık olmayan kendiliğinden atlanıyor. Şeridin asıl işi yankıyı elemek: sinyal kendi push'umuzdan geldiyse `_onSignal` şeridin boşalmasını bekliyor, o arada push damgayı ilerletmiş oluyor (bkz. [[cloud_push_service]] `ownRunEnd`).
- **Pull'dan sonra açık dünya tazeleniyor.** `pull()` tur satır uyguladıysa (`applied > 0 || removed > 0`) ve çekilen dünya hâlâ açık dünyaysa `ActiveCampaignNotifier.reload()` çağrılıyor. Bu şart olmadan 5a kullanıcıya **tamamen görünmezdi**: `EntityNotifier._loadFromCampaign` Drift'ten değil bellekteki blob'dan okuyor, dolayısıyla inen satırlar ancak bir sonraki açılışta belirirdi. `reload()` blob'u `_repo.load()` ile yerinde değiştirip `campaignRevisionProvider`'ı bump ediyor — yalnız bump etmek yetmez, aynı bayat blob yeniden okunur. `installed_packages` Drift `StreamProvider`'ı üstünden zaten canlı; `worldCharactersProvider` bulut kaynaklı, bu yoldan etkilenmiyor.
- **`catchUp` — flush, push, pull.** Uzlaştırma turu; kanal her `SUBSCRIBED` olduğunda (dünya açılışı, reconnect, uygulamanın öne gelmesi) ve karşı cihazın sinyalinde koşuyor. Önce `PendingWriteBuffer.flush()`: pull artık düzenleme sürerken de koşabiliyor, tampondaki satır Drift'e inmeden LWW onu bayat haliyle karşılaştırırdı (flush'ın `_bumpTick`'i 3 sn sonra boş bir push turu doğuruyor — yalnız yerel sorgu). Push-önce sırasının gerekçesi [[cloud_pull_service]]'te: ters sırada her pull kendi getirdiği satırları buluta geri göndertirdi.
- **`onSignal` — 1 sn debounce.** Karşı cihazın bir push turu satır başına bir sinyal üretiyor (sayaç her yazmada artıyor); pencere patlamayı tek pull'a indiriyor. Sonra sayaç yerel `worlds.cloud_revision` ile karşılaştırılıyor: eşik altındaysa (kendi yankımız ya da zaten çekilmiş) hiçbir şey yapılmıyor.
- **Eski `syncOnOpen` kaldırıldı (5b).** Rol DM'e çözülünce bir kez koşması gerekiyordu, ama pompa autoDispose olmayan bir `Provider` — kök kapsamda yaşıyor, dünya kapanınca dispose olmuyor. `_opened` bayrağı ilk DM dünyasında `true` olup öyle kalıyor ve **uygulama ömrü boyunca ikinci bir açılış pull'u koşmuyordu.** Tetik kanalın `SUBSCRIBED`'ına taşındı; bayrağa gerek kalmadı.
