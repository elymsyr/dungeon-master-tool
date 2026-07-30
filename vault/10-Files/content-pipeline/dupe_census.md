---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/dupe_census.dart
layer: tool
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `dupe_census.dart`

> [!abstract] Primary Purpose
> Duplication + cross-package-ref census over the bundled Open5e packs. Sibling of [[audit_packs]]: that tool asks *"are the fields filled?"*, this one asks *"should this entity exist at all?"*. Since [[Package-Links]] shipped (2026-07-29) a package can **link** another instead of copying it, and the built-in SRD pack is in scope everywhere implicitly — so a pack shipping its own "Acolyte" or "Amphibious" is shadowing content, not adding it. This measures how much of that there is. Backs `flutter_app/docs/open5e_content_audit.md` §3.2.

## Inputs / Outputs
**Inputs**
- `dart run tool/open5e_import/bin/dupe_census.dart [--packs <dir>] [--only <slugs>] [--markdown] [--list <slug>]`
- Reads the shipped assets plus the built-in pack (`generateBuiltinDnd5eV2Schema().seedRows` + `buildSrdCorePack()`, both pure Dart — no DB, no Flutter binding, **no source snapshot**).

**Outputs** — three censuses:
- **A** bundled entity ⟷ built-in pack (drop candidates: nothing to link, the built-in row is already in scope)
- **B** bundled entity ⟷ another bundled pack (one owner + `metadata.links` candidates)
- **C** cross-pack `softRef` targets, bucketed built-in / other pack / own pack / **nothing installed**
- `--list <slug>` prints the colliding names in one category so drop-vs-keep can be decided row by row.

## Dependencies & Links
- Depends on: [[builtin_schema]], [[srd_core_pack]] (the in-scope set), [[emit]] (the asset shape).
- Related: [[audit_packs]], [[Package-Links]], [[Ref-Resolution-Hard-vs-Soft]], [[build_catalog]] (`requires` comes from the `metadata.links` this census argues for).
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **Join key is `(category slug, lowercased name)`** — the same key `findEntityIdByName` resolves a softRef with, so every reported collision is one the resolver really faces. The name is lowercased because the importer's title-casing otherwise understates the overlap.
- **A name collision is not proof of identical content.** Level Up: Advanced 5e (`game_system: a5e`) deliberately restats SRD material — 313 of *Adventurer's Guide*'s 371 spells collide by name and most should be **kept**. `game_system` is display-only metadata, so it cannot carry the decision automatically; the tool reports candidates, policy is per document.
- **`_redundantTotal`** is the A ∪ B union, not their sum (a trait can be in the built-in pack *and* in six packs): a name the built-in ships makes every bundled copy redundant, a name only packs ship makes all but one redundant.
- **`_walkSoftRefs`** recurses the whole `attributes` tree for the `{slug, name}` envelope and deliberately skips `{_ref, name}` (in-pack hard ref, build-gated) and `{_lookup, name}` (Tier-0, resolved at import).

## Notes
- **Run 2026-07-30:** 19 packs / 20,712 entities vs 2,717 built-in rows → **4,331 redundant (20.9%)**; A = 1,660, B = 3,393. Worst: `trait` 452+1,098, `creature-action` 448+1,678, `monster` 409+588. Section C = 135 softRefs total (106 → built-in, 29 → own pack, **0 → another bundled pack**, 0 dangling).
- Section C doubles as the guard rail for the audit's fill phases: it must **grow** as `*_ref` fields get filled, and its "nothing installed" row must stay at 0.
