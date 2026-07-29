---
type: file-note
domain: world-content
path: flutter_app/lib/data/schema/auto_grant_inversion.dart
layer: data
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `auto_grant_inversion.dart`

> [!abstract] Primary Purpose
> One-shot converter that moves a feat's / trait's retired `auto_granted_by` list onto the card that actually grants it. `invertAutoGrants(entities)` walks a whole entity map and returns the number of edges moved.

## Inputs / Outputs
**Inputs**
- `WorldEntityRows entities` — the wire/world map `{entityId: {type, name, attributes}}`, **not** domain `Entity` objects.

**Outputs**
- Mutates in place. Returns the edge count (`0` when there was nothing to convert).
- Per source kind: `class`/`subclass` → the `features` row at `at_level` (created if absent); `species`/`subspecies` → flat `granted_feat_refs` / `granted_trait_refs`; `background` → `origin_feat_ref` when free.

## Dependencies & Links
- Sibling of [[rule_effects_migration]], which handles the retired effect DSLs. That one is per-entity and hooks the three ingestion seams directly; this one is **cross-entity** (it reads a feat and writes a class), so it runs over whole maps instead.
- Called by: [[world_repository_impl]] `_loadFromDb` (after the synth merge, so a built-in source card is present) and [[package_payload_importer]] `install`.
- Guarded by: `test/domain/services/feature_grant_edge_test.dart`.
- System flow: [[Grant-Resolution]]

## Key Logic / Variables
- **Cheap gate first.** A map where no entity carries `auto_granted_by` returns immediately, so running it on every world load costs one key lookup per entity.
- **`_attrs` normalises** `attributes` to a mutable `Map<String, dynamic>`. A narrowly typed literal satisfies the `Map<String, dynamic>` check but rejects a `List<String>` write at runtime; normalising once removes that failure mode.
- **Nothing is dropped.** A `source_ref` naming a card that is not installed, or a background that already declares a different origin feat, is written to the feat's `mechanical_notes` in prose rather than discarded.
- `_lookupSource` accepts a bare id, `{id}`, `{_ref, name}` and `{slug, name}` — hand-authored and freshly-imported content all still occur in the wild.

## Notes
- Bundled Open5e assets carry **zero** `auto_granted_by` rows (verified 2026-07-29), so this exists for installed campaigns seeded from the pre-inversion SRD pack and for third-party/R2 packs.
- The built-in SRD pack needs no migration — it is Dart source and moved with the code; `srdCorePackVersion` was bumped to `1.0.4` so existing installs re-seed.
