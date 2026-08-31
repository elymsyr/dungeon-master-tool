---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/bundled_worlds_installer.dart
layer: application
language: dart
status: stable
updated: 2026-08-31
tags: [file]
---

# `bundled_worlds_installer.dart`

> [!abstract] Primary Purpose
> What the admin dashboard's "bundled worlds" toggle actually runs. Reads each world
> under `assets/worlds/`, extracts its media to disk, converts the blueprints through
> [[world_blueprint_converter]] and saves the result as a **world** (Worlds tab, not
> Packages). It does I/O only — no conversion logic of its own.

## Inputs / Outputs
**Inputs**
- `rootBundle` assets: `assets/worlds/manifest.json`, then per world `manifest.json`, `world-blueprint.json`, `blueprint.json`, and every path listed in the world manifest's `files` block.
- `CampaignRepository` (`getAvailable`, `load`, `save`, `delete`).

**Outputs**
- `installAll()` → `InstallReport` (`installed`, `issues`, `failures`).
- `uninstallAll()` → count of worlds stamped `metadata.installed_from == 'assets'`.
- Writes media to `AppPaths.worldsDir/_bundled/<dir>/…`.

## Dependencies & Links
- Depends on: [[world_blueprint_converter]], [[builtin_content_names]], [[world_repository_impl]] (via `CampaignRepository`), `AppPaths`
- Used by: [[first_party_catalog_provider]] → `admin_screen`
- Domain map: [[World-and-Content]]

## Key Logic / Variables
Three things are load-bearing and each fixes a way content used to vanish:
1. **The world is saved with the built-in D&D 5e template** (`template_id`, `template_hash`, `template_original_hash`, `world_schema`). `CampaignRepository.save` opens a *template-less* world for a new name, and `WorldRepositoryImpl._loadFromDb` only runs its SRD self-heal when `templateId == builtinDnd5eV2SchemaId` — so without this the SRD pack is never linked, every `{slug, name}` soft ref (weapon, armor, spell, trait) has no target, and the whole built-in catalog is absent from the world.
2. **Media is extracted to disk** and `image_path` rewritten to an **absolute** path. `AssetRef` treats a non-scheme'd ref as a local filesystem path (`File(path)`); a relative `media/Tokens/x.webp` never opens, so no image ever rendered. Extraction is idempotent — an already-written file is skipped.
3. **Failures are reported, not swallowed.** The old `catch (e) { }` per world is why a partially-installed world looked like a success.

Existing worlds are merged (`{...previous, ...converted}`) because `_saveToDb` is full-replace on `entities`.

## Notes
- The `_bundled/` media root is per-user (`AppPaths.worldsDir` follows the active user); reinstalling after a user switch re-extracts.
