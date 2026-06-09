---
type: file-note
domain: backend
path: cloudflare/wrangler.toml
layer: backend
language: toml
status: stable
updated: 2026-06-09
tags: [file]
---

# `wrangler.toml`

> [!abstract] Primary Purpose
> Deployment configuration for the `dmt-assets` Cloudflare Worker: declares the R2 bucket binding, the KV namespace for rate limiting, and the public (non-secret) environment vars (Supabase URL + size/quota/rate constants). Secrets (`SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_TOKEN`) are NOT here — set via `wrangler secret put`.

## Inputs / Outputs
**Inputs**
- `wrangler deploy` / `wrangler dev` consume this file.

**Outputs**
- Worker entrypoint `src/worker.ts`, bindings + env vars exposed to the Worker's `Env`.

## Dependencies & Links
- Depends on: [[worker]]
- Used by: [[Deployment-and-Ops]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[worker_rate_limit]]

## Key Logic / Variables
- `name = "dmt-assets"`, `main = "src/worker.ts"`, `compatibility_date = "2025-01-01"`, `compatibility_flags = ["nodejs_compat"]`.
- `[[r2_buckets]]` binding `R2_BUCKET` → bucket `dmt-assets` (create with `wrangler r2 bucket create dmt-assets`).
- `[[kv_namespaces]]` binding `RATE_KV` → id `c7108c256a5342389b036d5bfa80cc7a`.
- `[vars]`:
  - `SUPABASE_URL = "https://zapecuofyecpgazfyyhs.supabase.co"` (public, also visible client-side)
  - `MAX_UPLOAD_BYTES = 20971520` (20 MB per item ceiling)
  - `USER_QUOTA_BYTES = 104857600` (100 MB combined cloud_backups + community_assets)
  - `DOWNLOAD_LIMIT_PER_HOUR = 20`
  - `UPLOAD_LIMIT_PER_HOUR = 60`
- Not in this file but read by the Worker: `CATALOG_GET_LIMIT_PER_HOUR` (default 600), `ADMIN_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY` — provided as wrangler secrets.

## Notes
- The 100 MB user quota here is the combined cloud-backup + counted-asset ceiling enforced at upload; per-kind limits live in `worker.ts` `KIND_MAX_BYTES`. Beta-tier quota (100 MB) is enforced separately in SQL (`beta_user_quota_bytes`).
