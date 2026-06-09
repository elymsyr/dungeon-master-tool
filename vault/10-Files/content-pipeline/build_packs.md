---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/build_packs.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `build_packs.dart`

> [!abstract] Primary Purpose
> Offline CLI entrypoint that transforms the Open5e v2 API fixture dump into one `<package>.pkg.json` per source document. It auto-discovers every document, dispatches each present content type to its mapper, runs the two-pass ref-resolution in `PackBuilder`, and writes the assets + a manifest + an `unmapped_report.json`. It hard-fails (exit 1) if any inter-entity `_ref` is left unresolved, so a broken pack never ships.

## Inputs / Outputs
**Inputs**
- CLI args (`--data`, `--out`, `--rev`); defaults: data = `../open5e-api-staging/data`, out = `assets/open5e_packs`, rev = `staging-2026-05-31`.
- Reads `data/v2/<publisher>/<doc>/*.json` Django fixtures via `loadFixtures` (Creature, Spell, MagicItem, CharacterClass, Species, Background, Feat + their child files).
- Reads `data/v1/<doc>/Spell.json` to build a `spellNameLower → dnd_class` fallback index (v2 leaves `Spell.classes` empty for most 3rd-party docs).
- Document registry from `sourceDocs(dataRoot)` (see `sources`).

**Outputs**
- `<outDir>/<package>.pkg.json` per non-overlap document.
- `<outDir>/manifest.json` (pack list the app reads via rootBundle).
- `<outDir>/unmapped_report.json` (Tier-0 values that could not be normalized).
- Process exit code: 1 if any unresolved ref, 2 if data root missing.

## Dependencies & Links
- Depends on: [[sources]], [[loaders]], [[normalize]], [[refgraph]], [[emit]], [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]]
- Used by: build pipeline (`dart run`); output consumed by [[package_payload_importer]] / [[package_import_service]] and [[build_catalog]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[Content-Licenses]]

## Key Logic / Variables
- Per document: build a fresh `PackBuilder`, call `mapCreatures` / `mapSpells` / `mapMagicItems` / `mapClasses` / `mapSpecies` / `mapBackgrounds` / `mapFeats` for each present content type, then `pack.resolveRefs()` (Pass 2). Non-empty unresolved list → log + `hadError = true` + skip writing that pack.
- **SRD overlap skip**: documents whose publisher is `wizards-of-the-coast` (`doc.isSrdOverlap`) are discovered but never written — the app ships the hand-authored built-in SRD 5.2.1 pack instead (see [[srd_core_pack]]).
- **v1 class recovery**: `_v1ClassIndex` reads every `v1/<doc>/Spell.json`; `_v1DocForV2` maps each v2 doc slug to the v1 doc holding its `dnd_class` linkage (e.g. `wz→warlock`, `a5e-ag→a5e`, `deepm→dmag`); `_v1GlobalPref` is the cross-doc canonical fallback order (`wotc-srd`, `o5e`, `a5e`, `dmag`, …). Doc-scoped overlay wins over the global fallback.
- After all docs: `mergeOpen5eOriginals` folds `open5e-open5e-2024` into `open5e-open5e`; `writeManifest` + `writeUnmappedReport` (see [[emit]]).
- Constant: `pack_version` always emitted as `1.0.0` by [[emit]]; rev passed through as `source_data_rev`.

## Notes
- Per the Open5e import memory: P0-P5 shipped ~22 packs (~32MB total: 3540 monsters, 1955 spells, 2319 magic items, etc.). The 32MB bundle is flagged (R6) as not-for-production.
- Honest source limits documented in mappers: leveled class features, subclass `granted_at_level`, feat effect/ASI DSL beyond conservative parses.
