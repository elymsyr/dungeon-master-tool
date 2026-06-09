---
type: file-note
domain: world-content
path: flutter_app/lib/application/providers/builtin_package_provider.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `builtin_package_provider.dart`

> [!abstract] Primary Purpose
> Riverpod providers that expose the installed built-in SRD pack to the rest of the app: its Drift row id (for player-visibility / share classification) and a typed, read-only snapshot of all its entities used to overlay SRD reference content into every *other* package's editing view.

## Inputs / Outputs
**Inputs**
- Providers watched: [[package_provider]] `srdCorePackageBootstrapProvider` (gate — pack must be installed), `packageRepositoryProvider`.
- Reads: `packagesDao.getAll()` (id resolve); `PackageRepository.load(srdCorePackageName)` (full entity snapshot).
- Parser: `entityFromRaw` from [[entity_provider]].

**Outputs**
- `builtinPackageIdProvider` → `FutureProvider<String?>` — SRD pack's `packages.id`.
- `srdReferenceEntitiesProvider` → `FutureProvider<Map<String, Entity>>` — every SRD entity (Tier-0 lookups + Tier-1 content) parsed to [[entity]], forced `linked: true`. Cached once per DB instance.

## Dependencies & Links
- Depends on: [[package_provider]], [[entity_provider]], [[packages_dao]], [[srd_core_package_bootstrap]]
- Used by: [[entity_provider]] (`EntityNotifier` overlay), [[visible_entity_provider]], [[entity_sidebar]]
- Domain map: [[World-and-Content]]

## Key Logic / Variables
- **SRD reference overlay** (Jun 2026): `EntityNotifier(overlaySrdReference: true)` — set only in [[package_screen]] for non-SRD packages — listens to `srdReferenceEntitiesProvider` and merges its entities on top of the package-own `state`. Package-own rows win on id collision; injected ids tracked in `_referenceEntityIds` and **skipped by every write path** (`_writeEntityToCampaign`, `_syncToCampaign`, `delete`) so the overlay is shown-only, never persisted into the package. Re-applied after every `_loadFromCampaign`.
- Source of truth = the installed SRD package row, so overlay always matches what the SRD package itself shows. Import cycle with [[entity_provider]] (`entityFromRaw` ↔ `srdReferenceEntitiesProvider`) is intentional and legal in Dart.

## Notes
- All packages share the built-in D&D 5e v2 schema ([[package_repository_impl]] `_loadFromDb`), so every category chip exists in every package — that's why the overlay's entities (e.g. `condition`) always have a category to render under.
- Editing a reference card in a writable package forks a homebrew copy (standard `linked` fork-on-edit), which *does* persist — consistent with linked pack rows everywhere.
