---
type: moc
domain: content-pipeline
updated: 2026-07-30
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
- [[vocab]] — Open5e's own Tier-0 vocabulary fixtures as a second canon behind [[normalize]]; seeds genuinely-new third-party vocabulary as pack-local Tier-0 rows.
- [[refgraph]] — PackBuilder: uuidv5 namespace + two-pass `_ref` resolution. See [[Pack-Build-Two-Pass-Refgraph]].
- [[emit]] — assemble wire-format `.pkg.json` + manifest + unmapped report.
- [[migrate_pack_assets]] — one-shot rewrite of bundled `.pkg.json` assets off the retired effect DSLs.
- [[mapper_monster]] · [[mapper_spell]] · [[mapper_item]] · [[mapper_chargen]] — per-type mappers.
- [[audit_packs]] · [[dupe_census]] · [[diff_packs]] — offline censuses over the shipped assets: *are the fields filled?*, *should this entity exist at all?* and *what did my rebuild change?*. All three back `flutter_app/docs/open5e_content_audit.md`.

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
- `flutter_app/docs/open5e_content_audit.md` — **the active work item.** Single entry point for fixing official-pack content: empty fields, a 20.9% name-collision surface, and refs written as prose. Its §2 ("never create what you can link") outranks every fill target in it. **Gap-analysed 2026-07-30** and restructured around four outcomes — correct packs, tested mechanics, real linking, working character creation — plus delivery: §0.1 traceability table, §2.3.1 (wizard readers that cannot see a softRef), §2.5 (name collision ≠ duplicate: measured 90.3% textual divergence, monster-owned children excluded), §3.4 (what the tools do **not** prove), and new roadmap stages **L0** (census fidelity), **U** (wizard), **M** (mechanics land), **T** (`verify_packs` + built-in audit), **D** (version & publish). **Stage A closed
  2026-07-30**: snapshot pinned at `d4276c58` and the shipped assets proven
  reproducible (A0), then every upstream fixture file decided (A1) — `ClassFeatureItem`
  and the Tier-0 vocabulary files load, six files do not, and two of the matrix's own
  claims were reversed (`CrossReference` is prose anchors, not refs; `ItemCategory` is
  not the `body-slot` vocabulary). New phases **B9** (vocabulary → kills 74 of 144
  unmapped values) and **B10** (free-text alignment). **L0 done 2026-07-30**:
  [[dupe_census]] separates identity (A/B) from resolution (C), splits every
  collision three ways by text, and buckets monster-owned children — actionable
  redundancy is **1,178 (5.7%)**, not 20.9%; matching A/B like the resolver would
  have called 3,501 qualified statblock rows duplicates (refiled on **T3**), and
  section C's "0 dangling" was really **1** (`"Spare The Dying"`, filed on **L3**).
  **B1 done 2026-07-30**: `ClassFeatureItem.json` is loaded and
  [[mapper_chargen]]'s `_levelFeatures` turns it into the `classFeatures` level
  table + `subclass.granted_at_level` — 572 rows, 100 of 101 subclasses, exactly
  what the source supports; the 20-row `column_value` class-table columns are
  deliberately left to **B2**. **B9 done 2026-07-30**: [[vocab]] reads the Tier-0
  vocabulary fixtures across every document as a second canon — content fixtures
  reference Tier-0 rows by *pk*, so this is what turns `thieves-cant` into the
  built-in `Thieves' Cant` and what proves `void-speech`/`titanic` are real, to be
  seeded as pack-local Tier-0 rows (§2: never in the built-in schema).
  `unmapped_report.json` 144 → 70 (only free-text `alignment` left, = **B10**),
  `monster.size_ref` 100%; the cost is 6 packs each shipping a one-row
  `Void Speech`, filed on **L2**. Both rebuilds stay scratch-only, so the shipped
  assets do not carry either fix yet (promotion is Stage D). Next: **B8** — the
  only shipped *defect* left, 396 of `open5e-tob3`'s 397 monsters with no
  Actions block.
- `flutter_app/docs/open5e_import_roadmap.md`; chargen wiring doc removed after all phases shipped (2026-06-09).
- Memories: `open5e_import_initiative`, `open5e_pack_consolidation_jun2026`, `subspecies_category_jun2026`, `official_pkg_chargen_rules_jun2026`, `bg_equipment_chargen_jun9`.
