---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/bundled_packs_bootstrap.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `bundled_packs_bootstrap.dart`

> [!abstract] Primary Purpose
> Debug-only auto-installer that reconciles the bundled Open5e content packs (`assets/open5e_packs/`) into the local package store once per app session per DB instance. Self-heals stale/missing content on every debug launch independent of the admin "Install asset packs" toggle, using a content-hash freshness gate (versions are not bumped between regenerations).

## Inputs / Outputs
**Inputs**
- `assets/open5e_packs/manifest.json` (+ per-pack `asset` files) via `rootBundle`, with a `kDebugMode && !kIsWeb` on-disk `File` fallback.
- Constructor: `AppDatabase _db`, `PackageRepository _repo`.
- Reads: `packagesDao.getByName`, `packagesDao.countEntities`.

**Outputs**
- `ensureInstalled()` -> count of packs (re)installed (0 when current / unavailable).
- Installs via `PackagePayloadImporter(_repo).install(..., installedFrom: 'assets', extraMetadata: {'bundled_content_hash': hash})`.
- `resetInstallGate()` static — clears the per-process gate.

## Dependencies & Links
- Depends on: [[package_payload_importer]], [[packages_dao]], `PackageRepository` (`package_repository`), [[srd_core_pack]] (built-in v2 schema)
- Used by: app-startup bootstrap provider (guarded on `kDebugMode`)
- Domain map: [[World-and-Content]]
- System flow: [[Content-Pipeline]]
- Spec / reference: [[Open5e-API]]

## Key Logic / Variables
- **Per-process gate** `_installedFor: Set<int>` keyed by `identityHashCode(_db)` so an auth-driven DB swap re-reconciles into the new DB (mirrors `SrdCorePackageBootstrap`). Marked done even when the manifest is absent (release / off-disk) to avoid re-probing rootBundle on every package read.
- **Freshness by content hash**: `pack_version`/`source_data_rev` stay `1.0.0`/`staging-…` between regenerations, so version compares can't detect change. Instead it `sha1.convert(utf8.encode(payloadRaw))` and stores the digest under `metadata.bundled_content_hash`; a pack is SKIPPED only when an existing non-empty row (`countEntities > 0`) carries the SAME stored hash (`_storedHash` reads it back out of `Package.stateJson`).
- **BB-1 release exclusion**: the ~32MB packs are excluded from release bundles; readable off-disk only under `kDebugMode`. The driving provider guards on `kDebugMode` so this is a deliberate no-op in release, where the official R2 catalog ([[first_party_catalog_service]]) is the real delivery channel.
- `_packageName` matches importer logic: prefer `metadata.title`, fall back to `package_name` slug.
- Best-effort: a malformed manifest/payload must not block startup; on exception the gate is left UNMARKED so a later call can retry.

## Notes
- Counterpart to `SrdCorePackageBootstrap` (built-in SRD) — that one always runs, this one is debug-only bundled extras.
