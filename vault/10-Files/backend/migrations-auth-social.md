---
type: file-note
domain: backend
path: supabase/migrations/001_cloud_backups.sql, 002_community_assets.sql, 003_social.sql, 004_likes_and_storage.sql, 005_game_listings_and_marketplace.sql
layer: backend
language: sql
status: stable
updated: 2026-06-09
tags: [file]
---

# `Migrations 001–005 — Auth, Backups, Assets & Social`

> [!abstract] Primary Purpose
> The foundational Supabase schema family: cloud campaign backups, the R2-backed `community_assets` metadata + access/quota RPCs, the social layer (profiles, follows, posts, conversations, admins), the storage buckets + RLS for payloads/images/avatars, and the first marketplace/game-listing tables. All tables are RLS-enabled; cross-cutting RPCs (`get_asset_access`, `get_user_total_storage_used`, `check_asset_quota`, `is_admin`) defined here are consumed by the Cloudflare Worker and the app.

## Inputs / Outputs
**Inputs**
- Run manually in Supabase SQL Editor. Reference `auth.users`.

**Outputs**
- Tables: `cloud_backups`, `community_assets`, `profiles`, `follows`, `shared_items`, `game_listings`, `posts`, `conversations`, `conversation_members`, `messages`, `app_admins`, `post_likes`, `game_listing_applications`.
- Storage buckets: `campaign-backups` (private, 10 MB, gzip), `shared-payloads` (private), `post-images` (public), `avatars` (public).
- RPCs (see [[rpc-reference]]).

## Dependencies & Links
- Depends on: Supabase `auth.users`, `storage.objects`
- Used by: [[worker]], [[worker_rls]], [[migrations-online-worlds]], [[migrations-media-storage]], [[migrations-security]], [[rpc-reference]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables — per migration
- **001_cloud_backups** — `cloud_backups` (client-gen UUID PK, `user_id` FK cascade, `item_id/type` (`world|template|package`), `storage_path = {user_id}/{type}s/{item_id}.json.gz`, `size_bytes`, `schema_version`). RLS "Users manage own backups" (`auth.uid()=user_id`). Bucket `campaign-backups` (10 MB, `application/gzip`) with per-folder storage RLS. RPC `get_user_storage_used(uuid)→bigint` (sum of own backups).
- **002_community_assets** — `community_assets` (UUID PK, `uploader_id` FK, `r2_object_key UNIQUE`, `sha256_hash`, `mime_type`, `size_bytes`, `campaign_id`, `session_id`). RLS "Uploader manages own assets". RPCs: `get_asset_access(p_user_id,p_r2_key)→bool` (originally uploader-only; widened in 060), `get_user_total_storage_used(uuid)→bigint` (cloud_backups + community_assets), `check_asset_quota(p_user_id,p_new_bytes,p_limit)→bool`. The access/quota RPCs are `service_role`-only (Worker is the caller).
- **003_social** — `profiles` (public read, self-write), `follows`, `shared_items`, `game_listings`, `posts`, `conversations`/`conversation_members`/`messages` (membership-gated via `is_conversation_member`), `app_admins` (opaque table) + `is_admin()` RPC. Re-defines `get_user_total_storage_used` to add posts + shared_items. `search_profiles(query,limit)`.
- **004_likes_and_storage** — buckets `shared-payloads` (private, owner-write, authenticated-read), `post-images` (public read, owner write), `avatars` (public read, owner write); table `post_likes` (public read, self-manage).
- **005_game_listings_and_marketplace** — language/tag indexes on game_listings + shared_items; `game_listing_applications` (applicant-or-owner read); RPCs `increment_shared_item_downloads`, `suggested_profiles`.

## Notes
- The newer marketplace model (snapshot + lineage, `marketplace_listings`) supersedes `shared_items`/`game_listings` starting at migration 006.
- `is_admin()` (defined here) is the admin gate reused by every `admin_*` RPC and the [[edge-beta-purge]] edge function.
