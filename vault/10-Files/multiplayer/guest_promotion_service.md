---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/guest_promotion_service.dart
layer: application
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `guest_promotion_service.dart`

> [!abstract] Primary Purpose
> Audit fazı **O3**: misafir ağacını (`dataRoot/db/dmt.sqlite` + `worlds/` `packages/` `characters/`) hesabın altına (`dataRoot/users/{id}/`) devreden servis. O1 misafir modunu erişilebilir yaptığı için kayıt olmadan önce gerçek iş birikiyor; devir bugüne kadar **medyayı** kopyalayıp **veritabanını** bırakıyordu — v12 fresh-cut'tan sonra tüm yapısal içeriğin yaşadığı tek yeri. **O4** ise devirden *sonrasının* politikasını yazıyor: misafir ağacı **tam olarak bir** hesabın talep edebileceği bir müsvedde alanıdır ve talep onu **tüketir**.

## Inputs / Outputs
**Inputs**
- Constructor: `dataRoot` (yani `AppPaths.dataRoot` — global kök *misafir kökünün ta kendisi*).
- `finalizePromotion` açık bir `AppDatabase` alır (hesabın DB'si).

**Outputs**
- `copyIntoAccount(userId)` → `GuestPromotionReport { outcome, databaseCopied, databaseMergePending, mediaSubtreesCopied }`.
- `finalizePromotion(userId, db)` → `GuestFinalizeReport { pathsRewritten, rowsMerged, absorbedAnything }`; tamamlanma işaretçisi **yalnız** bir şey soğurulduysa yazılır.
- **O5:** `mergeGuestRows(db)` → hesabın açık DB'sine `ATTACH` edilip `INSERT OR IGNORE` ile aktarılan satır sayısı.
- `rewriteGuestPaths(db, userId)`, `isPromoted(userId)`, `hasGuestData()`, `accountRoot(userId)`.
- **O4:** `canPromote(userId)` (tek yüklem — terfi edilmemiş + ağaç talep edilmemiş + içinde bir şey var), `readClaim()` → `GuestClaim?`, `retireClaimedGuestTree()` → `GuestRetirementReport`.
- **O4 yazdığı dosyalar:** misafir kökünde `.guest_claimed` (kim, ne zaman, ne aldı), `guest_archive/<ts>/` (taşınan DB + medya), ve hesabın `db/` dizininde `.v12_cut_applied` — sonuncusu olmadan terfi eden DB ilk gerçek açılışta yok ediliyordu.
- Yazdığı dosyalar: `users/{id}/.promotion_in_progress` (niyet), `users/{id}/.promoted_from_guest` (tamamlandı).

## Dependencies & Links
- Depends on: `dart:io`, `path`, `drift` (yalnız `customUpdate`/`customSelect` için), [[drift_database]].
- Used by: `user_session_provider` (`UserSessionNotifier.activate` — tek çağıran).
- Kardeş kararlar: [[route_access]] (rota, O1), [[account_gate]] (yüzey, O2), [[guest_mode_provider]] (seçim, O1).
- Devamı: [[beta_enter_gate]] / `BetaEnterMergeService` — buluta itiş **bu servis değil**, mevcut local-wins ilk-giriş merge'i.
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §6 Stage O · O3

## Key Logic / Variables
- **Üç kural, önem sırasıyla:** (1) misafir ağacı burada **salt-okunur** — move/delete/rename yok, yalnız kopya; (2) DB **kapalıyken** kopyalanır (WAL modu, `app_database.dart:152`) ve `-wal`/`-shm` çifti de gider; (3) önce kopya, **en sonda sentinel** — `.incoming` geçici adları rename edildiği için hedefte yarım `dmt.sqlite` hiç oluşmaz.
- İki faz olmasının sebebi tesadüfi değil: yol yeniden yazımı SQL ister, `sqlite3` burada **dev-only** bağımlılık, dolayısıyla rewrite ancak hesabın DB'si Drift ile açıldıktan sonra çalışabilir. Bu yüzden `activate` sırası: kapat → kopyala → `AppPaths.setUser` + `activeUserIdProvider` → aç → rewrite → sentinel.
- **`asset_refs` yeniden yazılmaz ve bu bir eksik değil.** Fazın kendi premisi "asset_refs satırları ve medya yolları `dataRoot`-relative" diyordu; ölçüm tersini gösterdi — `uri` değerleri şema URI'si (`dmt-asset://`, `dmt-public://`, `dmt-transient://`) ve ham dosya yolları o grafa **kasıtlı** olarak sokulmuyor (`reference_indexer.dart:19`). Konumdan bağımsızlar. Mutlak yol taşıyan şey JSON blob'ları ve `world_entities.image_path` gibi kolonlar (F11 `RawPathMigrator`'ın varlık sebebi) — o yüzden süpürme **her tablonun her TEXT kolonu** üzerinde (25 Drift tablosunda 154 `TextColumn` + 4 raw-DDL yan tablo).
- **Rewrite kök değil, alt-ağaç bazlı.** Hesap kökü misafir kökünü *önek olarak içerdiği* için root → account-root ikinci geçişte `users/{id}/users/{id}/…` üretirdi. `{root}/worlds` → `{root}/users/{id}/worlds` biçiminde çapalandığı için idempotent: ikinci geçiş **0** değer yazar (testte iddia ediliyor).
- Her yol üç yazımıyla aranır: platformun kendi ayracı, POSIX ayracı ve `jsonEncode`'dan geçmiş Windows yolunun **çiftlenmiş** ters bölüleri.
- **Hesabın kendi DB'si asla ezilmez** (`mergedIntoAccountDatabase`) — ama artık **satır bazında devralınır**. Bkz. aşağıdaki O5 bölümü: eski davranış (dosya kopyasını reddet, başka bir şey yapma) misafirin işini sessizce yere bırakıyordu.
- Yarıda kalan terfi: `.promotion_in_progress` var + `.promoted_from_guest` yok ⇒ hedefteki DB *bizim* yarım kopyamızdır, yabancı hesabın verisi değil; sonraki deneme baştan kopyalar ve bitirir.
- `cache/` bilerek kopyalanmaz — yeniden üretilebilir ve devrin en büyük, en değersiz parçası olurdu.

### O4 — devirden sonra ağaç ne olur
- **Bir kez talep.** Terfiyi *bitiren* hesap misafir köküne `.guest_claimed` yazar; başka hiçbir hesap o ağaçtan terfi edemez (`guestAlreadyClaimed`). Bozuk/okunamaz bir talep dosyası da **talep sayılır** — "burada bir şey ters gitmiş"in güvenli okuması *bu ağacı kimseye verme*dir.
- **Tüketilir, silinmez.** Talebin hemen ardından `retireClaimedGuestTree()` soğurulan DB'yi (+`-wal`/`-shm`) ve medyayı `guest_archive/<ts>/` altına **taşır**, 30 gün tutar — v12 kesiminin `dmt.sqlite.legacy.<ts>` idiyomunun aynısı. O3'ün "taşıma yok" kuralının gevşediği tek yer burası ve sebebi şu: kural **tek kopyayı** koruyordu, tamamlanma işaretçisi ise aynı baytların artık **iki** yerde olduğunun kanıtı.
- **Çıkış temiz alana iner.** Arda kalan misafir kökü boş olduğu için `AppPaths.setUser(null)` yeni ve **boş** bir DB açar; paylaşılan cihaz bir sonrakine önceki hesabın dünyalarını göstermez ve ikinci hesap *yapısal olarak* — sadece kontrol sayesinde değil — bir şey soğuramaz.
- **Yalnız alınan şey talep edilir.** Hiçbir şey soğurmayan bir terfi ağacı talep etmez; ağaç talep edilmemiş kalır ve bir sonraki hesap onu alabilir. (O5'ten sonra satır merge'i de "soğurma" sayılır, dolayısıyla mevcut DB'si olan bir hesap da ağacı harcar.)
- **Emeklilik idempotent** ve `UserSessionNotifier.deactivate` her çıkışta/çevrimdışı girişte çağırır: talep ile taşıma arasında ölen bir terfi orada iyileşir. Sıra önemli — **önce talep** (tek küçük yazma, ikinci hesabı durduran şey), **sonra taşıma** (yavaş ve daha kırılgan yarı).
- **O4'ün bulduğu asıl hata:** `_openConnectionForUser` yanında `.v12_cut_applied` olmayan her `dmt.sqlite`'ı pre-v12 sayar ve `dmt.sqlite.legacy.<ts>`'e taşır — terfi eden DB tam da o durumda geliyordu. Ölçüm: `db: true` diyen bir terfiden sonra `AppDatabase.forUser('u1')` **0 dünya** döndürdü. Yani **O3 hiç çalışmamıştı**; O3'ün testleri `forTesting` kullandığı için bu fonksiyonu hiç görmedi. Bkz. [[drift_database]].

### O8 — karakterler geldi ama görünmedi (2026-08-15)

Dünyalar ve paketler artık aktarılıyordu; geriye kalan şikâyet tek cümlelikti: "karakter hala gelmiyor."

**Kök neden — satırlar oradaydı, ekran onları başkasının sanıyordu.** Hesapsız oluşturulan karakterin `owner_id`'si `NULL`. Hub'ın karakter sekmesi ise **yalnızca kendine ait** olanları gösteriyor:

```dart
bool _isOwned(Character c, String? selfUid) {
  if (c.ownerId == null) return selfUid == null;   // characters_tab.dart:84
  return c.ownerId == selfUid;
}
```

Yani `NULL` sahip, "kimse giriş yapmamışken benim" demek — giriş yapıldığı anda "başkasının". Devredilen her karakter hesabın veritabanındaydı ve hiçbir ekranında değildi.

**Neden mevcut kurtarma yetmiyor.** `CharacterListNotifier._backfillWorldlessOwnership` tam bu iş için var ama **dünyaya bağlı** satırları bilerek atlıyor: orada `NULL` sahip, `release_character` RPC'sinin bıraktığı "serbest bırakıldı" anlamına geliyor ve her yenilemede sahiplenmek serbest bırakılan karakterleri diriltiyordu. Kullanıcının karakterleri de dünyaya bağlıydı.

**Çözüm — `claimGuestCharacters`, devrin içinde.** Devir, bu belirsizliğin var olmadığı tek yer: bu satırlar hiç hesabı olmamış bir çalışma alanından geliyor, dolayısıyla hiçbiri kimse tarafından serbest bırakılmış olamaz — sahipsizler çünkü sahiplenecek kimse yoktu. Sekmenin dayandığı kuralı gevşetmek yerine sahiplenmeyi buraya koymak, `release` akışını olduğu gibi bırakıyor.

- **Tam dosya kopyası yolunda** (`pending.database`): hesabın veritabanı zaten misafir dosyasının kendisi, `NULL` sahipli her satır misafir doğumlu.
- **Merge yolunda**: yalnızca `guest.world_characters` içinde id'si bulunan satırlar sahipleniliyor — hesabın kendi serbest bıraktığı karakterler `NULL` kalıyor.

`GuestFinalizeReport.charactersClaimed` kaç satırın sahiplenildiğini raporluyor.

Testler: **`characters that arrive without an owner`** grubu (3 vaka) — kopya yolu, merge yolu ve hesabın serbest bıraktığı karakterin korunması. Düzeltme geri alındığında ilk vaka düşüyor — doğrulandı.

### O7 — devredilen dünyanın paketleri boş geliyordu (2026-08-15)

O6 devri tekrar çalışır hale getirdi; hemen ardından: "oldu mesela dünya aktarırken builtin packages içeriği gelmedi."

**Kök neden — iki farklı kimlik rejimi.** `SrdCorePackageBootstrap.ensureInstalled` yerleşik SRD paketini her veritabanına **rastgele** `uuid.v4()` ile kuruyor. İçindeki satırların kimliği ise `srdStableEntityId(slug, name)` — `uuid.v5`, yani her veritabanında **aynı**. Üstelik `package_entities` birincil anahtarı yalnızca `id`; `package_id` anahtara dahil değil.

Düz satır kopyası bu yüzden mümkün olan en kötü şeyi yapıyordu:

| tablo | misafir satırı | sonuç |
|---|---|---|
| `packages` | id **A**, hesapta yok | eklendi — hesapta aynı isimde iki paket |
| `package_entities` | id'ler hesapta **B** altında zaten var | `INSERT OR IGNORE` **hepsini eledi** |
| `installed_packages` | dünya → **A** | dünya, içi boş bir pakete bağlı kaldı |

**Çözüm — `_guestPackageRemap`.** Merge, iki tarafta aynı ismi **ve en az bir ortak entity id'sini** taşıyan paketleri eşliyor; hesabın kopyası bütünüyle kazanıyor (`packages`, `package_schemas`, `package_entities` satırları atlanıyor), buna karşılık `package_id` taşıyan diğer tüm tablolar (`installed_packages`, `world_packages`, `world_entities`) `CASE` ile hesabın kimliğine çevriliyor.

Eşleme ölçütü bilerek **bozulmanın kendisi**: ortak entity id'si, misafir satırlarının yutulmasına yol açan şeyin ta kendisi. Sadece ismi aynı olan iki farklı kullanıcı paketi rastgele id üretir, hiçbir id paylaşmaz — dolayısıyla dokunulmaz ve ikisi de hayatta kalır.

Testler: `guest_promotion_service_test.dart` içinde **`packages that exist on both sides`** grubu (3 vaka). Düzeltme geri alındığında ilk vaka düşüyor — doğrulandı.

### O6 — misafir alanı birden fazla kez yaşar (2026-08-15)

O5 devri çalışır hale getirdi ve hemen ardından ikinci şikayet geldi: "hesap açmadan girdiğimde oluşturduğum her şey, bir hesap ile girdiğimde o hesaba aktarılmalı, şu an hiçbir şey olmuyor." Ölçüm, cihazın kendi dosyalarından: `.guest_claimed` **12:17:20Z** damgalı, yanında duran misafir veritabanı ise **12:33Z**'de sıfırdan yeniden oluşmuş ve içinde yeni dünya var.

**Kök neden:** O4'ün talebi (`claim`) misafir **köküne** yazılıyordu ve hiçbir şey onu silmiyordu. Böylece "bu içerik harcandı" kuralı sessizce "bu cihaz ömründe bir kez devredebilir" kuralına dönüştü; `canPromote` bir daha asla `true` dönmedi.

**Çözüm — nesil (generation):**

- `.guest_generation` misafir kökünde durur, o anki çalışma alanını tanımlar ve ilk soruluşta üretilir (`currentGeneration()`).
- Hem `.guest_claimed` hem hesabın `.promoted_from_guest` işaretçisi hangi nesil altında yazıldığını kaydeder.
- `retireClaimedGuestTree` arşivlediği içerikle birlikte talebi **ve** nesil dosyasını siler; sonraki misafir oturumu yeni bir nesil basar — altında ne talep ne işaretçi vardır, devir yeniden açılır.
- O4'ün asıl garantisi yerinde: bir nesil içinde ağaç hâlâ tek bir hesap tarafından alınabilir ve ikinci hesap birincinin işini göremez — çünkü o iş artık orada değil, arşivde.
- O6 öncesi yazılmış (nesilsiz) bir talep, adını verdiği içerik hâlâ yerinde **ve talepten eski** olduğu sürece geçerlidir (`_legacyClaimCovers`): varlık tek başına arşivlenmiş dosyayla onun yerine gelen yeni dosyayı ayırt edemez, zaman damgası eder. Kullanıcının cihazı bu kuralla kendiliğinden düzelir.
- `isPromoted` artık nesle bağlı; ancak eski nesilden kalan işaretçi yalnızca yerine **gerçekten yeni bir çalışma alanı** geçtiğinde düşürülür — boş bir kökte "bu hesap burada devir yaşadı" cevabı hâlâ evettir.
- [[confirm_sign_out_dialog]] uyarısı artık talebe değil hesabın kendi işaretçisine bakıyor (talep, çıkış anında çoğu zaman silinmiş oluyor).

Testler: `guest_promotion_service_test.dart` içinde **`a second life`** grubu (5 vaka) ve `guest_account_switch_test.dart`'ın O4 politika vakaları yeni politikaya göre yeniden yazıldı. Toplam **34 test**, hepsi geçiyor.

### O5 — devir neden hiç çalışmıyordu (2026-08-15)
- **Ölçüm, kullanıcının kendi veri kökünde.** `users/1a6055ee…/.promoted_from_guest` yazılmış (`pathsRewritten: 0`), `.guest_claimed` **yok**, misafir `db/dmt.sqlite` 39.6 MB ve içinde 1 dünya (`dasd`) + 1 karakter; hesabın DB'sinde **0 dünya**. Yani terfi "tamamlandı" diye işaretlenmiş ama hiçbir şey almamıştı.
- **Kök neden:** `accountAlreadyHasData` istisna değil **kural**. Bir hesapla bir kez giriş yapmak `users/{id}/db/dmt.sqlite`'ı yaratır ve SRD core bootstrap'ı onu doldurur (ölçülen: 38 MB, 0 dünya). Dolayısıyla dosya-kopyası *her dönen kullanıcıda* reddediliyor, medya da subtree dolu diye atlanıyordu — devrin tamamı düşüyordu.
- **İkinci hata, birincisini kalıcı yapan:** `finalizePromotion` sonucu ne olursa olsun `.promoted_from_guest` yazıyordu. Hesap "terfi edilmiş" damgasını yiyor, `canPromote` bir daha asla `true` dönmüyordu.
- **Çözüm (üç parça):**
  1. `copyIntoAccount` hesabın DB'si varken artık `mergedIntoAccountDatabase` döner ve borcu `.promotion_in_progress` içine `merge: true` olarak yazar; faz 2'de `mergeGuestRows` hesabın **açık** DB'sine misafir dosyasını `ATTACH` edip her tabloyu `INSERT OR IGNORE INTO main.<t> SELECT … FROM guest.<t>` ile aktarır. Çakışmada **hesabın satırı kazanır**. Tablo listesi `guest.sqlite_master`'dan okunur (yeni tablo kendiliğinden biner), kolonlar iki taraf arasında kesiştirilir; `sync_outbox` / `sync_telemetry` / `migration_progress` cihaz-yerel defter olduğu için hariç. Merge, path rewrite'tan **önce** çalışır ki gelen satırlar da aynı geçişte düzeltilsin.
  2. Medya artık **dosya bazında** kopyalanır (var olanı asla ezmeden), subtree bazında hep-ya-hiç atlanmaz — aynı sebeple hesabın dolu `worlds/`'ü misafirin haritalarını yere bırakıyordu.
  3. `.promoted_from_guest` yalnız bir şey soğurulduysa yazılır ve içine `absorbed: {database, rowsMerged, media}` konur; `isPromoted` **`absorbed` anahtarı olmayan** bir işaretçiyi "aslında terfi olmamış" sayar. Bu, hâlihazırda bozuk damgayı yemiş cihazın bir sonraki girişte kendiliğinden onarılması demek.
- **Buluta itiş:** `activate` artık soğurma olduğunda `BetaEnterGate.clear(userId)` çağırır — aksi halde bu cihazda daha önce giriş yapmış bir hesabın sentinel'i set olduğu için `BetaEnterMergeService` yeni gelen satırları hiç itmezdi.
- **O5'in ikinci yarısı — terfiden *sonra* açılan misafir alanı.** O4'ün emekliliği `db/dmt.sqlite`'ı arşive taşıdığı için "burada veritabanı yok" artık **rutin** bir durum; `_openConnectionForUser`'daki iki kontrol bunu "temiz kurulum" diye okuyup eski bir DB'yi dirilttti: (a) pre-Apr-2026 support-dizini içe aktarımının tek koruması `!newFile.existsSync()`'ti, (b) v12 kesimi de `.v12_cut_applied` zaten dizinde olduğu için gelen dosyaya dokunmadı. Ölçüm: çıkış sonrası misafir alanı **şema v5** bir dosyayla açıldı (`map_pins.campaign_id`, `world_id` yok) → `onUpgrade` → `createAll()` eski tabloları bıraktı → ilk index deyimi `no such column: world_id` fırlattı ve hub dünya listesi yerine SqliteException gösterdi. İki kural eklendi: içe aktarım **tek seferlik** (kesim işaretçisi varsa veya legacy dizinde `.moved_to_dataroot` makbuzu varsa atlanır) ve kesim artık işaretçiye değil **dosyanın kendi `user_version`'ına** da bakıyor — SQLite başlığının 60. baytından okunuyor, `sqlite3` handle'ı gerektirmiyor (bu katmanda dev-only bağımlılık). Test: `test/data/database/pre_v12_file_guard_test.dart`; mutasyonla doğrulandı, koruma kapatıldığında test tam da kullanıcının gördüğü hatayla düşüyor. Bkz. [[drift_database]].
- **Gerçek veriyle doğrulandı:** kullanıcının iki DB'si geçici bir köke kopyalanıp akış tekrar koşuldu → `mergedIntoAccountDatabase`, **25 satır** merge, hesapta `dasd` dünyası ve 1 karakter.

## Notes
- Yerini aldığı `_migrateGlobalDataIfNeeded` yalnız `worlds/` ve `packages/` kopyalıyordu; **`characters/` listede hiç yoktu** — dokümanın adlandırmadığı üçüncü boşluk. Üçü de artık gidiyor.
- Eski `migrated_{uid}` SharedPreferences sentinel'ı kaldırıldı; sentinel artık hesap kökünün altında bir dosya. İşaretçisi olmayan mevcut kullanıcı bir sonraki girişinde tam da o **ezmeme** dalına (`accountAlreadyHasData`) düşer.
- Buluta itiş burada **yok**: satırlar `users/{id}/` altına indikten sonra sıradan yerel satırlardır ve `BetaEnterMergeService` (`beta_enter_merge_service.dart:141` — `ownerId == null` ise sahipliği yerelde üstlenir, sonra `syncEngine.enqueue*`) onları outbox'a yazar. Sıra ölçüldü: `landing_screen` `activate(uid)`'i `/hub`'a gitmeden **önce** await ediyor, merge ise sonra `startup_sync_gate`'ten koşuyor.
- Test: `test/application/services/guest_promotion_service_test.dart` — **14 vaka**, gerçek dosya-tabanlı v12 DB üstünde (`openTestDatabaseAt`). O5 üçünü ekledi: mevcut DB'ye merge, aynı PK'de hesabın satırının kazanması, ve `absorbed` alanı olmayan eski işaretçinin yeniden denenmesi.
- Oturum kapatma tarafı **O4'te kapandı**: `deactivate()` artık yolları çevirmeden önce `retireClaimedGuestTree()` çağırıyor, dolayısıyla çıkan kullanıcı kendi hesabının bayat bir kopyasına değil boş bir çalışma alanına iniyor.
- O3'ün "misafir DB'si terfiden sonra da yerinde durur" garantisi O4'te **yerini değiştirdi**, zayıflamadı: artık `guest_archive/<ts>/db/dmt.sqlite`'ta, bayt bayt aynı. O3 testinin üç vakası oraya yönlendirildi.
- Kullanıcıya görünen taraf: `signOutLocalDataNote` (en → tr/de/fr) çıkış onay dialog'unda **yalnızca** cihazın misafir alanı gerçekten harcanmışsa görünür.
- Test: `test/application/services/guest_account_switch_test.dart` — **14 vaka**, hepsi gerçek açılış yolundan; son ikisi `UserSessionNotifier`'ı bir `ProviderContainer` üzerinden baştan sona sürüyor (gir → çık → başkası olarak gir).
