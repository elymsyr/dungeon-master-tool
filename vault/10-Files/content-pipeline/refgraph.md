---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/refgraph.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `refgraph.dart`

> [!abstract] Primary Purpose
> Per-package entity id minting + inter-entity `_ref` resolution — the build-time engine behind the two-pass pack build. Pass 1 mints a deterministic UUIDv5 from `<package namespace>` + `"slug:name"` so ids stay byte-stable across rebuilds (installed-campaign `package_entity_id` foreign keys keep resolving). Pass 2 rewrites every `{_ref, name}` placeholder to the matching UUID. `{_lookup, name}` (Tier-0) placeholders are left intact for the app to resolve at install time. Cloned from `buildSrdCorePack`.

## Inputs / Outputs
**Inputs**
- `packageName` (used to derive the per-package namespace UUIDv5).
- Mapper-produced wire-format entity rows (`packEntity` output) added via `add(row)`.

**Outputs**
- `PackBuilder` class:
  - `Map<String, dynamic> entities` — id → wire-format entity.
  - `String add(Map row)` — registers an entity, returns its minted id; idempotent per `(slug, name)`.
  - `bool has(slug, name)` — dedup/disambiguation check used by mappers.
  - `String stableId(slug, name)` — UUIDv5 helper.
  - `List<String> resolveRefs()` — Pass 2; returns `slug:name` refs that could NOT be resolved (empty = healthy pack).

## Dependencies & Links
- Depends on: `package:uuid` only.
- Used by: [[build_packs]] (one PackBuilder per doc), all mappers ([[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]]).
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]], [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[srd_core_pack]] (the original two-pass implementation this clones)

## Key Logic / Variables
- `namespace = uuid.v5(Namespace.url.value, 'open5e-pack:$packageName')` — each package gets its OWN namespace so ids never collide across packages and a package rebuilds byte-stable.
- `_refIndex`: `slug → (name → id)`, populated by `add`. Pass 2 (`_resolve`) recursively walks each entity's `attributes`: a map with both `_ref` (slug) and `name` becomes the looked-up id, or `''` + an entry in `unresolved` if missing.
- **Hard `ref` vs soft `ref`**: a `{_ref, name}` map is resolved at build (must exist in-pack or the build fails). A `{slug, name}` map WITHOUT `_ref` (a `softRef`, see [[mapper_chargen]]) is left untouched — it resolves at character-resolve time against installed content.
- Invariant: `resolveRefs()` returning non-empty makes [[build_packs]] skip writing that pack and exit 1.

## Notes
- Stable-id rationale mirrors [[srd_core_pack]]: changing ids per session would make [[package_sync_service]] treat installed rows as orphaned and delete them.
