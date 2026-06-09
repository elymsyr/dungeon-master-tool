---
type: file-note
domain: backend
path: cloudflare/src/rls.ts
layer: backend
language: typescript
status: stable
updated: 2026-06-09
tags: [file]
---

# `rls.ts`

> [!abstract] Primary Purpose
> The Worker's authorization shim. It calls four `SECURITY DEFINER` Supabase RPCs over PostgREST using the service-role key (so RLS is bypassed and real authorization lives inside the SQL function bodies). Covers counted-asset access, combined storage quota, transient-share access, and the transient eviction queue pop.

## Inputs / Outputs
**Inputs**
- `supabaseUrl`, `serviceRoleKey`, plus per-fn user/key/byte args.
- All requests POST to `${supabaseUrl}/rest/v1/rpc/<fn>` with `apikey` + `Authorization: Bearer <serviceRoleKey>`.

**Outputs**
- `checkAssetAccess(userId, r2Key) → bool` via `get_asset_access(p_user_id, p_r2_key)`.
- `checkAssetQuota(userId, newBytes, limitBytes) → bool` via `check_asset_quota(p_user_id, p_new_bytes, p_limit)`.
- `checkTransientAccess(userId, uploaderId) → bool` via `get_transient_access(p_user_id, p_uploader_id)`.
- `popTransientEvictQueue(limit) → TransientEvictRow[]` via `transient_evict_pop(_limit)`.
- Throws on non-2xx (`*_rpc_failed_<status>`); Worker maps these to `502`.

## Dependencies & Links
- Depends on: [[rpc-reference]], [[migrations-media-storage]]
- Used by: [[worker]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-security]]

## Key Logic / Variables
- Each helper tolerates two PostgREST response shapes: a bare scalar (`true`/`false`) or `{ "<fn_name>": true }`.
- `TransientEvictRow = { id, sha256, ext, uploader_id }` — the Worker reconstructs the R2 key `transient/{uploader_id}/{sha256}{ext}` and deletes it.
- The RPCs are `REVOKE`d from `anon`/`authenticated` and granted only to `service_role`; the Worker is the only legitimate caller. `transient_evict_pop` uses `FOR UPDATE SKIP LOCKED` so two concurrent worker sweeps don't conflict.

## Notes
- `get_asset_access` was uploader-only until migration 060 widened it to shared-world members (mirrors `get_transient_access`); see [[migrations-media-storage]].
