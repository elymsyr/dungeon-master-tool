---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/package_link_service.dart
layer: application
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `package_link_service.dart`

> [!abstract] Primary Purpose
> Reads and writes the package→package link graph. Links live in
> `packages.state_json['links']` (no table — see [[Package-Links]] for why), and
> every traversal here loads the whole `packages` row set ONCE and walks it in
> memory: the catalog is a few dozen rows whose `state_json` is small metadata
> (entities live in `package_entities`), so one `getAll()` beats N per-node
> queries.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase`, `PackageRepository`.
- Reads (Drift): `packages` via `packagesDao.getAll()`.

**Outputs**
- `parseLinks(stateJson)` / `linksFromState(map)` — static parsers; accept both
  top-level `links` and `metadata.links` (how a built pack payload declares them).
- `linksOf(name)`, `statusOf(name)` → `PackageLinkStatus(resolved, dangling)`.
- `closure(name)`, `closureOfAll(names)` → `List<Package>`, dependency order.
- `reverseLinks(name)` → packages that link this one.
- `wouldCycle(name, target)`, `addLink`, `removeLink`, `writeLinks`.
- Writes: `packages.state_json` via `PackageRepository.saveStatePatch`.

## Dependencies & Links
- Depends on: [[packages_dao]], [[package_repository_impl]], [[package_link]]
- Used by: `package_link_provider`, [[world_package_installer]],
  [[package_payload_importer]], [[link_package_dialog]], [[packages_tab]]
- Domain map: [[World-and-Content]]
- System flow: [[Package-Links]], [[Ref-Resolution-Hard-vs-Soft]]

## Key Logic / Variables
- **`_PackageIndex.resolve`** — soft ref: `byId[package_id]` first, `byName[name]`
  as fallback. The fallback is what keeps a link alive across a marketplace
  download or a package Copy (fresh local id, same title). Neither → dangling.
- **`_closureFrom`** — post-order DFS. `emitted` = de-dup + result order,
  `visiting` = cycle guard, so A→B→A terminates with each package once. Self
  links and dangling targets are `continue`d, never thrown. Root(s) come LAST,
  which is simultaneously install order and id-collision precedence.
- **`addLink`** refuses self-links, duplicates and anything that `wouldCycle`
  (i.e. the target already reaches this package). Returns `false` rather than
  throwing — the dialog turns that into the "would cycle" snackbar.
- **`removeLink`** matches the exact `PackageLink` *or* any link resolving to the
  same package, so a stale id/name pair can't defeat removal.
- `parseLinks` may return a `const []` — callers that mutate must copy
  (`addLink` does; this was a real crash).
- `writeLinks` → `saveStatePatch`, which is a **no-op for the SRD core pack**:
  SRD is the graph root and holds no links.

## Notes
- Covered by `test/application/services/package_link_service_test.dart` (18 tests:
  parse tolerance, closure order, cycles, self-links, dangling, reverse index,
  add/remove).
