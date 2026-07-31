---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/build_packs.dart
layer: tool
language: dart
status: stable
updated: 2026-07-31
tags: [file]
---

# `build_packs.dart`

> [!abstract] Primary Purpose
> Offline CLI entrypoint that transforms the Open5e v2 API fixture dump into one `<package>.pkg.json` per source document. It auto-discovers every document, dispatches each present content type to its mapper, runs the two-pass ref-resolution in `PackBuilder`, and writes the assets + a manifest + an `unmapped_report.json`. It hard-fails (exit 1) if any inter-entity `_ref` is left unresolved, so a broken pack never ships.

## Inputs / Outputs
**Inputs**
- CLI args (`--data`, `--out`, `--rev`); defaults: data = `../open5e-api-staging/data`, out = `assets/open5e_packs`, rev = `staging-2026-05-31`.
- Reads `data/v2/<publisher>/<doc>/*.json` Django fixtures via `loadFixtures` (Creature, Spell, MagicItem, CharacterClass, Species, Background, Feat + their child files), plus the Tier-0 vocabulary files across every document ([[vocab]]).
- Reads `data/v1/<doc>/Spell.json` to build a `spellNameLower → dnd_class` fallback index (v2 leaves `Spell.classes` empty for most 3rd-party docs).
- Reads `data/v1/<doc>/Monster.json` to build the B8 action index (`_v1ActionIndex`), recovering action buckets upstream's v2 conversion never wrote.
- Reads `data/v1/<doc>/Race.json` to build the B3 species index (`_v1SpeciesIndex`), recovering a species v2 converted with no traits at all.
- Document registry from `sourceDocs(dataRoot)` (see `sources`).

**Outputs**
- `<outDir>/<package>.pkg.json` per non-overlap document.
- `<outDir>/manifest.json` (pack list the app reads via rootBundle).
- `<outDir>/unmapped_report.json` (Tier-0 values that could not be normalized).
- Process exit code: 1 if any unresolved ref, 2 if data root missing.

## Dependencies & Links
- Depends on: [[sources]], [[loaders]], [[normalize]], [[vocab]], [[refgraph]], [[emit]], [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]]
- Used by: build pipeline (`dart run`); output consumed by [[package_payload_importer]] / [[package_import_service]] and [[build_catalog]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[Content-Licenses]]

## Key Logic / Variables
- Per document: build a fresh `PackBuilder`, call `mapCreatures` / `mapSpells` / `mapMagicItems` / `mapClasses` / `mapSpecies` / `mapBackgrounds` / `mapFeats` for each present content type, then `pack.resolveRefs()` (Pass 2). Non-empty unresolved list → log + `hadError = true` + skip writing that pack.
- **SRD overlap skip**: documents whose publisher is `wizards-of-the-coast` (`doc.isSrdOverlap`) are discovered but never written — the app ships the hand-authored built-in SRD 5.2.1 pack instead (see [[srd_core_pack]]).
- **v1 class recovery**: `_v1ClassIndex` reads every `v1/<doc>/Spell.json`; `_v1DocForV2` maps each v2 doc slug to the v1 doc holding its `dnd_class` linkage (e.g. `wz→warlock`, `a5e-ag→a5e`, `deepm→dmag`); `_v1GlobalPref` is the cross-doc canonical fallback order (`wotc-srd`, `o5e`, `a5e`, `dmag`, …). Doc-scoped overlay wins over the global fallback.
- **v1 action recovery** (audit **B8**, 2026-07-31): `_v1ActionIndex` reads every `v1/<doc>/Monster.json` into `v1doc → lowercased monster name → action_type bucket → [{name, desc}]`, decoding the `actions_json` / `bonus_actions_json` / `reactions_json` / `legendary_actions_json` columns (each a JSON *string*). `_v1DocForCreatures` maps the 8 v2 document slugs verified on the snapshot by monster-count **and** name parity (`a5e-mm→menagerie`, `bfrd→blackflag`, `ccdx→cc`, `tdcs→taldorei`, `tob`, `tob2`, `tob-2023`, `tob3`); the SRD documents are deliberately absent (skipped before this point, and `wotc-srd` is not row-parity with `srd-2014`). [[mapper_monster]] consumes it and fills **only** a bucket v2 left entirely empty — see that note for why the looser rule was rejected.
  - ⚠️ **This is the second undetectable `data/v1` dependency, and the bigger one.** Without `v1/tob3/Monster.json` the build is clean and green while 396 statblocks ship with an empty Actions block — exactly how the defect survived. Unlike the spell tags it *is* visible to [[audit_packs]] (`monster.action_refs` 86% vs 99.8%), so check that number after any rebuild.
- **v1 species recovery** (audit **B3**, 2026-07-31): `_v1SpeciesIndex` reads every `v1/<doc>/Race.json` into `v1doc → lowercased species name → [{name, desc}]`. v1 keeps a race's traits as one markdown blob rather than rows, so `_v1TraitRows` splits it on its `***Name.***` headers; the single-value prose columns (`size`, `speed_desc`, `asi_desc`, `languages`, `age`, `alignment`, `vision`) map to the v2 trait name they stand in for. `_v1DocForSpecies` lists the only two non-SRD documents shipping a `Species.json` (`toh→toh`, `open5e→o5e`). [[mapper_chargen]] fills **only** a species v2 gave zero trait rows — exactly one on the snapshot, `toh`'s **Shade**.
  - ⚠️ **This is the third undetectable `data/v1` dependency.** Three independent v2 conversion gaps — spell classes, ToB3's actions, Shade's traits — now rest on a directory that is `.gitignore`d, absent by default, and silently skipped when missing.
  - 🚫 **v1's structured `size_raw` and `speed_json` columns are deliberately NOT read.** They look exactly like the data B8 recovered and they are default-filled, not sourced: `size_raw` is `Medium` for all 11 `toh` races including Derro and Erina, whose own prose says **Small**, and `speed_json` says 25 for Drow against its own `speed_desc`'s 30. Reading them would have overwritten 7 correct sizes to buy 4 wrong ones. The same v1 file is authoritative for one column and junk for the next, so "recover it from v1" is a per-column decision, never a policy.
  - ⚠️ **`data/v1` is a hard dependency of character creation.** [[mapper_spell]] writes the recovered class as a bare-name **`tags`** entry (`spell.class_refs` is 0%), and the chargen spell pickers match on exactly that tag — so a snapshot cloned without `v1`, or a new document missing from `_v1DocForV2`, produces spells with no class linkage and **no error**: refs still resolve, both audit tools stay green (`tags` is not a declared field), and the wizard silently offers an empty spell list. Check `data/v1` in the snapshot and diff spell-tag coverage after any rebuild.
- **Discovery is silent about what it skips.** `sourceDocs` requires a `Document.json` plus at least one of the seven `_mappedFiles`; a document whose content lives only in unmapped files (`Item.json`, `Rule.json`, …) is dropped with no log line, and the SRD-overlap skip is **publisher-wide** (`publisher == 'wizards-of-the-coast'`), not just `srd-2014`/`srd-2024`.
- **`--rev` is a label, not a pin.** Default `staging-2026-05-31` is a hardcoded string while upstream `staging` moves, so two runs months apart are not comparable unless the caller passes the actual clone SHA. **The pinned snapshot is `d4276c586d79f2a27bf2b814aed151cf57605283`** (upstream commit date 2026-06-13, cloned 2026-07-30) — pass that as `--rev`, and see the audit doc's §4 A0 table.
- **`_parseArgs` takes `--k v` only.** `--out=/scratch` is silently ignored and the build writes into `assets/open5e_packs`; unknown flags are silently accepted; the loop bound `i < args.length - 1` means a flag in final position with no value is dropped. Every rebuild invocation should be checked before running, and pointed at a scratch dir with the space form. Compare against a rebuild with [[diff_packs]].
- **What it deliberately does not load** (decided 2026-07-30 against the pinned snapshot; audit §4 A1 has the measurements). Five upstream files exist **only** in `wizards-of-the-coast/srd-2014` / `srd-2024`, which the publisher-wide SRD skip never writes, so they cannot fill a field in any shipped pack no matter what they hold: `Item.json`, `Weapon.json`, `Armor.json`, `WeaponProperty*.json`, `Rule.json`/`RuleSet.json`, `CrossReference.json`. Consequences worth knowing before planning work:
  - **`CrossReference.json` is not a ref source.** 48 rows total, and the targets are `rule`/`ruleset`/`itemset` — content types we do not model. They are website prose anchors (`anchor: "Grappling"`). Name-matching is the *only* route for cross-package refs; there is no better upstream source waiting.
  - **No shipped document carries a mundane-equipment fixture.** The 159 synthesised `adventuring-gear` stubs cannot be replaced by an import, only by linking built-in gear.
  - **`SpellCastingOption.json` is redundant.** Present in 8 shipped docs, but the number of spells with casting-option payload and no `Spell.higher_level` prose is **0 in every document** — and [[mapper_spell]] already appends that prose.
  - **`ItemCategory.json` is an item taxonomy** (Ring, Rod, Wand, Wondrous Item), not the anatomical `body-slot` vocabulary. It cannot fill `magic-item.body_slot_ref`.
  - `ClassFeatureItem.json` is loaded alongside `ClassFeature.json` and passed to `mapClasses` as `featureItems` (audit **B1**, 2026-07-30) — 743 rows in 6 shipped docs, `level` 100% non-null; it yields 572 level rows and fixes 100 of the 101 subclasses that granted nothing. See [[mapper_chargen]] for the granted-feature vs class-table-column split.
  - The **Tier-0 vocabulary files** are loaded since audit **B9** (2026-07-30) — see [[vocab]]. `Vocabulary.load(dataRoot)` is called once in `main` and walks every `data/v2/<publisher>/<doc>/`, and `norm.tier0Seeder` is **rebound per pack** inside the document loop so the `{_ref}` the normalizer hands back always points inside the pack being built. Note the shape — `core` is a document `sourceDocs` correctly refuses to turn into a pack, so this is a **vocabulary read, not a new `_mappedFiles` entry**; do not "fix" the discovery skip. Result: `unmapped_report.json` 144 → 70 values, `monster.size_ref` 100%. The 70 remaining `alignment` values are upstream free text with no fixture behind them (audit **B10**).
- After all docs: `mergeOpen5eOriginals` folds `open5e-open5e-2024` into `open5e-open5e`; `writeManifest` + `writeUnmappedReport` (see [[emit]]).
- Constant: `pack_version` always emitted as `1.0.0` by [[emit]]; rev passed through as `source_data_rev`.

## Notes
- Per the Open5e import memory: P0-P5 shipped ~22 packs (~32MB total: 3540 monsters, 1955 spells, 2319 magic items, etc.). The 32MB bundle is flagged (R6) as not-for-production.
- Honest source limits documented in mappers: ~~leveled class features, subclass `granted_at_level`~~ (**fixed by B1** — the level lived in `ClassFeatureItem`, which this file simply never opened), feat effect/ASI DSL beyond conservative parses.
