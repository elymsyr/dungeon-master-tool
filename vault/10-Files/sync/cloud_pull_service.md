---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_pull_service.dart
layer: application
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `cloud_pull_service.dart`

> [!abstract] Primary Purpose
> Push'un tersi: bulut ayna tablolarındaki satırları yerele geri okur. Kapı tek bir RPC — `get_world_delta(world, since, limit)` — ve damga `worlds.cloud_revision`. 26 tabloya CDC aboneliği **yok** (§2.3): sunucu revizyon penceresini tek pakette döner, istemci `complete` false olduğu sürece yeni damgayla tekrar çağırır.
>
> Tablo eşlemesini kendi tutmuyor: [[cloud_mirror_tables]]'daki bildirimi ters yönde okuyor.

> [!warning] Sıra: önce push, sonra pull
> Pull satırı bulutun `updated_at`'i ile yazar. Push damgası tur başında `now()`'a çekildiği için, o damgadan **önce** düzenlenmiş her uzak satır bir sonraki push taramasına düşmez. Ters sırada her pull kendi getirdiği satırları buluta geri göndertir. Saat kayması yüzünden yine de düşen olursa zararsız: migration **096**'nın echo guard'ı aynı içeriğin revizyonu artırmasını engelliyor, karşı cihaz uyanmaz. `CloudPushPump.syncOnOpen` bu sırayı uyguluyor.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase db`, `SupabaseClient client`, `ContentRefIndex? index`.
- Supabase RPC `get_world_delta` (migration 096) → `{revision, head, complete, tables, tombstones}`.
- Reads (Drift): hedef satırların `updated_at`'i (LWW karşılaştırması), `worlds` (bayrak + damga).

**Outputs**
- Writes (Drift): 12 ayna tablosu + `combatants` / `combat_conditions`; tombstone'ların işaret ettiği satırların silinmesi; `worlds.cloud_revision`.
- Public API: `pullWorld(worldId, {full})` → `CloudPullResult`; `apply(worldId, CloudDelta)` → `CloudPullApplied` (**ağsız** ara adım, testin girdiği kapı).
- Veri sözleşmesi: `CloudDelta` / `CloudTombstone`.

## Dependencies & Links
- Depends on: [[cloud_mirror_tables]], [[drift_database]], [[content_ref_index]] (`fileForSha`), `isOfflineError`.
- Used by: [[cloud_push_provider]] (`cloudPullServiceProvider`, `CloudPushPump.pull` / `syncOnOpen`).
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
- Bilinçli sınırlar (§4.8): paket pull'u yok (Faz 5b), Realtime sinyali yok — pull dünya açılışında bir kez koşuyor, bellekteki dünyayı tazeleyen bir şey yok (uygulama yeniden açılınca görülür), ilerleme UI'ı yok, oyuncu tarafı yok (Faz 5.5).
- Migration **096 2026-09-22'de deploy edildi**, yani `get_world_delta` yerinde. (Deploy edilmeseydi `pullWorld` sessizce hata döner ve damga ilerlemezdi.) Uçtan uca elle doğrulama bekliyor: `docs/online-sync-redesign.md` §4.8 "Bekleyen doğrulama".
