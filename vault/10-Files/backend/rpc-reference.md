---
type: file-note
domain: backend
path: supabase/migrations/*.sql (CREATE FUNCTION catalog)
layer: backend
language: sql
status: stable
updated: 2026-06-09
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
- Used by: [[worker]], [[worker_rls]], [[edge-beta-purge]], [[supabase_world_membership_service]], [[world_join_service]], [[character_claim_service]], [[free_media_service]], [[beta_enter_gate]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables — RPC catalog

### Media / storage (Worker calls these — `service_role` only unless noted)
- `get_asset_access(p_user_id uuid, p_r2_key text) → bool` — counted R2 asset readable? uploader OR shared-world member (002, widened 060).
- `check_asset_quota(p_user_id uuid, p_new_bytes bigint, p_limit bigint) → bool` — would this upload stay under quota? (002).
- `get_user_total_storage_used(p_user_id uuid) → bigint` — cloud_backups + community_assets (+ posts/shared_items) total; **excludes** free_media + transient (002/003). `authenticated` + `service_role`.
- `get_user_storage_used(p_user_id uuid) → bigint` — cloud_backups only (001).
- `get_transient_access(p_user_id uuid, p_uploader_id uuid) → bool` — transient R2 readable? uploader OR shared-world member (054).
- `transient_reserve(_bytes bigint, _world text) → jsonb` — pre-upload per-user 100 MB cap check + global 10 GB LRU eviction; returns `{ok, per_user_used, global_used, evicted}` (065). `authenticated`.
- `transient_touch(_sha text) → void` — bump `last_used_at` (LRU) on download (065). `authenticated`.
- `transient_evict_pop(_limit int default 20) → setof (id bigint, sha256 text, ext text, uploader_id uuid)` — drain evict queue, `FOR UPDATE SKIP LOCKED` (065). Worker `/transient/evict-sweep` calls it.
- `transient_per_user_cap_bytes() → 100 MB`, `transient_pool_cap_bytes() → 10 GB` (IMMUTABLE constants, 065).

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
- Worker-facing subset is exactly the 4 in [[worker_rls]] plus the transient caps.
