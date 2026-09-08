---
type: file-note
domain: backend
path: cloudflare/wrangler.toml
layer: backend
language: toml
status: stable
updated: 2026-09-08
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
  - `DOWNLOAD_LIMIT_PER_HOUR = 10000` (2026-09-08'de 20'den yükseltildi — talep-üzerine medyada bir oyuncunun ilk katılışı paylaşılmış her kart görselini tek tek çekiyor, 20'de 429 yiyordu)
  - `UPLOAD_LIMIT_PER_HOUR = 60`
- `[triggers] crons = ["0 * * * *"]` — saatlik `scheduled()` tetikleyicisi; `transient_evict_queue`'yu boşaltır. Kuyruğu başka hiçbir şey otomatik boşaltmıyordu, `/transient/evict-sweep` yalnızca elle POST ediliyordu ve R2'da yetim obje birikiyordu. Bkz. [[worker]].
- `[[ratelimits]] CATALOG_RL` (namespace 1001, 300/60s) — public catalog GET; KV sayacı kullanmaz.
- Not in this file but read by the Worker: `ADMIN_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY` — provided as wrangler secrets.

## Notes
- Kullanıcı başına depolama kotası **yok** (Phase D): `USER_QUOTA_BYTES` kaldırıldı. Yükleme tavanları per-kind (`worker.ts` `KIND_MAX_BYTES`, bilinmeyen kind için `MAX_UPLOAD_BYTES`) ve havuz tarafında `transient_max_file_bytes()` / `pinned_*_cap_bytes()`.
