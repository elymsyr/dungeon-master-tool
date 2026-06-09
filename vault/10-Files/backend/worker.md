---
type: file-note
domain: backend
path: cloudflare/src/worker.ts
layer: backend
language: typescript
status: stable
updated: 2026-06-09
tags: [file]
---

# `worker.ts`

> [!abstract] Primary Purpose
> The `dmt-assets` Cloudflare Worker — the single HTTP gateway in front of the R2 bucket. It authenticates every counted-asset request with a Supabase JWT, enforces RLS via service-role RPCs, applies per-hour rate limits and per-kind/quota size limits, and streams objects in/out of R2. It also hosts the public first-party content catalog (`/catalog/*`) and admin maintenance routes (transient evict-sweep, full/per-user R2 purge). The Worker never writes the `community_assets` metadata row — the Flutter client does that.

## Inputs / Outputs
**Inputs**
- Bindings (`Env`): `R2_BUCKET` (R2), `RATE_KV` (KV namespace), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_TOKEN` (secret), size/limit vars.
- Request headers: `Authorization: Bearer <supabase jwt>`, `X-Asset-Kind`, `X-Content-SHA256`, `Content-Length`, `Content-Type`.
- Calls into `jwt.ts` (`verifyJwt`), `rate_limit.ts` (`checkRateLimit`), `rls.ts` (`checkAssetAccess`, `checkAssetQuota`, `checkTransientAccess`, `popTransientEvictQueue`).
- Indirectly reads Supabase RPCs `get_asset_access`, `check_asset_quota`, `get_transient_access`, `transient_evict_pop` (all service-role only).

**Outputs**
- R2 object stream (GET), R2 put (PUT), R2 delete (DELETE / purge).
- JSON status responses (`jsonResponse`), `429` rate-limited responses with `Retry-After`.
- Admin endpoints return purge/sweep counts.

## Dependencies & Links
- Depends on: [[worker_jwt]], [[worker_rls]], [[worker_rate_limit]], [[rpc-reference]], [[migrations-media-storage]]
- Used by: [[entity_image_upload]], [[free_media_service]], [[edge-beta-purge]], [[wrangler_config]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-security]]

## Key Logic / Variables
- **Routing** (`handleRequest`): `OPTIONS`→CORS 204; `/transient/evict-sweep`, `/admin/purge-all`, `/admin/purge-user` (admin-gated POST); `/catalog/{key}` (public GET, admin PUT/DELETE); `/assets/{key}` (JWT-gated GET/PUT/DELETE). Key sanitized against `..`, leading `/`, `//`.
- **Auth**: `/assets/*` requires `Bearer` JWT verified by `verifyJwt`; `payload.sub` becomes `userId`. Admin routes use `checkAdminAuth` — constant `ADMIN_TOKEN` Bearer (rejects if token < 16 chars).
- **Download** (`handleDownload`): rate-limit (`dl`) → RLS. `transient/{uploaderId}/...` keys use `checkTransientAccess(userId, uploaderId)`; all other keys use `checkAssetAccess(userId, r2Key)`. On allow, streams R2 object with `Cache-Control: private, max-age=604800` and `X-Content-SHA256`.
- **Upload** (`handleUpload`): prefix must equal `transient/{userId}/` (transient) or `{userId}/` (permanent) else `403 prefix_mismatch`. Rate-limit (`ul`). Size limit = `min(MAX_UPLOAD_BYTES, KIND_MAX_BYTES[X-Asset-Kind])`; unknown kind falls back to the global ceiling, never exceeds it. **Permanent only**: quota check via `checkAssetQuota`, where asset effective limit = `USER_QUOTA_BYTES - ASSET_QUOTA_RESERVE_BYTES (4 MB)` (reserve kept for cloud backups). Transient skips quota. MIME allowlist: `image/*`, `audio/*`, plus exact `application/gzip`, `application/octet-stream`. `X-Content-SHA256` must be 64 hex chars. Stores `customMetadata`: uploader, sha256, `transient:'true'` if transient.
- **`KIND_MAX_BYTES`**: portrait/cover/entity-image/extra-image/mind_map = 4 MB; `battle_map` = 10 MB. Must stay in sync with Flutter `MediaKind`.
- **Catalog** (`handleCatalog`): GET is public, per-IP rate-limited (`cat`, `CATALOG_GET_LIMIT_PER_HOUR` default 600). `manifest.json` cached 120 s; versioned payloads `public, max-age=31536000, immutable`. PUT/DELETE need `ADMIN_TOKEN`. Objects live under `catalog/` prefix.
- **Maintenance**: `handleTransientEvictSweep` pops up to 500 (clamp) rows from `transient_evict_pop`, deletes R2 keys `transient/{uploader}/{sha}{ext}`. `handleAdminPurgeAll` cursor-paginates R2 (5 pages × 1000/invocation, batch-200 parallel delete), `?dry=1` counts only, returns `next_cursor`. `handleAdminPurgeUser` sweeps two prefixes `{userId}/` and `transient/{userId}/` (UUID rough-validated `[0-9a-fA-F-]{20,64}`).

## Notes
- Worker is the enforcement point for the **counted/transient** media tiers; the **free** tier goes directly to Supabase Storage and never touches this Worker (see [[migrations-media-storage]]).
- DB↔R2 consistency on purge is the caller's responsibility; orphan `community_assets`/`free_media_assets` rows must be cleared by migration/RPC first.
- Worker NOT deployed to production per memory notes (catalog initiative deferred).
