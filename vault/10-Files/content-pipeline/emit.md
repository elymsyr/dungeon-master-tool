---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/emit.dart
layer: tool
language: dart
status: stable
updated: 2026-08-20
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
- `metadata` keys: `title`, `publisher`, `license`, `attribution`, `game_system`, `source`, `source_doc_slug`, `pack_version` (the `packVersion` const, **`1.1.0`** since 2026-08-13), `source_data_rev`, `is_srd_overlap`, `counts`.
- **`mergeOpen5eOriginals` stamps the second document's identity (audit R6, 2026-08-20).** Open5e Originals ships as two documents (`open5e` 5e-2014, `open5e-2024` 5e-2024) folded into one pack. The fold re-assembles with the **primary** doc, so the pack label is `5e-2014`; when the two `gameSystem`s differ, each secondary entity's `source` gains the system (`Open5e Originals` → `Open5e Originals (5e-2024)`) so the card says which ruleset wrote it (finding F-open5e-01). Conditional — same system, no change.
- ⚠️ **There is no `links` key and no way to emit one.** `assemblePack` builds that map literally, so the pack→pack declarations [[Package-Links]] needs (`metadata.links`, carrying **both** the catalog `slug` and the local `name` — see [[package_link_service]] / [[build_catalog]]) have no producer. The audit's phase **L2** lands *here*, not in a mapper, despite the cause-code table pointing at `mappers/*.dart`.
- ⚠️ **`pack_version` is a release step, not a placeholder — bump `packVersion` when content changes.** [[build_catalog]] turns it into the immutable `r2_path` `package/<slug>@<version>.json.gz`, and [[publish_catalog]] **skips** an object that already exists unless `--force`, so a rebuild published without a bump reaches nobody. Audit phase **D1** (2026-08-13) replaced the hardcoded `'1.0.0'` with a hand-bumped semver const, now `1.1.0`: a content hash was rejected because `r2_path` immutability only needs the version to move per release, and semver ordering is what makes the installed-vs-catalog upgrade check (**D2**) a plain comparison. **D2 is still open** — [[first_party_catalog_provider]] never diffs the stored `catalog_version`, so a user on `@1.0.0` has no upgrade trigger. In debug this is masked by [[bundled_packs_bootstrap]]'s content-hash reinstall (which stays necessary: two rebuilds inside one release share a version).
- `mergeOpen5eOriginals`: Open5e ships its homebrew as two docs — `open5e` (5e-2014) and `open5e-2024`. This folds `open5e-open5e-2024`'s entities into `open5e-open5e`, recomputes counts, re-writes the merged asset, deletes the secondary `.pkg.json`, and removes the secondary entry from the results list. No-op if either is absent.

## Notes
- Per the consolidation memory: the two Originals were intentionally merged into one "Open5e Originals" package; SRD 5.1/5.2 packs were dropped (built-in pack covers ~99%).
