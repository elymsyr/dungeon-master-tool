---
type: file-note
domain: deployment
path: cloudflare/upload_banners.sh, flutter_app/tool/catalog_publish/bin/publish_catalog.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Catalog Publish Ops (official content → Cloudflare R2)

> [!abstract] Primary Purpose
> The operator procedure for shipping app-owned "Official Content" to the public R2 catalog. Two artifacts move: the catalog payloads + manifest (via `publish_catalog.dart`) and the card banner images (via `cloudflare/upload_banners.sh`). Both write through the Cloudflare Worker's admin-gated `PUT {worker}/catalog/...` routes, authed by a Bearer `ADMIN_TOKEN`; the matching `GET` routes are public.

## Inputs / Outputs
**Inputs**
- Env (both tools): `DMT_WORKER_URL` (the Worker base, e.g. `https://dmt-assets.<acct>.workers.dev`) and `ADMIN_TOKEN` (the `wrangler secret ADMIN_TOKEN`).
- `publish_catalog.dart` reads `assets/first_party/manifest.json` (produced by [[build_catalog]]) plus each entry's `bundled_asset` file.
- `upload_banners.sh` reads `flutter_app/assets/first_party/banners/*.jpg`.

**Outputs**
- R2 objects under `{worker}/catalog/`: versioned payloads `catalog/{type}/{slug}@{ver}.json.gz`, the `catalog/manifest.json` index, and `catalog/banners/<name>.jpg`.

## Dependencies & Links
- Depends on: [[build_catalog]], [[publish_catalog]], [[worker]], [[dart-define-reference]]
- Used by: [[first_party_catalog_service]]
- Domain map: [[Deployment-and-Ops]]
- System flow: [[Content-Pipeline]]
- Spec / reference: [[wrangler_config]], [[worker_jwt]]

## Key Logic / Variables
**End-to-end procedure (run from `flutter_app/`):**
1. Build the manifest + payloads with [[build_catalog]] → writes `assets/first_party/manifest.json`.
2. `dart run tool/catalog_publish/bin/publish_catalog.dart --worker <url> [--token <ADMIN_TOKEN>] [--dry-run] [--force]` (see [[publish_catalog]]). Token falls back to `ADMIN_TOKEN` env, worker to `DMT_WORKER_URL` env. Trailing slashes stripped.
3. `DMT_WORKER_URL=<url> ADMIN_TOKEN=<secret> ./cloudflare/upload_banners.sh` to mirror banners.
4. After re-uploading any banner, bump `kBannerAssetVersion` in [[first_party_catalog_service]] (the `?v=N` cache-buster — banners are served `immutable, max-age=1y`).

**Publish ordering / idempotency invariants (from `publish_catalog.dart`):**
- Payloads are gzipped and PUT to `catalog/{r2_path}` with `Content-Type: application/gzip`; the **manifest is uploaded LAST** as plain `application/json`, so `catalog/manifest.json` never references an object that isn't already present.
- Versioned payload paths are **immutable**: an already-present object (HEAD/GET == 200) is skipped unless `--force`. `--dry-run` gzips and reports sizes but uploads nothing (and skips the token requirement).
- Exit codes: `2` for missing worker/token/manifest; `1` if any upload failed.

**`upload_banners.sh` specifics:**
- `set -euo pipefail`; resolves the banner dir relative to the script (`../flutter_app/assets/first_party/banners`); loops `*.jpg`, `curl -fsS -X PUT` each with `Authorization: Bearer ${ADMIN_TOKEN}` and `Content-Type: image/jpeg` to `${DMT_WORKER_URL%/}/catalog/banners/${name}`; prints a final count.
- The in-app cards use the BUNDLED banner copies; this R2 mirror is for the web app / external use and for any banners not bundled (only the two built-in covers are bundled).

## Notes
- These tools require the Worker to be deployed; per project memory the catalog Worker and routes are implemented but NOT yet deployed to production. Both are operator-run, not part of [[ci-build]].
