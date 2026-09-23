---
type: file-note
domain: backend
path: supabase/migrations/*.sql (CREATE FUNCTION catalog)
layer: backend
language: sql
status: stable
updated: 2026-09-23
tags: [file]
---

# `Supabase RPC Reference`

> [!abstract] Primary Purpose
> A catalog of the key `SECURITY DEFINER` RPCs defined across the Supabase migrations, grouped by area, with signature + one-line purpose + the grant role. The app calls these via `supabase.rpc(...)`; the Cloudflare Worker calls a small `service_role`-only subset. Use this instead of grepping `CREATE FUNCTION` across 70+ migration files.

## Inputs / Outputs
**Inputs**
- Invoked over PostgREST `/rest/v1/rpc/<fn>`.

**Outputs**
- See per-RPC return types below.

## Dependencies & Links
- Depends on: [[migrations-auth-social]], [[migrations-online-worlds]], [[migrations-media-storage]], [[migrations-security]]
- Used by: [[worker]], [[worker_rls]], `beta_purge_with_cleanup` edge fn (kaldırıldı), [[supabase_world_membership_service]], [[world_join_service]], [[character_claim_service]], [[free_media_service]], `beta_enter_gate.dart` (kaldırıldı)
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables — RPC catalog

### Media / storage (Worker calls these — `service_role` only unless noted)
- `get_asset_access(p_user_id uuid, p_r2_key text) → bool` — counted R2 asset readable? uploader OR shared-world member (002, widened 060).
- `check_asset_quota(p_user_id uuid, p_new_bytes bigint, p_limit bigint) → bool` — would this upload stay under quota? (002).
- `get_user_total_storage_used(p_user_id uuid) → bigint` — cloud_backups + community_assets (+ posts/shared_items) total; **excludes** free_media + transient (002/003). `authenticated` + `service_role`.
- `get_user_storage_used(p_user_id uuid) → bigint` — cloud_backups only (001).
- ~~`get_transient_access`, `transient_reserve`, `transient_touch`, `transient_evict_pop`, `transient_*_cap_bytes`, `report_missing_shas`~~ — **099'da silindi** (Faz 5d, transient havuz kalktı).
- `world_media_reserve(_world text, _items jsonb) → jsonb` — yüklemeden önce: yalnız dünyanın sahibi; her öğe `{sha, ext, bytes, kind, mime}`; limiti aşan `too_large`'da döner (hata değil), zaten yüklü atlanır, rezerve edilip yüklenmemiş yeniden döner; kişi başı 1 GB (`media_user_full`) ya da toplam 9 GB (`media_pool_full`) aşılırsa hiçbir satır yazılmaz. Dönüş `{upload: [sha], too_large: [sha]}` (099). `authenticated`.
- `world_media_confirm(_world text, _shas text[]) → int` — PUT'u biten sha'lar okunabilir olur (099). `authenticated`, yalnız sahip.
- `get_media_quota() → jsonb` — `{user_used, user_cap, total_used, total_cap}`; "multiplayer aç"ın ön hesabı (099). `authenticated`.
- `world_media_sign_put(p_user uuid, p_world text, p_shas text[])` / `world_media_sign_get(p_user uuid, p_shas text[])` — Worker'ın toplu imza izni, N sha tek sorgu (099). `service_role`.
- `r2_evict_pop(_limit int default 20) → setof (id bigint, r2_key text)` — tahliye kuyruğunu boşaltır, `FOR UPDATE SKIP LOCKED`; obje o arada yeniden canlandıysa (`pub_assets` / `world_media` satırı var) satırı düşürür ama döndürmez (090 → 099). Worker cron'u ve `/admin/evict-sweep` çağırır.
- `media_total_cap_bytes() → 9 GB`, `world_media_user_cap_bytes() → 1 GB`, `world_media_max_bytes(kind) → bigint | null` (IMMUTABLE, 099).

### Worlds / membership / invites
- `is_world_member(world text) → bool`, `is_world_dm(world text) → bool`, `can_access_map(world,map text) → bool` (026). `authenticated`.
- `create_world_invite(world_id text, expires_secs int, uses int default 1) → text` — DM-only, generates 8-char base32 code (026).
- `redeem_world_invite(code text) → table(world_id, world_name)` — player joins as member (026).
- `regenerate_world_invite`, `ensure_world_invite`, `publish_world(...)` (beta-gated, per-user 10-world cap), `share_package_to_world`, `unshare_world_package` (043/044/055).
- `claim_character(p_character_id text)`, `release_character`, `assign_character`, `remove_from_world`, `delete_character` (026/034/036/038).

### Admin / general
- `is_admin() → bool` — `auth.uid()` in `app_admins` (003). The gate for every `admin_*` RPC + the edge function.
- `whoami()` diagnostic (028); `ban_user`/`unban_user`/`get_banned_users`/`am_i_banned`; `set_online_restriction`/`is_online_restricted`; `get_all_users_summary`, `get_system_storage_stats`.
- Admin list/delete: `admin_list_marketplace_listings`, `admin_delete_*`, `admin_list_posts`, `admin_list_audit_log`.
- Internal: `_assert_admin_rate_limit()` (rate guard, client EXECUTE revoked in 074).
- `delete_my_account() → bool` (083, gövde **084**, **085** ve **086**'da düzeltildi, `authenticated`) — self-service hesap silme. Sıra: elle temizlikler → `DELETE FROM auth.users WHERE id = auth.uid()`; public şemadaki her kullanıcı-sahipli tablo FK cascade ile gider. **085:** `marketplace_listings` açıkça silinir (cascade zincirine rağmen ilanlar hesap silindikten sonra listede duruyordu — gözlenmiş vaka, no-op ise zararsız); `auth.uid()` NULL veya `auth.users`'tan 0 satır silinmesi artık `FALSE` değil `RAISE EXCEPTION` (sessiz no-op istemcide "silindi" gibi görünüyordu). **086 — sahiplik semantiği (güvenlik):** 084/085 iki tabloda "kullanıcı gidiyorsa satırı da gitsin" diyordu, ikisinde de satır yalnız kullanıcının değildi. (a) `world_characters`: blanket `DELETE ... WHERE owner_id` **başka bir DM'in dünyasındaki** satırı da siliyordu. Artık [[Grant-Resolution|039]]'un durum makinesi izleniyor — `(owner, NULL)` → DELETE, `(owner, W)` → `(NULL, W)` ("unclaimed in world", `release_character` ve leave/kick trigger'ıyla aynı geçiş). Kullanıcının kendi dünyasındakiler `worlds` cascade'i sırasında 039'un BEFORE-DELETE trigger'ıyla toplanır. (b) `admin_audit_log`: satırlar admin'in **başkalarına** uyguladığı ban/kısıtlama/ilan-silme kaydı; silinmeleri kötüye kullanan bir admin'in izini süpürmesine izin veriyordu. 023'ün `admin_id NOT NULL + ON DELETE SET NULL` çelişkisi kaldırıldı (`admin_id` nullable, korelasyon FK'siz `admin_legacy_id`'de) ve satır siliniyor değil **anonimleşiyor**. `admin_list_audit_log` de dördüncü COALESCE şıkkıyla (`deleted:<uid>`) güncellendi. Storage/R2 objeleri SQL'den silinemez — istemci onları RPC'den **önce** temizler, bkz. [[account_deletion_service]].

### Beta program
- `join_beta() → text` (now creates a request, 066), `request_beta(msg)`, `cancel_beta_request()`.
- `leave_beta() → bool` — delegates to `_purge_beta_user(auth.uid())` (067). Cascade-deletes the user's worlds, orphan world_characters, personal packages/entities, marketplace listings, free_media, community_assets, transient_shares, cloud_backups, beta_requests, beta_participants.
- `_purge_beta_user(p_user uuid) → bool` / `_leave_beta_for(p_user uuid) → bool` — service_role-only shared purge bodies (067/064).
- `admin_revoke_beta(p_user uuid)`, `admin_approve_beta_request`, `admin_reject_beta_request`, `admin_list_beta_requests`.
- `is_beta_active(uuid)`, `get_beta_status()` (anon EXECUTE revoked in 074), `beta_slot_cap()→90` (063), `beta_user_quota_bytes`, `beta_inactivity_days`, `sweep_inactive_beta` (070), `beta_heartbeat`/`user_heartbeat`.

### Notifications & social
- `admin_create_notification(...)`, `admin_delete_notification`, `admin_list_notifications`, `admin_notification_responses`, `list_notifications`, `submit_notification_response`, `mark_notification_read`, `dismiss_read_notifications` (069).
- `search_profiles`, `suggested_profiles`, conversation RPCs (`get_my_conversations`, `mark_conversation_read`, `create_group_conversation`, `open_direct_conversation`, ...).

## Notes
- Convention: helper/admin/service RPCs are `REVOKE`d from `anon`/`authenticated` and granted only to the role that needs them; 072–074 enforce this globally (no `anon` EXECUTE on any DEFINER fn). See [[migrations-security]].
- Worker-facing subset is exactly the RPCs in [[worker_rls]] (`get_asset_access`, `get_pub_upload_allowed`, `r2_evict_pop`, `world_media_sign_put/get`).
