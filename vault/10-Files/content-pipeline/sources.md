---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/sources.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `sources.dart`

> [!abstract] Primary Purpose
> Auto-discovers the registry of Open5e source documents to package. Every `data/v2/<publisher>/<doc>/` directory that holds a `Document.json` plus at least one mappable content type becomes a `SourceDoc`. Title, publisher, license and game-system are read straight from `Document.json`, so adding a new Open5e source needs no code change. Also owns the license → human attribution-notice text.

## Inputs / Outputs
**Inputs**
- `dataRoot` path (`open5e-api-staging/data`); scans `<dataRoot>/v2/**`.
- Each doc's `Document.json` (single Django-fixture record: `pk`, `fields.name`, `fields.publisher`, `fields.licenses`, `fields.gamesystem`).

**Outputs**
- `List<SourceDoc> sourceDocs(String dataRoot)` — sorted by slug.
- `String attributionFor(String license)` — OGL 1.0a / CC-BY-4.0 / CC0 notice text.
- `SourceDoc` class: `slug`, `title`, `publisher`, `license`, `gameSystem`, `v2Dir`, `files`, `isSrdOverlap`; getters `packageName` (`open5e-<slug>`), `attribution`, `v2File(name)`, and `has*` flags per content type.

## Dependencies & Links
- Depends on: `dart:io`, `dart:convert` (no app imports).
- Used by: [[build_packs]], [[emit]] (reads `SourceDoc` metadata into the payload).
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[Content-Licenses]]

## Key Logic / Variables
- `_mappedFiles` — the 7 parent content fixtures recognized: `Creature.json`, `Spell.json`, `MagicItem.json`, `CharacterClass.json`, `Species.json`, `Background.json`, `Feat.json`. A doc with none of these is skipped.
- `_publisherNames` maps publisher slugs to display names (e.g. `kobold-press → Kobold Press`); unknown slugs are title-cased.
- `_preferredLicense`: picks the most permissive single license to attribute under — `ogl-10a` > `cc-by-40` > `cc0`. Drives `attributionFor`.
- `isSrdOverlap = publisherSlug == 'wizards-of-the-coast'` — flags SRD 5.1/5.2 docs so [[build_packs]] discovers but never writes them.
- Three attribution constants embedded in every pack's metadata: `_ogl10aAttribution`, `_ccBy4Attribution`, `_cc0Attribution`.

## Notes
- Discovery is registry-free: drop a new Open5e doc dir under `data/v2` and it ships automatically (if it carries a mappable file and a `Document.json`).
