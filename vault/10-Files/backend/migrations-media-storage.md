---
type: file-note
domain: backend
path: supabase/migrations/053_free_media_bucket.sql, 054_transient_share.sql, 055_online_count_limits.sql, 060_asset_access_shared_world.sql, 065_transient_shared_pool.sql, 089_media_pool_budgets.sql, 092_media_on_demand.sql, 099_world_media.sql, 100_package_media.sql
layer: backend
language: sql
status: stable
updated: 2026-10-01
tags: [file]
---

# `Migrations — Media Storage (3-Tier Model)`

> [!abstract] Primary Purpose
> **099 (Faz 5d) ile transient katman kalktı**, yerini dünya başına kalıcı `world_media` aldı; **100 (Faz 5e)** aynı tabloya paket kapsamını ekledi — güncel model aşağıdaki "099" ve "100" bölümlerinde ve [[Media-Storage-Tiers]]'ta; bu özet 053–065'in tarihçesi.
>
> Defines the three-tier media storage model and its server-side enforcement. **Free tier** (portraits, world/package covers) lives in a public Supabase Storage bucket and never counts toward quota. **Counted tier** lives in R2 with quota enforcement. **Transient tier** (storage-full / projection shares) lives under R2 `transient/` with no quota but a per-user 100 MB cap + global 10 GB LRU pool. Also adds per-user/per-world count limits and widens counted-asset read access to shared-world members.

## Inputs / Outputs
**Inputs**
- Run in Supabase SQL Editor. References `worlds`/`world_members` (026), `community_assets` (002), `auth.users`.

**Outputs**
- Bucket `free-media` (public, 2 MB/file). Tables: `free_media_assets`, `transient_shares`, `transient_evict_queue`.
- RPCs (see [[rpc-reference]]): `get_transient_access`, `get_asset_access` (re-defined), `transient_reserve`, `transient_touch`, `transient_evict_pop`, `transient_per_user_cap_bytes`, `transient_pool_cap_bytes`, plus count-limit constants + `enforce_world_character_limits`.

## Dependencies & Links
- Depends on: [[migrations-auth-social]], [[migrations-online-worlds]]
- Used by: [[worker]], [[worker_rls]], [[free_media_service]], [[entity_image_upload]], [[entity_media_cleanup_service]], [[rpc-reference]], `beta_purge_with_cleanup` edge fn (kaldırıldı)
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Media-and-Assets]]

## Key Logic / Variables — per migration
- **053_free_media_bucket** — Bucket `free-media` (public, 2 MB/file), path `{uploader_id}/{sha256}.{ext}`, avatars-style RLS (public read, owner write; NO beta gate). Metadata table `free_media_assets` (UUID PK, `owner_id`, `storage_path UNIQUE`, `sha256_hash`, `mime_type`, `size_bytes`, `kind` = `MediaKind.wireName`, `scope_id`). **CRITICAL INVARIANT: `free_media_assets` is never summed into any quota function** (`get_user_total_storage_used`, `get_beta_quota_used`) — the free-media rule depends entirely on this.
- **054_transient_share** — `transient_shares` (UUID PK, `world_id`, `uploader_id`, `sha256`, `ext` default `.png`, `session_id`). RLS: members read, DM+uploader write. RPC `get_transient_access(p_user_id,p_uploader_id)→bool` — uploader always allowed, else the two users share a world (`world_members JOIN world_members`); `service_role`-only. `REPLICA IDENTITY FULL` + realtime so un-share DELETE carries row data. Transient objects/rows are deliberately quota-exempt.
- **055_online_count_limits** — IMMUTABLE constant fns: `max_online_characters_per_user()=10`, `max_online_worlds_per_user()=10`, `max_characters_per_world()=10`, `max_online_packages_per_user()=10`. Trigger `enforce_world_character_limits` (BEFORE INSERT/UPDATE) enforces both axes, recounting only when the relevant axis actually changes (`IS DISTINCT FROM`, excludes self via `id<>NEW.id`); over-limit raises `check_violation` (SQLSTATE 23514). Per-user world/package limits enforced inside `publish_world` / `publish_personal_package` (INSERT branch only).
- **060_asset_access_shared_world** — Re-defines `get_asset_access` so counted assets follow the same rule as transient: uploader OR shared-world member. Fixes 403 broken images on shared/projected entity cards.
- **065_transient_shared_pool** — Adds `bytes`, `mime_type`, `last_used_at` to `transient_shares` (+ LRU/uploader/sha indexes). New `transient_evict_queue` (service_role-only). Caps: `transient_per_user_cap_bytes()=100 MB`, `transient_pool_cap_bytes()=10 GB`. `transient_reserve(_bytes,_world)` (pre-upload): rejects oversize / `transient_per_user_full` (>100 MB user total), then LRU-evicts oldest `last_used_at` rows into `transient_evict_queue` until `global+new ≤ 10 GB`, returning `{ok, per_user_used, global_used, evicted}`. `transient_touch(_sha)` bumps `last_used_at` on download. `transient_evict_pop(_limit)` uses `FOR UPDATE SKIP LOCKED` so the Worker's `/transient/evict-sweep` can drain the queue without two workers colliding.

## Notes
- The Worker (`worker.ts`) is the binary gatekeeper for counted + transient; the free tier bypasses the Worker entirely and uploads straight to Supabase Storage.
- LRU eviction emits a CDC DELETE that drops the projected image on player screens (intentional).

## 089 — havuzun iki sınıfa bölünmesi
- **transient**: per-user cap **kaldırıldı** (`transient_per_user_cap_bytes()` düşürüldü); yerine dosya başına 100 MB emniyet kapağı `transient_max_file_bytes()`. Havuz 10 GB → **5 GB** (`transient_pool_cap_bytes()`), LRU aynen sürüyor.
- **pinned**: `pub_assets(sha256 PK, ext, bytes, mime_type)` + `pub_asset_refs(sha256, owner_id, ref_key)`. Key şeması `pub/{sha}.{ext}` — içerik-adresli, iki kişi aynı görseli yayınlasa tek kopya. Cap'ler `pinned_pool_cap_bytes()` (5 GB) ve `pinned_per_user_cap_bytes()` (500 MB/yayıncı).
- **Refcount sayaç değil SAYIMdır**: `pub_asset_refs` satırları. Düşüş `pub_asset_release(ref_key, sha?)` ile ama silme kararı `trg_drop_orphan_pub_asset` (AFTER DELETE) trigger'ında — çünkü `owner_id` `auth.users`'a CASCADE'li ve hesap silme RPC'ye hiç uğramaz. Son ref gidince obje `transient_evict_queue`'ya tam `r2_key` ile yazılır, Worker sweep'i siler.
- `get_pub_upload_allowed` (service_role) Worker PUT kapısı; `get_r2_pool_stats()` (admin) havuz doluluğu.

## 088 — paylaşım gövdesi sınırları
`entity_shares.payload_json` ≤ **512 KB** (`chk_entity_shares_payload_size`, NOT VALID — yeni yazmalarda tam zorlanır, mevcut tabloyu taramaz) ve dünya başına ≤ **4000** satır (`max_shares_per_world()` + `trg_enforce_world_share_limits` BEFORE INSERT; UPDATE saymaz ki rutin payload güncellemesi tam 4000'de patlamasın). `max_share_payload_bytes()` client pre-check'i için var — CHECK ifadesi fonksiyon çağıramaz, iki sabit birlikte değiştirilir. Doğrulama: `supabase/scripts/verify_088_089.sql`.

## 099 — dünya medyası bulutta, transient kalktı (Faz 5d)
- **`world_media`** `(world_id → worlds ON DELETE CASCADE, sha256, ext, bytes, kind, mime, uploaded, created_at)`, PK `(world_id, sha256)`, `idx_world_media_sha`. `ext` CHECK `^(\.[a-z0-9]{1,10})?$` (R2 key'inin parçası). RLS: üyeler okur, sahip siler; yazma yalnız RPC'den. Satır rezervasyonla `uploaded = false` doğar, onaysız satır imzalanmaz ama kotaya sayılır.
- Sabitler: `media_total_cap_bytes()` **9 GB** (`pub/` + `worlds/` birlikte; 089'un iki havuz tavanının yerine), `world_media_user_cap_bytes()` **1 GB** (kullanıcının bütün dünyaları), `world_media_max_bytes(kind)`: `battle_map` 10 · `world_entity_image` 5 · `world_audio` 10 · `world_pdf` 20 MB, bilinmeyen tür NULL.
- RPC'ler: `world_media_reserve(_world, _items)` (tek global `pg_advisory_xact_lock('media_reserve')` — `pub_asset_reserve` de aynısını alıyor; limiti aşan `too_large`'da, tavan aşımı partinin tamamını reddeder), `world_media_confirm`, `get_media_quota`, worker için `world_media_sign_put` / `world_media_sign_get` (service_role). Ortak sayaç `_media_usage(uid)` (istemciye kapalı).
- **Kuyruk yeniden adlandırıldı:** `transient_evict_queue` → `r2_evict_queue` (index + sequence dahil), `uploader_id` düştü, `r2_key NOT NULL`. `trg_world_media_evict` (AFTER DELETE) her satırın key'ini yazar — tek tek silme, multiplayer kapatma, dünya ve hesap silme aynı yoldan. `r2_evict_pop` (id, r2_key) sınıfa göre canlılık bakar: `pub/` → `pub_assets`, `worlds/` → `world_media`.
- **Söküm:** `transient_shares` (önce kalan objeleri kuyruğa atıp realtime yayınından çıkararak), `get_transient_access`, `transient_reserve/touch`, `transient_*_cap_bytes`, `pinned_pool_cap_bytes`, `report_missing_shas`, `max_missing_shas`, `world_members.missing_shas`. `drop_orphan_pub_asset`, `get_r2_pool_stats` (yeni biçim: `cap_bytes`, `pinned`, `world_media`) ve `get_asset_access` (yalnız yorum) yeniden tanımlandı.
- Doğrulama: `supabase/scripts/verify_099.sql` (`099 OK`); `verify_088_089.sql` ve `verify_publish_media.sql` yeni kuyruk adına güncellendi.

## 100 — paket medyası da bulutta (Faz 5e)
- **Tek tablo, kardeş değil:** `world_media.package_id` (→ `user_packages` ON DELETE CASCADE), `world_id` nullable, `world_media_one_scope` CHECK (`num_nonnulls(world_id, package_id) = 1`). PK `(world_id, sha256)` düştü; yerine kapsam başına UNIQUE (`world_media_world_sha_key`, `world_media_package_sha_key` — NULL'lar çakışmaz). Ad tarihsel kaldı. Gerekçe: kişi başı 1 GB bütün kapsamların toplamı, 5g karakteri de buraya ekleyecek; kardeş tablo kotayı, tahliyeyi ve imzayı çoğaltırdı.
- `media_r2_key(world, package, sha, ext)` key yerleşiminin tek tanımı (`worlds/{id}/…` | `packages/{id}/…`): trigger, imza RPC'leri ve dolaylı olarak worker. `_media_scope_owner(scope, id, uid)` sahiplik + id kalıbı (`^[A-Za-z0-9_-]{1,100}$`), hep true/false (NULL `IF NOT` kapısından geçerdi).
- RLS: dünya satırı üyeler okur / sahip siler (değişmedi); paket satırını yalnız paketin sahibi okur ve siler (`world_media: scope read` / `world_media: scope owner delete`).
- `_media_usage` paket medyasını da kullanıcıya sayar (`LEFT JOIN worlds` + `user_packages`). `enqueue_world_media_evict` key'i `media_r2_key`'den alır; `r2_evict_pop`'a `packages/` canlılık dalı. Yerele alma = `user_packages` satırının silinmesi → CASCADE → kuyruk → cron.
- RPC'ler kapsamlı: `media_reserve` / `media_confirm` (`_scope`, `_id`), `media_sign_put` / `media_sign_get` (tam `r2_key` döner). 099'un dört dünya RPC'si düştü — deploy sırası: 100, hemen worker, sonra uygulama.
- Doğrulama: `verify_100.sql` (`100 OK`) — şema, tek kapsam CHECK'i, paket rezervasyonu/onayı, kapsam karışmaması, key'i bozan id, imza, RLS, iki kapsamın tek kota sayısı, CASCADE → kuyruk, yeniden canlanan obje. `verify_099.sql` 100'ün adlarına geçti. 001→100 temiz Postgres 16'da hatasız; 100 iki kez koşunca da.
