---
type: file-note
domain: world-content
path: flutter_app/lib/application/providers/first_party_catalog_provider.dart
layer: application
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `first_party_catalog_provider.dart`

> [!abstract] Primary Purpose
> INSTALL side of the official content channel. Wraps [[first_party_catalog_service]] in providers and holds `FirstPartyInstallNotifier` — the state notifier that turns a catalog card into an installed local package: resolve `requires` transitively, fetch each payload, materialise the R2 banner as the package cover, and hand the payload to [[package_payload_importer]] with `installedFrom: 'official'`. This is the only path official content takes in a **release** build; the bundled `assets/open5e_packs/` route ([[bundled_packs_bootstrap]], `AssetsPackInstaller`) is debug/admin-only.

## Inputs / Outputs
**Inputs**
- `firstPartyCatalogProvider` — `FutureProvider<List<CatalogEntry>>`, the manifest (R2 → bundled fallback; never surfaces an offline error).
- `assetsPacksAvailableProvider` — `rootBundle` probe (BB-1): false in normal production builds, which is why the admin "Install asset packs" toggle is hidden there.
- `CatalogEntry` fields used at install: `slug`, `version`, `requires`, `r2Path` / `bundledAsset`.

**Outputs**
- `firstPartyInstallProvider` — `Map<String, CatalogInstallStatus>` per slug (`idle` / `installing` / `done` / `error`).
- A local `packages` row per installed entry, stamped `metadata.installed_from = 'official'`, `metadata.catalog_version = entry.version`, plus `cover_image_path` when a banner downloaded.
- Invalidates `packageListProvider` after each install.

## Dependencies & Links
- Depends on: [[first_party_catalog_service]], [[package_payload_importer]], `CoverImageBundler`, `AssetsPackInstaller`, `AppPaths`.
- Related: [[Package-Links]] (where `requires` comes from), [[build_catalog]] (`_requiredSlugs`), [[emit]] (`pack_version` → the version installed here), [[bundled_packs_bootstrap]] (the debug-only twin).
- Domain map: [[World-and-Content]]
- Spec / reference: [[catalog-publish-ops]]

## Key Logic / Variables
- **Dependency install order**: `install(entry)` runs a cycle-safe post-order DFS over `entry.requires` against the manifest (mirrors `PackageLinkService.closure`), installs dependencies first, and **fails the whole install** if a dependency install fails. A required slug that is absent from the manifest is skipped — the link simply dangles, matching the soft-ref rule that a missing target is a warning, never a failure.
- **Naming**: the local package row is named after `metadata.title` (see [[package_payload_importer]]), which is why a `metadata.links` entry must carry the **title** in `name` and the **catalog slug** in `slug` — two different strings, one for each side. See [[Package-Links]].
- **Banner**: `fetchBanner(slug)` → base64 → `CoverImageBundler.restore` into `AppPaths.packagesDir`, so the Packages tab shows the same art as the catalog card.

## Notes
- ⚠️ **Install-only: there is no upgrade path.** The notifier stores `metadata.catalog_version` but never compares it against the manifest, and `statusFor(...) == done` short-circuits dependencies only within a session. A user who installed `@1.0.0` keeps that payload forever — combined with [[emit]]'s hardcoded `pack_version: '1.0.0'` and [[publish_catalog]]'s skip-if-exists, regenerated official content currently cannot reach an existing install at all. Audit doc (`flutter_app/docs/open5e_content_audit.md`) phases **D1/D2** own this.
- ⚠️ **Uninstall does not consider reverse links.** Once the official packs stop duplicating content and start linking one owner (audit phase L2), deleting the owner strips content from every linker. `PackageLinkService.reverseLinks` exists for that warning but is not wired into this path.
