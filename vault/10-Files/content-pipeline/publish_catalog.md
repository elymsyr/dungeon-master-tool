---
type: file-note
domain: content-pipeline
path: flutter_app/tool/catalog_publish/bin/publish_catalog.dart
layer: tool
language: dart
status: stable
updated: 2026-08-13
tags: [file]
---

# `publish_catalog.dart`

> [!abstract] Primary Purpose
> Offline CLI that uploads the first-party catalog to the Cloudflare R2 worker. Reads `assets/first_party/manifest.json`, gzips each entry's bundled payload, and PUTs it to the worker's admin-gated write route at `PUT {worker}/catalog/{r2_path}` (Bearer ADMIN_TOKEN). The manifest itself is uploaded LAST (plain JSON at `catalog/manifest.json`), so the index never points at an object that isn't already present.

## Inputs / Outputs
**Inputs**
- CLI args: `--worker <url>` (else `DMT_WORKER_URL` env), `--token <ADMIN_TOKEN>` (else `ADMIN_TOKEN` env), `--dry-run`, `--force`.
- `assets/first_party/manifest.json` (built by [[build_catalog]]) + each entry's `bundled_asset` payload file.

**Outputs**
- HTTP PUTs to `{worker}/catalog/{r2_path}` (`application/gzip`) and finally `{worker}/catalog/manifest.json` (`application/json`).
- Console summary (`uploaded / skipped / failed / KB transferred`); exit 1 if any failure, exit 2 on missing worker/token/manifest.

## Dependencies & Links
- Depends on: [[build_catalog]] output, `dart:io` `HttpClient`, `dart:convert` gzip.
- Used by: deploy/release process (manual).
- Server side: `worker` (`catalog/*` routes), `worker_jwt` / admin auth.
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[catalog-publish-ops]], [[Backend-Infra]]

## Key Logic / Variables
- **Immutability**: versioned payload paths (`{type}/{slug}@{ver}.json.gz`) are immutable — an already-present object (checked via GET → 200 in `_exists`) is skipped unless `--force`.
- **Manifest last**: ensures the live index only ever references objects already uploaded.
- `--dry-run`: gzips + counts but never PUTs (token not required); logs `~ <path>`.
- Auth: `Authorization: Bearer <token>` header on every PUT.
- `_kb` formats transfer size; `_parseArgs` supports `--flag` (valueless) and `--key value`.

## Notes
- Worker not yet deployed per the First-Party Catalog memory; legal/R2 publish approval is the remaining gate for the Open5e packs (P2). Run [[build_catalog]] first or it errors.
- ⚠️ **Immutability means a content rebuild publishes nothing unless the version moves.** `r2_path` is `package/<slug>@<pack_version>.json.gz` and `_exists()` skips a path that exists, so republishing at an unchanged version reports *"19 skipped"* and no client sees the change. `--force` is not the fix: it overwrites a path the contract calls immutable and still gives clients no upgrade signal. **Fixed upstream 2026-08-13 (D1)** — [[emit]]'s `packVersion` is now a hand-bumped const at `1.1.0`, so the catalog points at unwritten paths and all 19 upload. The upload itself needs `DMT_WORKER_URL` + `ADMIN_TOKEN` (CI secrets). Client-side upgrade detection is still missing ([[first_party_catalog_provider]] never re-checks `catalog_version`) — audit phase **D2**.
