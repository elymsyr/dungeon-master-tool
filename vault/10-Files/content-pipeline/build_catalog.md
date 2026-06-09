---
type: file-note
domain: content-pipeline
path: flutter_app/tool/catalog_publish/bin/build_catalog.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `build_catalog.dart`

> [!abstract] Primary Purpose
> Offline CLI that emits `assets/first_party/manifest.json` — the index the app reads to browse the first-party "Official Content" catalog. Each entry describes one installable item and carries BOTH a `bundled_asset` (Flutter asset path, offline fallback) and an `r2_path` (the gzipped object the publish CLI uploads under R2 `catalog/`), so the app works online (R2, fresh + updatable) and offline (bundled) with no payload duplicated in the binary.

## Inputs / Outputs
**Inputs**
- `assets/open5e_packs/manifest.json` (built by [[build_packs]]) — seeds the catalog's `package` entries; errors out if missing.
- Each `assets/open5e_packs/*.pkg.json` metadata (title, version, publisher, license, counts).
- Optional hand-authored sources under `assets/first_party/<world|character|template|sound>/*.json` (+ optional `*.meta.json` sidecars).
- Optional `assets/first_party/banners/banner-credits.yaml` (slug → creator/link image attribution).

**Outputs**
- `assets/first_party/manifest.json` — `{catalog_version: '2026-06-01', entries: [...]}`.

## Dependencies & Links
- Depends on: [[build_packs]] output, `package:yaml`, `dart:io`/`dart:convert`.
- Used by: [[publish_catalog]] (consumes the manifest); `first_party_catalog_service` (app reads it online→cache→bundled).
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[catalog-publish-ops]], [[Content-Licenses]]

## Key Logic / Variables
- Constants: `_open5eDir = 'assets/open5e_packs'`, `_firstPartyDir = 'assets/first_party'`, `_catalogVersion = '2026-06-01'`.
- `_packageEntries`: one `item_type: 'package'` entry per Open5e pack. `bundled_asset` reuses the existing open5e asset (no copy); `r2_path = 'package/<slug>@<version>.json.gz'` (versioned, immutable); also records `size_bytes`.
- `_handAuthoredEntries`: scans the 4 hand-authored types (`world`, `character`, `template`, `sound`); each `<slug>.json` payload's optional `<slug>.meta.json` supplies catalog fields, else filename + sane defaults; `r2_path = '<type>/<slug>@<version>.json.gz'`.
- `_bannerCredits`: parses `banner-credits.yaml` `credits:` map; attaches `banner_credit` (`{creator, link}`) to entries whose slug matches, so the install dialog can show a clickable image credit.

## Notes
- Per the First-Party Catalog memory (P1-P6 shipped): the worker `catalog/*` routes give public read + admin write; the worker is NOT yet deployed. P7 (template + sound persistence) deferred. v1 seeds purely from the 22 Open5e packs.
