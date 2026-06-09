---
type: moc
domain: content-pipeline
updated: 2026-06-09
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
- [[mapper_monster]] · [[mapper_spell]] · [[mapper_item]] · [[mapper_chargen]] — per-type mappers.

## Key Files — SRD core + catalog
- [[srd_core_pack]] — hand-authored SRD 5.2.1 package builder (two-pass).
- [[srd_helpers]] — effect-DSL builders (`effect`/`predicate`/`scalesWith`/`activation`/`autoGrantBy`). See [[Effect-DSL-Resolution]].
- [[srd-pack-content]] — grouped: classes/subclasses/species/spells/monsters/feats/items.
- [[builtin_schema]] — `builtin_dnd5e_v2_schema.dart` + `lookups.dart` (73 categories, Tier-0 seeds).
- [[build_catalog]] · [[publish_catalog]] — first-party catalog build + R2 publish CLI.

## Data Flow
Open5e fixtures → [[normalize]] → [[mapper_monster|mappers]] → [[refgraph]] two-pass → [[emit]] `.pkg.json`. SRD core authored directly via [[srd_helpers]]. Packages → R2 via [[publish_catalog]] → installed by [[World-and-Content]].

## Related Domains
- [[World-and-Content]] (installs packages) · [[Character-System]] (consumes effects) · [[Data-Layer]] (entity shape) · [[Backend-Infra]] (R2 catalog).

## Source Docs
- `flutter_app/docs/open5e_import_roadmap.md`, `chargen_mechanics_wiring.md`; `open5e_import_initiative`, `open5e_pack_consolidation_jun2026` memories.
