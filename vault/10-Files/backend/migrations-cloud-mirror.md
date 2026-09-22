---
type: file-note
domain: backend
path: supabase/migrations/094_cloud_mirror_schema.sql, supabase/migrations/095_chars_client_timestamp.sql, supabase/migrations/096_world_delta.sql, supabase/scripts/verify_094.sql, supabase/scripts/verify_096.sql
layer: backend
language: sql
status: active
updated: 2026-09-22
tags: [file]
---

# `Migrations — Cloud Mirror Schema & RLS (094–096)`

> [!abstract] Primary Purpose
> `online-again` Faz 3. 077'nin kaldırdığı tam bulut aynasını **satır bazlı** olarak geri getirir ve altyapısını kurar: revizyon sayacı (Realtime'daki tek tablo), tombstone'lar, oyuncunun kişisel durumu, online paket tabloları, 17 tabloluk RLS yüzeyi ve oyuncunun kart okumak için **tek kapısı** olan `get_shared_entities()` + SQL redaksiyonu. Tamamen eklemeli: `entity_shares.payload_json` ve mevcut Realtime abonelikleri dokunulmadan duruyor. İstemci bu şemayı henüz kullanmıyor.

## Inputs / Outputs
**Inputs**
- Supabase SQL Editor'da sırayla çalıştırılır. 026 (`worlds`, `world_members`, `world_characters`, `entity_shares`, `is_world_member`, `is_world_dm`) ve 078/088 (`entity_shares.payload_json` + limitler) üstüne biner.

**Outputs**
- **Altyapı (3):** `world_revisions`, `world_tombstones`, `world_member_state`
- **077'den geri gelen (6):** `world_entities`, `world_settings`, `world_map_data`, `world_sessions`, `world_mind_map_nodes`, `world_mind_map_edges`
- **Yeni (5):** `world_encounters`, `world_combatants`, `world_map_pins`, `world_timeline_pins`, `world_installed_packages`
- **Online paketler (3):** `user_packages`, `user_package_entities`, `user_package_schemas`
- **RPC:** `get_world_delta(world, since, limit)` (096 — DM'in okuma kapısı), `get_shared_entities(world, since_revision)`, `get_shared_entity_ids(world)`, `next_world_revision`, `next_package_revision`, `max_rows_per_world`, `max_entity_row_bytes`, `max_online_packages_per_user`, `max_cloud_bytes_per_user`
- **Görünüm:** `v_shared_entities` — istemciye kapalı
- **Realtime:** `world_revisions` publication'a **eklenir**; hiçbir tablo çıkarılmaz

## Dependencies & Links
- Depends on: [[migrations-online-worlds]], [[migrations-security]]
- Used by: [[cloud_push_service]] (Faz 4a dünya tabloları, Faz 4b `user_package*` + `world_characters`), [[cloud_pull_service]] (Faz 5a, `get_world_delta`).
- Domain map: [[Backend-Infra]]
- System flow: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.2–§2.6, §4.4, §4.8

## Key Logic / Variables
- **CDC değil, artımlı çekme.** Realtime'a giren tek tablo `world_revisions` (dünya başına bir satır: `revision`, `updated_at`, `updated_by`). Dünyadaki her satır yazması `next_world_revision()` ile sayacı artırır ve yazılan satırı aynı numarayla damgalar; istemci sinyali alıp `since_revision`'dan sonrasını çeker. 26 tabloya abonelik ~1000 mesaj/saat ederdi, bu ~1.
- **`updated_at` sunucu tarafından EZİLMEZ.** Yeni tabloların hiçbirine `tg_bump_updated_at` bağlı değil — değer istemcinin düzenleme anıdır. Varış zamanına bakılırsa geç gelen çevrimdışı kuyruk her seferinde yeni veriyi ezer (`redesign` §2.8). Mevcut `trg_chars_bump_updated` (026) Faz 4b'de **düştü** — `095_chars_client_timestamp.sql`. Karakterler push turuna katıldığı an borç kapandı; aynı commit'te `WorldMirrorService.pushCharacter` de `updated_at` göndermeye başladı, yoksa satır ilk INSERT'teki saatte donardı.
- **Tombstone.** `tg_world_tombstone(<id kolonu>)` AFTER DELETE; dünya CASCADE'inde erken çıkar (tombstone da CASCADE ile düşerdi). `owner_id` oyuncunun kendi satırından (mind map, member_state) gelir ve RLS'te oyuncunun göreceği tek tombstone odur — DM'in sildiği kart id'leri oyuncuya sızmaz. **050'nin tuzağı yok**: eski `tg_bump_parent_world` `worlds` satırının kendisini UPDATE ettiği için dünya silinemiyordu; yeni sayaç ayrı tabloya yazar.
- **Tek okuma kapısı.** Oyuncunun `world_entities` üzerinde policy'si **yoktur** (tabloda tek policy var: `world_entities: dm all`; `verify_094` bunu sayarak doğrular). Oyuncu kartlara yalnız `get_shared_entities()` ile ulaşır: `v_shared_entities` görünümü izinli + `dm_only_keys IS NOT NULL` satırları verir, fonksiyon `dm_notes`'u **hiç seçmez** ve `fields_json::jsonb - dm_only_keys` ile DM'e özel alanları çıkarır.
- **Emniyet kuralı.** `dm_only_keys` NULL = "sır listesi bilinmiyor", "sır yok" **değil** → kart hiç dönmez. Kararı (hangi alan gizli) Dart verir, uygulamayı SQL yapar; PL/pgSQL'e ikinci bir şema yorumlayıcısı yazılmaz.
- **`v_shared_entities` RLS'i atlar** (postgres'e ait görünüm) — bu yüzden `anon` ve `authenticated`'dan `REVOKE` edilmiştir, tek okuyucusu iki SECURITY DEFINER fonksiyon. Görünümün varlık sebebi: görünürlük predikatının iki sorguda tekrarlanmaması.
- **Mind map sahipliği** artık `owner_id` kolonu (NULL = DM), 026'nın `map_id = 'player_<uid>'` konvansiyonu değil. DM oyuncunun düğümlerini **görmez**.
- **`world_combatants.conditions_json`** — yereldeki `combat_conditions` tablosunun karşılığı kolon olarak. Yerel PK `autoIncrement` int, cihazlar arası taşınamazdı.
- **Kota:** `max_rows_per_world()` 20.000 (INSERT trigger), `max_entity_row_bytes()` 256 KB (CHECK), `max_online_packages_per_user()` 20 (INSERT trigger), `max_cloud_bytes_per_user()` 500 MB (**tanımlı, zorlanmıyor** — ölçüm Faz 7). 088'in dersi geçerli: CHECK fonksiyon çağıramaz, sabit iki yerde durur.
- **096 — echo guard (Faz 5a).** 094'ün `trg_*_stamp_rev` trigger'ı `BEFORE INSERT OR UPDATE`, şartsızdı: aynı gövdenin yeniden yazılması bile sayacı artırıyordu. Pull gelince bu kapanmayan bir döngü: A pull eder → satırı yerele yazar → push geri gönderir → revizyon artar → B uyanır → … Trigger ikiye bölündü, UPDATE dalına `WHEN (OLD.* IS DISTINCT FROM NEW.*)` kondu. Upsert yalnız gönderilen kolonları yazdığı için içerik aynıysa `NEW = OLD` ve sayaç kıpırdamaz. **Aynı hata paketlerde para yakıyordu:** `user_packages` satırı push'ta `sinceAll` (her tur gider), yani hiçbir şey değişmese bile her tur `revision`'ı bir artırıyordu.
- **096 — `get_world_delta(world, since, limit)`.** SECURITY **INVOKER**: RLS çağıranın rolüyle işliyor, dolayısıyla DM kendi dünyasını görür ve oyuncu bu kapıdan hiçbir DM kartı alamaz (onun kapısı `get_shared_entities`). Tablo başına `limit` satır; bir tablo dolduysa turun kesme noktası o tablonun son satırına çekilir ve **tüm** tablolar o noktadan kırpılır — dönen paket hep tutarlı bir revizyon aralığı, `complete` false ise istemci yeni damgayla tekrar çağırır. İlerleme garantili: kesme noktası her zaman `since`'ten büyük. Tombstone'lar aynı pencereden, `owner_id IS NULL OR owner_id = auth.uid()` ile.
- **`fields_json` gerçekten JSON nesnesi olmalı** (`jsonb_typeof(...) = 'object'` CHECK). Güvenlik sınırı: bozuk tek satır redaksiyon sorgusunu patlatır ve o dünyadaki **her** oyuncunun okuması durur.

## Notes
- `verify_094.sql` rol taklidi için `set_config('role', 'authenticated', true)` + `request.jwt.claims` kullanır — tablo sahibi `postgres` RLS'i bypass ettiği için testler mutlaka `authenticated` rolünde koşar. `ROLLBACK` ile biter, iz bırakmaz.
- Doğrulama iki ortamda yapıldı: temiz Postgres 16'da (docker + minimal Supabase iskeleti, migration arka arkaya iki kez uygulanarak) ve **2026-09-22'de gerçek Supabase projesinde** — 094 hatasız uygulandı, `verify_094.sql` `094 OK` döndü.
- `verify_096.sql` aynı kalıpta: echo guard (aynı gövde sayacı artırmamalı, gerçek değişiklik artırmalı), delta penceresi, tombstone, sayfalama kırpması ve "oyuncu bu kapıdan DM kartı göremez" RLS testi.
- **095 ve 096 2026-09-22'de deploy edildi** (094 ile aynı gün). `verify_096.sql` henüz koşturulmadı; uçtan uca elle doğrulama adımları `docs/online-sync-redesign.md` §4.7 ve §4.8 "Bekleyen doğrulama".
- Sonraki adımlar: paket pull'u + Realtime sinyali (Faz 5b), `entity_shares.payload_json`'ın düşmesi ve Realtime budaması (Faz 5.5). Tamamlananlar: `dmt-content://` (3.5), Drift v13 + dünya push'u (4a), paket + karakter push'u (4b, migration 095), dünya pull'u (5a, migration 096).
