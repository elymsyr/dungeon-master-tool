---
type: file-note
domain: backend
path: supabase/functions/beta_purge_with_cleanup/index.ts
layer: backend
language: typescript
status: stable
updated: 2026-06-09
tags: [file]
---

# `beta_purge_with_cleanup/index.ts`

> [!abstract] Primary Purpose
> A Supabase Edge Function (Deno) that performs full user-data teardown across all three storage layers in one call, unifying self-exit and admin-revoke. It runs the appropriate DB-cleanup RPC, sweeps the user's Supabase Storage objects across three buckets, and then calls the Cloudflare Worker `/admin/purge-user` to delete the user's R2 objects. Previously these three layers were cleaned separately (admin-revoke only touched DB; self-exit had no R2 cleanup because the client lacks `ADMIN_TOKEN`).

## Inputs / Outputs
**Inputs**
- POST with `Authorization: Bearer <jwt>` and body `{ "user_id": "<uuid>" }`.
- Env: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (auto); `R2_WORKER_URL`, `R2_ADMIN_TOKEN` (manual).
- RPCs: `is_admin` (gate), `leave_beta` (self), `admin_revoke_beta` (admin).

**Outputs**
- DB cleanup via RPC, Storage objects removed (service-role), R2 purge via Worker.
- JSON: `{ ok, user_id, self, rpc, rpc_result, storage, r2 }`.

## Dependencies & Links
- Depends on: [[worker]], [[migrations-security]], [[rpc-reference]]
- Used by: [[beta_enter_gate]], [[auth_provider]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-online-worlds]]

## Key Logic / Variables
- **Auth**: caller-scoped Supabase client (caller JWT, RLS-enforced) resolves `callerId` via `auth.getUser()`. If `target_user_id !== callerId`, requires `is_admin()` RPC === true (else 403). `user_id` validated `^[0-9a-fA-F-]{20,64}$`.
- **Step 1 — DB**: `isSelf ? rpc('leave_beta') : rpc('admin_revoke_beta', {p_user})`. RPC failure → 500 `rpc_failed`.
- **Step 2 — Storage**: a service-role client wipes the `{userId}/` prefix in buckets `campaign-backups`, `free-media`, `shared-payloads`. `wipeUserPrefix` deletes top-level files then one level of subdirs (folder entries have `id === null`); `wipeFlat` paginates 1000/page via offset and `storage.remove(paths)`. Errors are best-effort (recorded per-bucket).
- **Step 3 — R2**: if `R2_WORKER_URL` + `R2_ADMIN_TOKEN` set, POST `{user_id}` to `${R2_WORKER_URL}/admin/purge-user` with `Bearer R2_ADMIN_TOKEN`; otherwise `{ skipped: true }`.
- CORS preflight handled; non-POST → 405.

## Notes
- The Storage sweep here is the only place free-media/shared-payloads R2-adjacent binaries are removed for a user; the SQL RPCs only remove rows. R2 binaries are removed by the Worker.
- Mirrors the layered teardown described in [[migrations-security]] (beta exit semantics).
