---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/package_source_entities.dart
layer: application
language: dart
status: stable
updated: 2026-08-14
tags: [file]
---

# `package_source_entities.dart`

> [!abstract] Primary Purpose
> Turns *installed content packages* into the same `Map<String, Entity>` shape the wizard, editor, card and resolver already consume, and defines **how those maps layer over the built-in SRD map**. Every path that dereferences a ref for a character with `source_packages` goes through here, so this file — not the resolver — is where "which card does this name land on?" is decided.

## Inputs / Outputs
**Inputs**
- Providers watched: `bundledPacksBootstrapProvider` (reconciles the bundled Open5e packs before any read), `appDatabaseProvider`, `builtinSrdEntitiesProvider`, `packageLinkClosureOfAllProvider`.
- Reads: `packagesDao.getByName` / `.getEntities` (row-level, never the full blob `load()`).
- Triggers: none — pull-based, cached per package name via `ref.keepAlive()`.

**Outputs**
- `packageEntitiesProvider` (FutureProvider.family by package name) — one package's entities, `_lookup` placeholders already resolved against the built-in Tier-0 ids.
- `sourcePackagesOf(Character)`, `expandedPackageNames(watch, names)`, `layerCharacterPackages(...)`, `mergeBuiltinWithPackages(...)`, `layerPackagesOverBuiltin(builtin, packages)`.

## Dependencies & Links
- Depends on: [[packages_dao]], [[package_import_service]] (`resolveLookupPlaceholder`), [[builtin_package_provider]], [[package_link_service]], [[bundled_packs_bootstrap]].
- Used by: `wizardEntitiesProvider` (worldless branch), `character_provider`, `character_stat_chips`, `character_editor_screen` — and, transitively, [[entity_ref]] / [[character_resolver]], which read whatever map these produce.
- Domain map: [[World-and-Content]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Package-Links]]

## Key Logic / Variables
- `packageEntitiesProvider` resolves `{_lookup, name}` envelopes against a `(slug → name → id)` index built from the **built-in** map, so a package row ends up pointing at the same Tier-0 rows everything else uses.
- `expandedPackageNames` widens a picked set to its transitive link closure, **dependency-ordered — links first, the package the user picked last**. On an unresolved closure it returns the caller's list unchanged rather than dropping every source.
- **`layerPackagesOverBuiltin` is the single ordering rule** (audit **L1**, 2026-08-14): packages first, built-in filled in behind with `putIfAbsent`; within the closure, **last wins** (iterate `packages.reversed`, insert with `putIfAbsent`). `mergeBuiltinWithPackages` delegates to it, and `layerCharacterPackages` mirrors it with `CombinedMapView([...maps.reversed, base])`.
- **Why order is the whole story.** Ids are uuidv5 of `(pack, slug, name)`, so an SRD card and an A5E restat of the same spell **never collide by id** — both sit in the merged map, and `findEntityIdByName` ([[entity_ref]]) picks by *insertion order*, first writer wins. Merge order is therefore a content decision disguised as a data-structure detail.
- Returns `base`/`builtin` **by identity** when there is nothing to layer. Downstream caches (`categoryIndexProvider`, the `Expando` name index in [[entity_ref]]) key on map identity, so gratuitously copying the map invalidates a ~7 K-entry index.

## Notes
- ✅ **Three paths, three answers — fixed 2026-08-14 (audit L1).** `mergeBuiltinWithPackages` built `{...builtin, ...packages}` → the **built-in** card won all 1,643 section-A name collisions; `layerCharacterPackages` put packages first → the **package** won, but the *linked* pack beat the picked one, contradicting its own doc comment; `wizardEntitiesProvider`'s world branch suppresses the built-in row by `(slug, lowercased name)` → the **campaign** won. A worldless character with A5E ticked got the SRD card in the wizard and the A5E card on the sheet. All three now agree: the package the user picked wins.
- The rule is only defensible because L1 measured the collisions and dropped **none** of them — A5E restats, separate Tome of Beasts editions, monster-owned children and two additive singletons (`docs/open5e_content_audit.md` §2.5). Since the shadowing is permanent, it has to point at the pack the user asked for.
- Test: `test/application/services/package_shadowing_test.dart` — shadow direction, closure order, empty/unloaded, and a built-in-only name still resolving.
