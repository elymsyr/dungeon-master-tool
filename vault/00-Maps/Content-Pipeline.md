---
type: moc
domain: content-pipeline
updated: 2026-08-10
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
- [[audit_packs]] · [[dupe_census]] · [[diff_packs]] — offline censuses over the shipped assets: *are the fields filled?*, *should this entity exist at all?* and *what did my rebuild change?*. All three back `flutter_app/docs/open5e_content_audit.md`. `audit_packs --builtin` (T2) runs the same census over the built-in pack — the link target — instead of the assets.
- [[gate_packs]] — the **relational** gate (T3): seven per-entity rules the field censuses structurally cannot express (actionless monster, orphaned child row, dangling ref, qualifier-strip mis-resolution, empty equipment option, skewed action buckets). No snapshot needed, exits non-zero on any violation, and [[build_packs]] runs it over what it just wrote.
- [[verify_packs]] — the correctness gate beside those three: *is the shipped value the one the fixture column holds?* Needs the pinned snapshot, exits non-zero on a disagreement, and is the only tool that can see a **fabricated** value (a mapper default with no source behind it).

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
  `Void Speech`, filed on **L2**. **B8 done 2026-07-31**: `open5e-tob3`'s 396
  actionless monsters were not a bucketing bug — upstream's v2 conversion dropped
  that document's whole `ACTION` column (2 rows for 397 creatures) while the other
  three buckets match `v1/tob3/Monster.json` row for row, so [[build_packs]] now
  indexes v1's statblock columns and [[mapper_monster]] backfills **only** buckets
  v2 left empty. `monster.action_refs` 86% → 99.8%; corpus actionless 400 → 5, all
  genuinely actionless. **B3 done 2026-07-31**: filed as "match `SpeciesTrait.type`
  and `BackgroundBenefit.type` instead of names", and three of its five clauses
  did not survive the snapshot — `BackgroundBenefit.type` was already the key, and
  `SpeciesTrait.type` is **null on 100% of the rows we ship** (only `srd-2024`
  fills it, and the SRD skip never builds it). What was real: `tool_proficiency`
  → `granted_tool_refs` **0% → 35%** + `granted_tool_variant_group` 0% → 22%, plus
  a third v2 conversion gap — `toh`'s **Shade** ships zero trait rows and is
  recovered from `v1/toh/Race.json`. `size_ref` at 100% is unreachable: four
  species say the subrace decides and the subraces never say, and v1's
  `size_raw`/`speed_json` are default-filled traps. All four rebuilds stay
  scratch-only, so the shipped assets carry none of these fixes yet (promotion is
  Stage D). **B2 done 2026-07-31**: the four fields it was filed to fill
  (`cantrips_known_by_level`, `prepared_spells_by_level`, `spell_slots_by_level`,
  `extra_attack_count_by_level`) need `CORE_TRAITS_TABLE`/`SPELL_SLOTS`, which
  exist **only in the two skipped WotC documents** — but the 171 `column_value`
  rows B1 excluded from `features` had no other home and were being dropped
  outright while their empty heading / `[Column data]` placeholder shipped as
  prose. Now rendered as a `### Class Table` markdown table. **Neither census
  tool can see it** (`description` was already 100% "filled"), which is exactly
  what **T1** exists to catch. **B4 done 2026-07-31** — and the first phase
  whose filed premise *survived* the snapshot, because it was measured first:
  [[mapper_spell]] now reads `shape_type`/`shape_size` → `area_shape_ref` +
  `area_size_ft` (**0% → 7%**, all five upstream shapes already built-in
  `area-shape` rows, size unconditionally feet) and `reaction_condition` →
  `reaction_trigger` (**0% → 3%**, with upstream's dangling "which you take …"
  lead-in stripped since the app's field stands alone). Both are at their
  ceiling — that is all the source has. **T1 done 2026-07-31**: [[verify_packs]]
  grades every shipped value against its fixture column — 0 disagreements, but
  **3,663 `unsourced`**, the fabrication class no census can express. **B11 done
  2026-08-10**: the one live defect in that list — [[mapper_monster]] wrote
  `hit_dice ?? '1d4'` and `open5e-bfrd` is null throughout — is fixed by
  **omitting** the field, 360 removals confined to that pack. **T2 done
  2026-08-10**: [[audit_packs]] `--builtin` measures the built-in pack for the
  first time (2,719 entities, 59 categories) and finds `skill.ability_ref`
  required and **0% filled** behind an `_ability_name_` placeholder nothing
  resolves — the wizard's skill ability-mod chip has never rendered — plus the
  fact that no spell-slot table ships anywhere. Filed T2-1/2/3; the built-in pack
  is measured, never edited, by this audit. **T3 done 2026-08-10**: [[gate_packs]]
  gates the relations a field census cannot express — 198 violations, all already
  filed (197 tob3's, waiting on the B8 rebuild; 1 the `"Spare The Dying"` ref L3
  owns), and nothing orphaned, dangling or unresolvable. [[build_packs]] runs it
  over its own output, so §3.5 cannot repeat silently. **Stage T is closed**;
  next is the rebuild and **D1**.
- `flutter_app/docs/open5e_import_roadmap.md`; chargen wiring doc removed after all phases shipped (2026-06-09).
- Memories: `open5e_import_initiative`, `open5e_pack_consolidation_jun2026`, `subspecies_category_jun2026`, `official_pkg_chargen_rules_jun2026`, `bg_equipment_chargen_jun9`.
