---
type: moc
domain: content-pipeline
updated: 2026-06-22
tags: [moc]
---

# Content Pipeline — Map of Content

> [!summary] Scope
> Offline Dart tooling that transforms Open5e v2 fixtures → typed content packages, plus the hand-authored SRD 5.2.1 built-in pack and the catalog publish CLI. The "Calibration Data" analogue — the curated content the runtime depends on. Output is consumed by [[World-and-Content]].

## Key Files — Open5e importer (`flutter_app/tool/open5e_import/`)
- [[build_packs]] — entry point; orchestrates load → map → resolve → emit. Fails on unresolved `_ref`.
- [[sources]] — auto-discover `Document.json` source registry.
- [[loaders]] — v1/v2 fixture loader + groupBy/byPk.
- [[normalize]] — enum string → canonical Tier-0 name; unmapped sink.
- [[refgraph]] — PackBuilder: uuidv5 namespace + two-pass `_ref` resolution. See [[Pack-Build-Two-Pass-Refgraph]].
- [[emit]] — assemble wire-format `.pkg.json` + manifest + unmapped report.
- [[migrate_pack_assets]] — one-shot rewrite of bundled `.pkg.json` assets off the retired effect DSLs.
- [[mapper_monster]] · [[mapper_spell]] · [[mapper_item]] · [[mapper_chargen]] — per-type mappers.
- [[audit_packs]] · [[dupe_census]] — offline censuses over the shipped assets: *are the fields filled?* and *should this entity exist at all?*. Both back `flutter_app/docs/open5e_content_audit.md`.

## Key Files — SRD core + catalog
- [[srd_core_pack]] — hand-authored SRD 5.2.1 package builder (two-pass).
- [[srd_helpers]] — wire-format + placeholder builders (`packEntity`/`lookup`/`ref`/`withFeatureGrant`/`eqGroup`). Card mechanics are plain named fields, not builders. See [[Grant-Resolution]].
- [[srd-pack-content]] — grouped: classes/subclasses/species/spells/monsters/feats/items.
- [[builtin_schema]] — `builtin_dnd5e_v2_schema.dart` + `lookups.dart` (73 categories, Tier-0 seeds).
- [[build_catalog]] · [[publish_catalog]] — first-party catalog build + R2 publish CLI.

## Data Flow
Open5e fixtures → [[normalize]] → [[mapper_monster|mappers]] → [[refgraph]] two-pass → [[emit]] `.pkg.json`. SRD core authored directly via [[srd_helpers]]. Packages → R2 via [[publish_catalog]] → installed by [[World-and-Content]].

## Related Domains
- [[World-and-Content]] (installs packages) · [[Character-System]] (consumes effects) · [[Data-Layer]] (entity shape) · [[Backend-Infra]] (R2 catalog).

## Source Docs
- `flutter_app/docs/open5e_content_audit.md` — **the active work item.** Single entry point for fixing official-pack content: empty fields, 20.9% duplicated entities, and refs written as prose. Its §2 ("never create what you can link") outranks every fill target in it.
- `flutter_app/docs/open5e_import_roadmap.md`; chargen wiring doc removed after all phases shipped (2026-06-09).
- Memories: `open5e_import_initiative`, `open5e_pack_consolidation_jun2026`, `subspecies_category_jun2026`, `official_pkg_chargen_rules_jun2026`, `bg_equipment_chargen_jun9`.
