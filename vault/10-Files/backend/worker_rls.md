---
type: file-note
domain: backend
path: cloudflare/src/rls.ts
layer: backend
language: typescript
status: stable
updated: 2026-09-23
tags: [file]
---

# `rls.ts`

> [!abstract] Primary Purpose
> The Worker's authorization shim. It calls the `SECURITY DEFINER` Supabase RPCs over PostgREST using the service-role key (so RLS is bypassed and real authorization lives inside the SQL function bodies). Covers asset access, pinned (`pub/`) upload reservation, world-media signing permission (Faz 5d), and the eviction queue pop.

## Inputs / Outputs
**Inputs**
- `supabaseUrl`, `serviceRoleKey`, plus per-fn user/key/byte args.
- All requests POST to `${supabaseUrl}/rest/v1/rpc/<fn>` with `apikey` + `Authorization: Bearer <serviceRoleKey>`.

**Outputs**
- `checkAssetAccess(userId, r2Key) → bool` via `get_asset_access(p_user_id, p_r2_key)`.
- `popEvictQueue(limit) → EvictRow[]` via `r2_evict_pop(_limit)` (099).
- `worldMediaSignPut(userId, worldId, shas) → {sha256, ext, bytes, mime}[]` via `world_media_sign_put` — yalnız dünyanın sahibi, yalnız rezerve edilmiş sha; `bytes` + `mime` imzaya bağlanır.
- `worldMediaSignGet(userId, shas) → {sha256, world_id, ext}[]` via `world_media_sign_get` — kullanıcının üyesi olduğu herhangi bir dünyada **onaylı** sha.
- Yeni üçü ortak `serviceRpc<T>` üzerinden; eski ikisi (`checkAssetAccess`, `checkPubUploadAllowed`) kendi fetch'lerini tutuyor.
- Throws on non-2xx (`*_rpc_failed_<status>`); Worker maps these to `502`.

## Dependencies & Links
- Depends on: [[rpc-reference]], [[migrations-media-storage]]
- Used by: [[worker]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-security]]

## Key Logic / Variables
- Each helper tolerates two PostgREST response shapes: a bare scalar (`true`/`false`) or `{ "<fn_name>": true }`.
- `EvictRow = { id, r2_key }` — 099'dan beri her kuyruk satırı tam key taşır (`pub/…` ya da `worlds/{worldId}/…`); Worker onu siler.
- The RPCs are `REVOKE`d from `anon`/`authenticated` and granted only to `service_role`; the Worker is the only legitimate caller. `r2_evict_pop` uses `FOR UPDATE SKIP LOCKED` so two concurrent worker sweeps don't conflict.

## Notes
- `get_asset_access` was uploader-only until migration 060 widened it to shared-world members; see [[migrations-media-storage]]. `checkTransientAccess` / `get_transient_access` 099'da silindi.

## `checkPubUploadAllowed` (089)
`pub/{sha}.{ext}` key'inde kullanıcı prefix'i yoktur, dolayısıyla Worker prefix eşleşmesiyle PUT yetkisi veremez. Kapı **rezervasyondur**: client önce `pub_asset_reserve` RPC'sini çağırır (dedup + 5 GB havuz + 500 MB yayıncı cap'leri orada), sonra PUT eder; bu fonksiyon `get_pub_upload_allowed(p_user_id, p_sha)` ile o rezervasyonun (`pub_asset_refs` satırı) gerçekten var olduğunu doğrular. Kuyruk satırı 089'da `r2_key` aldı, 099'da yalnız onu taşıyor. Bkz. [[Media-Storage-Tiers]], [[worker]].
