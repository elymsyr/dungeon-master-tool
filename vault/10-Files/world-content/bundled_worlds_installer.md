---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/bundled_worlds_installer.dart
layer: application
language: dart
status: stable
updated: 2026-09-01
tags: [file]
---

# `bundled_worlds_installer.dart`

> [!abstract] Primary Purpose
> Installs a packaged world as a **world** (Worlds tab, not Packages): extracts its media
> to disk, converts the blueprints through [[world_blueprint_converter]], saves the result.
> It does I/O only — no conversion logic of its own. Two entry points, one install path:
> `installAll()` (the admin dashboard's "bundled worlds" toggle, bytes from `assets/worlds/`)
> and `installFromCatalog()` (the Marketplace's official world card, bytes from R2 with a
> bundled fallback).

## Inputs / Outputs
**Inputs**
- `rootBundle` assets: `assets/worlds/manifest.json`, then per world `manifest.json`, `world-blueprint.json`, `blueprint.json`, and every path listed in the world manifest's `files` block.
- Or a `CatalogEntry` + `FirstPartyCatalogService`: the R2 envelope at `r2_path`, one object per `media[]`, and `external_files[]` fetched from the publisher.
- `CampaignRepository` (`getAvailable`, `load`, `save`, `delete`).
- `CharacterRepository` (`exists`, `save`, `loadAll`, `dropLocal`) — the blueprint's PCs.

**Outputs**
- `installAll()` / `installFromCatalog()` → `InstallReport` (`installed`, `issues`, `failures`).
- `uninstallAll()` → count of worlds stamped `metadata.installed_from` `'assets'` **or** `'official'`.
- Writes media to `AppPaths.worldsDir/_bundled/<dir>/…`.
- Writes one **ownerless** `world_characters` row per blueprint PC (world's Characters tab).

## Dependencies & Links
- Depends on: [[world_blueprint_converter]], [[builtin_content_names]], [[world_repository_impl]] (via `CampaignRepository`), `CharacterRepository`, `AppPaths`
- Used by: [[first_party_catalog_provider]] → `admin_screen`
- Domain map: [[World-and-Content]]

## Key Logic / Variables
Four things are load-bearing and each fixes a way content used to vanish:
1. **The world is saved with the built-in D&D 5e template** (`template_id`, `template_hash`, `template_original_hash`, `world_schema`). `CampaignRepository.save` opens a *template-less* world for a new name, and `WorldRepositoryImpl._loadFromDb` only runs its SRD self-heal when `templateId == builtinDnd5eV2SchemaId` — so without this the SRD pack is never linked, every `{slug, name}` soft ref (weapon, armor, spell, trait) has no target, and the whole built-in catalog is absent from the world.
2. **Media is extracted to disk** and `image_path` rewritten to an **absolute** path. `AssetRef` treats a non-scheme'd ref as a local filesystem path (`File(path)`); a relative `media/Tokens/x.webp` never opens, so no image ever rendered. Extraction is idempotent — an already-written file is skipped.
3. **Failures are reported, not swallowed.** The old `catch (e) { }` per world is why a partially-installed world looked like a success.
4. **PCs are characters, not entities.** `_installCharacters` wraps each `BlueprintConversion.characters` row in a `Character` with `ownerId: null` (unclaimed → the "Available to Claim" section) and the world's id, then writes it through `CharacterRepository`. Written as world entities they were invisible everywhere: the Database tab drops `player-character` from its category list (`entity_sidebar.dart`), and the Characters tab reads `world_characters`.

Existing worlds are merged (`{...previous, ...converted}`) because `_saveToDb` is full-replace on `entities`; the merge drops any `type == 'player-character'` row an older install left behind, so a reinstall heals the old shape.

The world id comes from `load()['world_id']` for an existing world and from the map `save()` writes back for a new one — `save` only stamps `world_id` on the create branch. Characters are **insert-only** (`exists(id)` short-circuits): ids are deterministic uuidv5 from the blueprint, so a second install must not overwrite a PC the DM has levelled up.

`uninstallAll()` drops the world's characters itself — `WorldRepositoryImpl._purgeWorld` deliberately leaves `world_characters` alone (a character normally outlives its world), but these are install artifacts and would otherwise linger pointing at a dead world id.

## Source seam (2026-09-01)
`WorldFileLoader` (`Future<Uint8List?> Function(String rel)`) is the only difference between
the two entry points — `_installWorld` takes the three decoded JSONs plus a media loader and
knows nothing about where bytes come from, so all four invariants above hold identically on
both paths. `installAll` passes a `rootBundle` loader; `installFromCatalog` passes one that
tries R2 first (fresh), then the bundled asset, then — for a file the catalog does not host —
the publisher URL from `external_files`. A loader returning null is an **issue**, never a
silent skip.

`_fetchEnvelope` mirrors that for the payload: R2 `r2_path` gz → the three bundled JSONs.
The catalog install stamps `installed_from: 'official'` + `catalog_version` (which
`campaignMetadataProvider` reads back, driving the dialog's Update state).

`_mediaPaths` skips the `pdf_url` key: it is a publisher download link, and walking it as a
media path would report "unavailable" on every install.

## Assets are not bundled (2026-09-01)
`assets/worlds/` (~326 MB) is **commented out of `pubspec.yaml`** — the same treatment
`assets/open5e_packs/` gets. Worlds now reach users only through the marketplace
(`installFromCatalog`, bytes from R2); the directory is the authoring source for
`tool/catalog_publish/` and nothing else. Consequences:
- `installAll()` and the bundle fallback inside `installFromCatalog` find nothing in a
  release build — the R2 path is the only live one.
- `isAvailable()` returns false on Android/iOS unconditionally (and everywhere else once the
  assets are absent), so the admin dashboard's "Install bundled worlds" toggle is hidden on
  mobile. A maintainer re-enables the whole thing by uncommenting the pubspec block.

## Notes
- The `_bundled/` media root is per-user (`AppPaths.worldsDir` follows the active user); reinstalling after a user switch re-extracts.
