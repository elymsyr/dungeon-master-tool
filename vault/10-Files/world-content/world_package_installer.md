---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/world_package_installer.dart
layer: application
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `world_package_installer.dart`

> [!abstract] Primary Purpose
> The single entry point for "install a package into a world". Replaces four
> hand-rolled copies of the same *register the link → build the Tier-0 index →
> sync* block, and adds the two things link-awareness needs: installing the
> package's whole link closure, and remapping refs that point into a linked
> package to that package's world-side ids.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase`, `PackageRepository`.
- `installIntoWorld({worldId, packageId})`, `resync(...)` (same path — sync is
  idempotent), `uninstallFromWorld({worldId, packageId, purgeDetached})`.
- Reads: `packages`, `package_entities`, `installed_packages`, `world_entities`.

**Outputs**
- `WorldInstallResult` — per-package `PackageSyncResult` in install order, plus
  `added`/`updated`/`removed` totals and `dependencyCount`.
- `buildForeignRefIndex(worldId)` → `packageEntityId → world id`.
- `buildLookupResolver(worldId)` → the Tier-0 `_lookup` resolver for `sync`.
- Writes: `installed_packages`, `world_entities` (through
  [[package_sync_service]]).

## Dependencies & Links
- Depends on: [[package_link_service]], [[package_sync_service]],
  [[package_import_service]] (`resolveLookupPlaceholder`), [[builtin_synth]],
  [[installed_packages_dao]], [[packages_dao]]
- Used by: [[import_package_dialog]], [[world_packages_provider]],
  [[world_packages_section]], [[world_mirror_applier]] (CDC inbound share)
- Domain map: [[World-and-Content]]
- System flow: [[Package-Links]], [[Ref-Resolution-Hard-vs-Soft]]

## Key Logic / Variables
- **Closure install** — `PackageLinkService.closure(root.name)` gives
  dependencies first, root last. All `installed_packages` rows are upserted up
  front so a package syncing early already sees its siblings; then each is
  synced in order.
- **`buildForeignRefIndex`** — rebuilt **between** packages in a closure, because
  syncing a dependency mints its world rows and the next package must see those
  ids. Two sources, in precedence order: (1) built-in pack entries via
  `synthBuiltinEntityId(worldId, packEntityId)` — SRD rows are synthesised at
  read time and never materialised; (2) every real `world_entities` row with a
  `package_entity_id`, which wins (matching `buildTier0LookupIndex`, where a
  homebrew fork overrides the pristine pack entry).
- Handed to `PackageSyncService.sync(foreignRefs:)`, which seeds `packToWorld`
  with it so the syncing package's own rows still win on collision.
- **Uninstall does not cascade** — only the requested package is removed;
  linked packages stay installed. `installed_packages` has no "installed as a
  dependency" column and adding one would bump the Drift schema past the v12
  fresh cut (renaming every existing user DB), so provenance is not tracked.
- A missing `packageId` returns an empty result; a dangling link is skipped —
  neither throws.

## Notes
- Covered by `test/application/services/world_package_installer_test.dart`
  (8 tests: closure install + order, cross-package ref remap, idempotency,
  dangling link, unknown id, non-cascading uninstall, foreign-ref index).
