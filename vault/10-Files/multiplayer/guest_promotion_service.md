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
- `copyIntoAccount(userId)` → `GuestPromotionReport { outcome, databaseCopied, mediaSubtreesCopied }`.
- `finalizePromotion(userId, db)` → yeniden yazılan değer sayısı; ardından tamamlanma işaretçisi.
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
- **Hesabın kendi DB'si asla ezilmez** (`accountAlreadyHasData`): cihazda zaten veritabanı olan bir hesaba giriş, misafirin kayıt olmasından *farklı* bir merge'dir. Satırları yerinde kalır, misafir ağacı okunabilir durur, uzlaştırma bulut merge'inin işi.
- Yarıda kalan terfi: `.promotion_in_progress` var + `.promoted_from_guest` yok ⇒ hedefteki DB *bizim* yarım kopyamızdır, yabancı hesabın verisi değil; sonraki deneme baştan kopyalar ve bitirir.
- `cache/` bilerek kopyalanmaz — yeniden üretilebilir ve devrin en büyük, en değersiz parçası olurdu.

### O4 — devirden sonra ağaç ne olur
- **Bir kez talep.** Terfiyi *bitiren* hesap misafir köküne `.guest_claimed` yazar; başka hiçbir hesap o ağaçtan terfi edemez (`guestAlreadyClaimed`). Bozuk/okunamaz bir talep dosyası da **talep sayılır** — "burada bir şey ters gitmiş"in güvenli okuması *bu ağacı kimseye verme*dir.
- **Tüketilir, silinmez.** Talebin hemen ardından `retireClaimedGuestTree()` soğurulan DB'yi (+`-wal`/`-shm`) ve medyayı `guest_archive/<ts>/` altına **taşır**, 30 gün tutar — v12 kesiminin `dmt.sqlite.legacy.<ts>` idiyomunun aynısı. O3'ün "taşıma yok" kuralının gevşediği tek yer burası ve sebebi şu: kural **tek kopyayı** koruyordu, tamamlanma işaretçisi ise aynı baytların artık **iki** yerde olduğunun kanıtı.
- **Çıkış temiz alana iner.** Arda kalan misafir kökü boş olduğu için `AppPaths.setUser(null)` yeni ve **boş** bir DB açar; paylaşılan cihaz bir sonrakine önceki hesabın dünyalarını göstermez ve ikinci hesap *yapısal olarak* — sadece kontrol sayesinde değil — bir şey soğuramaz.
- **Yalnız alınan şey talep edilir.** `accountAlreadyHasData` ile biten bir terfi DB almamıştır; ağaç talep edilmemiş kalır ve bir sonraki hesap onu alabilir.
- **Emeklilik idempotent** ve `UserSessionNotifier.deactivate` her çıkışta/çevrimdışı girişte çağırır: talep ile taşıma arasında ölen bir terfi orada iyileşir. Sıra önemli — **önce talep** (tek küçük yazma, ikinci hesabı durduran şey), **sonra taşıma** (yavaş ve daha kırılgan yarı).
- **O4'ün bulduğu asıl hata:** `_openConnectionForUser` yanında `.v12_cut_applied` olmayan her `dmt.sqlite`'ı pre-v12 sayar ve `dmt.sqlite.legacy.<ts>`'e taşır — terfi eden DB tam da o durumda geliyordu. Ölçüm: `db: true` diyen bir terfiden sonra `AppDatabase.forUser('u1')` **0 dünya** döndürdü. Yani **O3 hiç çalışmamıştı**; O3'ün testleri `forTesting` kullandığı için bu fonksiyonu hiç görmedi. Bkz. [[drift_database]].

## Notes
- Yerini aldığı `_migrateGlobalDataIfNeeded` yalnız `worlds/` ve `packages/` kopyalıyordu; **`characters/` listede hiç yoktu** — dokümanın adlandırmadığı üçüncü boşluk. Üçü de artık gidiyor.
- Eski `migrated_{uid}` SharedPreferences sentinel'ı kaldırıldı; sentinel artık hesap kökünün altında bir dosya. İşaretçisi olmayan mevcut kullanıcı bir sonraki girişinde tam da o **ezmeme** dalına (`accountAlreadyHasData`) düşer.
- Buluta itiş burada **yok**: satırlar `users/{id}/` altına indikten sonra sıradan yerel satırlardır ve `BetaEnterMergeService` (`beta_enter_merge_service.dart:141` — `ownerId == null` ise sahipliği yerelde üstlenir, sonra `syncEngine.enqueue*`) onları outbox'a yazar. Sıra ölçüldü: `landing_screen` `activate(uid)`'i `/hub`'a gitmeden **önce** await ediyor, merge ise sonra `startup_sync_gate`'ten koşuyor.
- Test: `test/application/services/guest_promotion_service_test.dart` — **11 vaka**, gerçek dosya-tabanlı v12 DB üstünde (`openTestDatabaseAt`).
- Oturum kapatma tarafı **O4'te kapandı**: `deactivate()` artık yolları çevirmeden önce `retireClaimedGuestTree()` çağırıyor, dolayısıyla çıkan kullanıcı kendi hesabının bayat bir kopyasına değil boş bir çalışma alanına iniyor.
- O3'ün "misafir DB'si terfiden sonra da yerinde durur" garantisi O4'te **yerini değiştirdi**, zayıflamadı: artık `guest_archive/<ts>/db/dmt.sqlite`'ta, bayt bayt aynı. O3 testinin üç vakası oraya yönlendirildi.
- Kullanıcıya görünen taraf: `signOutLocalDataNote` (en → tr/de/fr) çıkış onay dialog'unda **yalnızca** cihazın misafir alanı gerçekten harcanmışsa görünür.
- Test: `test/application/services/guest_account_switch_test.dart` — **14 vaka**, hepsi gerçek açılış yolundan; son ikisi `UserSessionNotifier`'ı bir `ProviderContainer` üzerinden baştan sona sürüyor (gir → çık → başkası olarak gir).
