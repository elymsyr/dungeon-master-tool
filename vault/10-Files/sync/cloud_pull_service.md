---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_pull_service.dart
layer: application
language: dart
status: active
updated: 2026-09-23
tags: [file]
---

# `cloud_pull_service.dart`

> [!abstract] Primary Purpose
> Push'un tersi: bulut ayna tablolarındaki satırları yerele geri okur. Kapı tek bir RPC — `get_world_delta(world, since, limit)` — ve damga `worlds.cloud_revision`. 26 tabloya CDC aboneliği **yok** (§2.3): sunucu revizyon penceresini tek pakette döner, istemci `complete` false olduğu sürece yeni damgayla tekrar çağırır.
>
> Tablo eşlemesini kendi tutmuyor: [[cloud_mirror_tables]]'daki bildirimi ters yönde okuyor.
>
> Faz 5c'den beri iki kapsam: dünya (`get_world_delta`, damga `worlds.cloud_revision`) ve paket (`get_package_delta`, damga `packages.cloud_revision`); sayfa döngüsü (`_pullFrom`) ve `apply` ortak. Ayrıca ikinci cihazın ilk senkronu: bulutta olup bu cihazda olmayan dünyayı/paketi listeleyip indiriyor.

> [!warning] Sıra: önce push, sonra pull
> Pull satırı bulutun `updated_at`'i ile yazar. Push damgası tur başında `now()`'a çekildiği için, o damgadan **önce** düzenlenmiş her uzak satır bir sonraki push taramasına düşmez. Ters sırada her pull kendi getirdiği satırları buluta geri göndertir. Saat kayması yüzünden yine de düşen olursa zararsız: migration **096**'nın echo guard'ı aynı içeriğin revizyonu artırmasını engelliyor, karşı cihaz uyanmaz. `CloudPushPump.catchUp` bu sırayı uyguluyor (Faz 5b'den beri kanalın her `SUBSCRIBED`'ında ve her revizyon sinyalinde).

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase db`, `SupabaseClient client`, `ContentRefIndex? index`.
- Supabase RPC `get_world_delta` (migration 096) / `get_package_delta` (098) → `{revision, head, complete, tables, tombstones}`; select `worlds` + gömülü `world_revisions(revision)`, `user_packages` (bulutta olup burada olmayanın listesi).
- Reads (Drift): hedef satırların `updated_at`'i (LWW karşılaştırması), `worlds` (bayrak + damga).

**Outputs**
- Writes (Drift): 12 ayna tablosu + `combatants` / `combat_conditions`; tombstone'ların işaret ettiği satırların silinmesi; `worlds.cloud_revision`.
- Public API: `pullWorld(worldId, {full})` / `pullPackage(packageId, {full})` → `CloudPullResult` (`revision` = ulaşılan bulut revizyonu); `apply(scopeId, CloudDelta, {package})` → `CloudPullApplied` (**ağsız** ara adım, testin girdiği kapı); `listCloudOnlyWorlds()` / `listCloudOnlyPackages()`; `downloadWorld(CloudWorld, {onProgress})` / `downloadPackage(CloudPackage, {onProgress})`.
- Veri tipleri: `CloudWorld` / `CloudPackage` (record), `CloudPackageNameTaken`.
- Veri sözleşmesi: `CloudDelta` / `CloudTombstone`.

## Dependencies & Links
- Depends on: [[cloud_mirror_tables]], [[drift_database]], [[content_ref_index]] (`fileForSha`), `isOfflineError`.
- Used by: [[cloud_push_provider]] (`cloudPullServiceProvider`, `CloudPushPump.pull` / `catchUp`).
- Karşı yön: [[cloud_push_service]].
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.3, §2.4, §2.8, §4.8 (Faz 5a); [[migrations-cloud-mirror]].

## Key Logic / Variables
- **Sayfalama:** sunucu tablo başına `_page` (500) satır döner ve bir tablo dolduysa turun kesme noktasını o tablonun son satırına çeker — dönen paket hep tutarlı bir revizyon aralığı. `pullWorld` `complete` gelene kadar döner, `_maxRounds` (200) güvenlik freni.
- **Sayfa + damga tek transaction:** yarıda kalan uygulama `cloud_revision`'ı ilerletmez, aynı sayfa yeniden gelir. Medya çözümü (dosya sistemi) transaction'ın **dışında** yapılıyor; yazma kilidi disk I/O'su kadar açık kalmasın.
- **Çatışma — son düzenleyen kazanır (§2.8):** yerel `updated_at` gelenden büyük **ya da eşitse** satır atılır. Eşitlik de atlanıyor: aynı zamanlı iki yazma zaten ayırt edilemez, gereksiz yazma yapılmıyor.
- **`INSERT ... ON CONFLICT DO UPDATE`, `INSERT OR REPLACE` değil.** İkincisi satırın tamamını değiştirir ve aynalanmayan yerel kolonları (`world_characters.is_online` gibi) varsayılana düşürürdü.
- **Silmeler upsert'lerden önce:** aynı id silinip yeniden yaratıldıysa tazesi kalsın. Tombstone'un `deleted_at`'i yerel düzenlemeden eskiyse satır **silinmez** — bir sonraki push onu buluta geri koyar.
- **Pull silmesi yerel tombstone BIRAKMAZ.** Silme DAO'lardan değil ham `DELETE`'ten geçiyor; `sync_tombstones`'a kayıt düşseydi push aynı silmeyi buluta geri göndermeye çalışırdı.
- **Cascade elle:** `foreign_keys = OFF` (bilinçli, bkz. [[drift_database]]) olduğundan encounter silmesi combatant'larını, combatant silmesi koşullarını **kodda** düşürüyor; yoksa hayalet savaşçı kalır.
- **Combatant:** bulutta durum etkileri satır değil `conditions_json` kolonu. Yerel PK autoincrement olduğu için eşleme yok — savaşçının koşulları silinip yeniden yazılıyor. Gelen `world_id` düşer (yerelde encounter üzerinden biliniyor).
- **Ters dönüşümler:** ISO → unix saniye, `boolean` → 0/1, `jsonb` → TEXT, `rename` tersine. Bulut-yalnızı kolonlar (`revision`, `dm_only_keys`, kapsam dışı `owner_id`) yerele **sızmaz**.
- **Medya:** `dmt-content://{sha}` → `ContentRefIndex.fileForSha` ile bu cihazdaki yol. Bayt burada yoksa ref **olduğu gibi kalır**; [[asset_ref_resolver]] onu zaten çözüyor, `MissingMediaReporter` sha'yı indirme kuyruğuna yazıyor (Faz 3.5).

## Notes
- Test: `test/application/services/cloud_pull_apply_test.dart` (14 test) — `apply` üzerinden, ağsız. Sonuncusu **round-trip**: pull edilen satır push'a verildiğinde bayt bayt aynı gövdeyi üretiyor; echo guard'ın çalışması buna bağlı.
- **İndirme — kabuk en son (Faz 5c).** Yarım inmiş dünya/paket hiçbir listede görünmemeli: açılabilseydi varsayılan ayarlarını "şimdi" damgasıyla kaydeder, LWW'yi kazanır ve buluttaki gerçek ayarları ezerdi. Dünyada `worlds` satırı bütün sayfalardan sonra yazılıyor (`apply`'ın damga UPDATE'i satır yokken no-op); pakette paketin satırı `get_package_delta`'nın son sayfasında geliyor ve `apply` paket tablolarını ters sırada (çocuklar önce, `packages` en son) yazıyor. Push damgası indirmenin **başına** çekiliyor: inen satırlar ondan eski, ilk açılışta buluta geri gitmez. Yarıda kalan indirme ham SQL ile siliniyor — DAO silmesi `sync_tombstones` bırakır, sonraki push buluttaki gerçek satırları silerdi. RLS dünyayı gizlerse RPC boş ama "tamam" dönüyor; revizyon 0 ise indirme hata sayılıyor (boş kabuk doğmasın). Paket adı yerelde UNIQUE: aynı adlı yerel paket varsa indirme ağa hiç çıkmadan `CloudPackageNameTaken` döner.
- **Liste:** `listCloudOnlyWorlds` sahibi bu kullanıcı olan ve sayacı > 0 olan dünyaları (Faz 4'ten önce yalnız multiplayer için yayınlanmış, aynası boş dünyaları eliyor); PostgREST bire-bir gömmeyi bazen nesne bazen tek elemanlı liste döndürüyor, `_revisionOf` ikisini de okuyor.
- Bilinçli sınırlar (§4.8, §4.8.2): paketin canlı sinyali yok (uzlaştırma anı açılış), oyuncu tarafı yok (Faz 5.5), görseller DM'in öbür cihazı açıkken gelir (§2.7).
- Test: `cloud_pull_apply_test.dart` (14, ağsız `apply`), `cloud_download_test.dart` (9, sahte PostgREST — `test/support/fake_postgrest.dart`). Realtime sinyali Faz 5b'de geldi — pull'un kendisi değişmedi, yalnız tetiği ([[cloud_push_provider]]).
- LWW'nin eşitlik kuralı (`yerel >= gelen → at`) ile 097'nin bulut kuralı (`NEW < OLD → atla`, eşitlik geçer) aynı saniyede farklı içerikte ayrışabilir — bilinçli sınır, `online-sync-redesign.md` §4.8.1.
- **İnen satırların görünür olması [[cloud_push_provider]]'a bağlı.** Bu servis yalnız Drift'e yazıyor; açık dünyanın UI'ı `ActiveCampaignNotifier`'ın bellekteki blob'undan okuyor. `CloudPushPump.pull` tur satır uyguladıysa `ActiveCampaignNotifier.reload()` çağırıyor — blob depodan tazeleniyor ve `campaignRevisionProvider` bump'lanıyor. Bump tek başına yetmez: aynı bayat blob'u yeniden okutur.
- Migration **096 2026-09-22'de deploy edildi**, yani `get_world_delta` yerinde. (Deploy edilmeseydi `pullWorld` sessizce hata döner ve damga ilerlemezdi.) Uçtan uca elle doğrulama bekliyor: `docs/online-sync-redesign.md` §4.8 "Bekleyen doğrulama".
