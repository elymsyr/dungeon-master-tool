---
type: file-note
domain: world-content
path: flutter_app/lib/application/providers/first_party_catalog_provider.dart
layer: application
language: dart
status: stable
updated: 2026-09-01
tags: [file]
---

# `first_party_catalog_provider.dart`

> [!abstract] Primary Purpose
> INSTALL side of the official content channel. Wraps [[first_party_catalog_service]] in providers and holds `FirstPartyInstallNotifier` — the state notifier that turns a catalog card into an installed local package: resolve `requires` transitively, fetch each payload, materialise the R2 banner as the package cover, and hand the payload to [[package_payload_importer]] with `installedFrom: 'official'`. This is the only path official content takes in a **release** build; the bundled `assets/open5e_packs/` route ([[bundled_packs_bootstrap]], `AssetsPackInstaller`) is debug/admin-only.

## Inputs / Outputs
**Inputs**
- `firstPartyManifestProvider` — `FutureProvider<List<CatalogEntry>>`, the whole manifest (R2 → bundled fallback; never surfaces an offline error). `firstPartyCatalogProvider` (packages) and `firstPartyWorldCatalogProvider` (worlds) are the item-type slices of it; both feed the same `OfficialPackagesCatalogView`.
- `assetsPacksAvailableProvider` — `rootBundle` probe (BB-1): false in normal production builds, which is why the admin "Install asset packs" toggle is hidden there.
- `CatalogEntry` fields used at install: `slug`, `version`, `requires`, `r2Path` / `bundledAsset`.

**Outputs**
- `firstPartyInstallProvider` — `Map<String, CatalogInstallStatus>` per slug (`idle` / `installing` / `done` / `error`).
- `isCatalogUpdateAvailable(installedVersion, catalogVersion)` — pure semver compare used by [[official_package_dialog]] to offer an upgrade (audit D2).
- A local `packages` row per installed entry, stamped `metadata.installed_from = 'official'`, `metadata.catalog_version = entry.version`, plus `cover_image_path` when a banner downloaded.
- Invalidates `packageListProvider` **and `packageMetadataProvider`** (whole family) after each install — the latter so the stored `catalog_version` an update check reads is re-fetched.

## Dependencies & Links
- Depends on: [[first_party_catalog_service]], [[package_payload_importer]], `CoverImageBundler`, `AssetsPackInstaller`, `AppPaths`.
- Related: [[Package-Links]] (where `requires` comes from), [[build_catalog]] (`_requiredSlugs`), [[emit]] (`pack_version` → the version installed here), [[bundled_packs_bootstrap]] (the debug-only twin).
- Domain map: [[World-and-Content]]
- Spec / reference: [[catalog-publish-ops]]

## Key Logic / Variables
- **Dependency install order**: `install(entry)` runs a cycle-safe post-order DFS over `entry.requires` against the manifest (mirrors `PackageLinkService.closure`), installs dependencies first, and **fails the whole install** if a dependency install fails. A required slug that is absent from the manifest is skipped — the link simply dangles, matching the soft-ref rule that a missing target is a warning, never a failure.
- **Naming**: the local package row is named after `metadata.title` (see [[package_payload_importer]]), which is why a `metadata.links` entry must carry the **title** in `name` and the **catalog slug** in `slug` — two different strings, one for each side. See [[Package-Links]].
- **Upgrade check (D2, 2026-08-13)**: `isCatalogUpdateAvailable` parses both sides as strict `major.minor.patch` and compares component-wise (so `1.9.0 → 1.10.0` *is* an update). Fail-soft: a null, empty or non-semver version on either side returns false — no nagging on data we don't understand. An upgrade is just `install(entry)` again; [[package_payload_importer]] saves over the same row name and carries declared links across.
- **Worlds (2026-09-01)**: `_installOne` branches on `itemType == 'world'` to `_installWorld`, which delegates to [[bundled_worlds_installer]]`.installFromCatalog` — a world is a campaign, not a package, so it never touches [[package_payload_importer]]. The returned `InstallReport` is surfaced, not swallowed: `failures` → `error` phase, `issues` → `done` with a "N content issue(s)" message (a map that failed to download is not a clean install). Invalidates `campaignListProvider`.
- **Banner**: `fetchBanner(slug)` → base64 → `CoverImageBundler.restore` into `AppPaths.packagesDir`, so the Packages tab shows the same art as the catalog card.

## Notes
- ✅ **Upgrade path exists since 2026-08-13 (audit D2).** The notifier is still install-only; the *comparison* lives here and the UI lives in [[official_package_dialog]]. With [[emit]]'s `packVersion` now a hand-bumped semver const and the catalog rebuilt, a user on `@1.0.0` sees "Update to v1.1.0". Guarded by `test/application/providers/first_party_catalog_update_test.dart`.
- ⚠️ **Still unpublished.** The upgrade only fires once `publish_catalog` has actually uploaded the new version — see [[publish_catalog]]; that run needs `DMT_WORKER_URL` + `ADMIN_TOKEN`.
- **Uninstall + reverse links**: handled outside this file. Official packs are ordinary local rows deleted through the Packages tab, which warns via `PackageLinkService.reverseLinks` ([[package_link_service]]). `AssetsPackInstaller.uninstallAll` deliberately does not — it is an admin bulk toggle with no per-pack decision.
