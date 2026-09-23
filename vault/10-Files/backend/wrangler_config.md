---
type: file-note
domain: backend
path: cloudflare/wrangler.toml
layer: backend
language: toml
status: stable
updated: 2026-09-23
tags: [file]
---

# `wrangler.toml`

> [!abstract] Primary Purpose
> Deployment configuration for the `dmt-assets` Cloudflare Worker: declares the R2 bucket binding, the three platform rate-limiter bindings, and the public (non-secret) environment vars (Supabase URL + size/quota/rate constants). Secrets (`SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_TOKEN`) are NOT here — set via `wrangler secret put`.

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
- Spec / reference: [[worker]]

## Key Logic / Variables
- `name = "dmt-assets"`, `main = "src/worker.ts"`, `compatibility_date = "2025-01-01"`, `compatibility_flags = ["nodejs_compat"]`.
- `[[r2_buckets]]` binding `R2_BUCKET` → bucket `dmt-assets` (create with `wrangler r2 bucket create dmt-assets`).
- `[vars]`:
  - `SUPABASE_URL = "https://zapecuofyecpgazfyyhs.supabase.co"` (public, also visible client-side)
  - `MAX_UPLOAD_BYTES = 20971520` (20 MB per item ceiling)
- `[triggers] crons = ["0 * * * *"]` — saatlik `scheduled()` tetikleyicisi; `r2_evict_queue`'yu (099'a kadar `transient_evict_queue`) boşaltır — `pub/` refcount düşüşleri ve satırı silinen dünya medyası. Kuyruğu başka hiçbir şey otomatik boşaltmıyordu, elle tetik (`/admin/evict-sweep`, eski adı `/transient/evict-sweep`) yetmiyordu ve R2'da yetim obje birikiyordu. Bkz. [[worker]].
- `R2_BUCKET_NAME = "dmt-assets"` (var) + `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` (**secret**, Faz 5d) — `/world-media/sign`'ın SigV4 imzası için R2 S3 API token'ı (Object Read & Write, yalnız bu bucket). Biri eksikse uç 503 `presign_not_configured`. Web istemcisi için bucket'ta CORS gerekir (GET/PUT, `content-type`).
- `[[ratelimits]]` × 3 — **tüm** rate limiting burada, KV yok:
  | binding | namespace_id | limit | kapsam / anahtar |
  |---|---|---|---|
  | `CATALOG_RL` | 1001 | 300 / 60 s | public `GET /catalog/*`, `CF-Connecting-IP` |
  | `DL_RL` | 1002 | 600 / 60 s | `GET /assets/*`, `userId` |
  | `UL_RL` | 1003 | 20 / 60 s | `PUT /assets/*`, `userId` |
- Not in this file but read by the Worker: `ADMIN_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY` — provided as wrangler secrets.

## Notes
- **KV rate limiter kaldırıldı (2026-09-21, `online-again` Faz 0).** `[[kv_namespaces]] RATE_KV`, `DOWNLOAD_LIMIT_PER_HOUR`, `UPLOAD_LIMIT_PER_HOUR` ve `cloudflare/src/rate_limit.ts` hep birlikte silindi. Sebep: sayaç her izinli istekte `kv.put` yapıyordu, free tier günde 1000 write veriyor, kota dolunca limiter fail-open geçip sessizce kayboluyordu (`audit-2026-09.md` §5). Platform limiter sayacı edge'de tutar — kota yok, kaybolmaz.
- İki bilinçli takas, ikisi de `CATALOG_RL` ile zaten kabul edilmişti: `period` **yalnızca 10 veya 60 saniye** olabiliyor (saatlik tavanlar dakikalığa çevrildi: 10 000/saat → 600/dk, 60/saat → 20/dk) ve sayaçlar **per-colo**, global değil. Burası bir abuse freni; gerçek tavanlar R2 kotası ve `KIND_MAX_BYTES`.
- Limitler **iki yerde**: burası uygular, `worker.ts` başındaki `CATALOG_LIMIT_PER_MIN` / `DL_LIMIT_PER_MIN` / `UL_LIMIT_PER_MIN` yalnızca 429 gövdesinde bildirilir. Platform limiter sayaç döndürmediği için elle senkron tutulur; ayrışırlarsa limit doğru uygulanır, sadece 429 gövdesi yanlış sayı söyler.
- Kullanıcı başına depolama kotası **yok** (Phase D): `USER_QUOTA_BYTES` kaldırıldı. Yükleme tavanları per-kind (`worker.ts` `KIND_MAX_BYTES`, bilinmeyen kind için `MAX_UPLOAD_BYTES`) ve havuz tarafında `transient_max_file_bytes()` / `pinned_*_cap_bytes()`.
