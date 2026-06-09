---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/emit.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `emit.dart`

> [!abstract] Primary Purpose
> Package assembly + asset writer. Wraps a document's resolved entities into the `.pkg.json` payload the app-side `Open5ePackInstaller` feeds into the package repository, writes the compact (minified) asset, folds the two Open5e "Originals" docs into one package, and writes the discovery `manifest.json` + the `unmapped_report.json`.

## Inputs / Outputs
**Inputs**
- `SourceDoc doc` (metadata from [[sources]]), resolved `entities` map (from [[refgraph]]), and `sourceDataRev`.
- The `UnmappedSink.toJson()` report (from [[normalize]]).

**Outputs**
- `PackResult assemblePack(...)` — builds `{package_name, metadata, entities}` payload + per-slug `counts`.
- `writePack(result, outDir)` → `<outDir>/<package>.pkg.json` (minified JSON, ~40% smaller than pretty).
- `writeManifest(results, outDir)` → `<outDir>/manifest.json` (`{packs: [{asset, package_name, title, publisher, license, game_system, is_srd_overlap, counts}]}`) — read by the app via rootBundle.
- `writeUnmappedReport(report, outDir)` → `<outDir>/unmapped_report.json` (pretty).
- `mergeOpen5eOriginals(results, outDir, rev)` → re-merged results list.

## Dependencies & Links
- Depends on: [[sources]] (`SourceDoc`), `dart:io`, `dart:convert`.
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[Content-Licenses]]

## Key Logic / Variables
- **Payload shape is deliberately minimal**: only `package_name` + `metadata` + `entities`. The `world_schema` / `template_id` are attached at install time inside the app (it embeds the built-in v2 schema), so the asset stays compact and never drifts from the live schema.
- `metadata` keys: `title`, `publisher`, `license`, `attribution`, `game_system`, `source`, `source_doc_slug`, `pack_version` (hardcoded `'1.0.0'`), `source_data_rev`, `is_srd_overlap`, `counts`.
- `mergeOpen5eOriginals`: Open5e ships its homebrew as two docs — `open5e` (5e-2014) and `open5e-2024`. This folds `open5e-open5e-2024`'s entities into `open5e-open5e`, recomputes counts, re-writes the merged asset, deletes the secondary `.pkg.json`, and removes the secondary entry from the results list. No-op if either is absent.

## Notes
- Per the consolidation memory: the two Originals were intentionally merged into one "Open5e Originals" package; SRD 5.1/5.2 packs were dropped (built-in pack covers ~99%).
