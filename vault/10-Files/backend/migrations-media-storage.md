---
type: file-note
domain: backend
path: supabase/migrations/053_free_media_bucket.sql, 054_transient_share.sql, 055_online_count_limits.sql, 060_asset_access_shared_world.sql, 065_transient_shared_pool.sql
layer: backend
language: sql
status: stable
updated: 2026-06-09
tags: [file]
---

# `Migrations — Media Storage (3-Tier Model)`

> [!abstract] Primary Purpose
> Defines the three-tier media storage model and its server-side enforcement. **Free tier** (portraits, world/package covers) lives in a public Supabase Storage bucket and never counts toward quota. **Counted tier** lives in R2 with quota enforcement. **Transient tier** (storage-full / projection shares) lives under R2 `transient/` with no quota but a per-user 100 MB cap + global 10 GB LRU pool. Also adds per-user/per-world count limits and widens counted-asset read access to shared-world members.

## Inputs / Outputs
**Inputs**
- Run in Supabase SQL Editor. References `worlds`/`world_members` (026), `community_assets` (002), `auth.users`.

**Outputs**
- Bucket `free-media` (public, 2 MB/file). Tables: `free_media_assets`, `transient_shares`, `transient_evict_queue`.
- RPCs (see [[rpc-reference]]): `get_transient_access`, `get_asset_access` (re-defined), `transient_reserve`, `transient_touch`, `transient_evict_pop`, `transient_per_user_cap_bytes`, `transient_pool_cap_bytes`, plus count-limit constants + `enforce_world_character_limits`.

## Dependencies & Links
- Depends on: [[migrations-auth-social]], [[migrations-online-worlds]]
- Used by: [[worker]], [[worker_rls]], [[free_media_service]], [[entity_image_upload]], [[entity_media_cleanup_service]], [[rpc-reference]], [[edge-beta-purge]]
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
