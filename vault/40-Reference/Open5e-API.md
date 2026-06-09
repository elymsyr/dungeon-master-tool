---
type: reference
domain: content-pipeline
updated: 2026-06-09
tags: [reference]
---

# Open5e API

> [!summary] What this is
> Upstream content source. v2 fixtures are imported offline into packages by [[build_packs]]. A staging Django API (`open5e-api-staging/`) serves/transforms the data; the Flutter app never calls it at runtime — only the offline tool consumes its fixtures.

## Pipeline
Fixtures (`open5e-api-staging/data/v2/**/Document.json`) → [[sources]] discovery → [[loaders]] → [[normalize]] → [[mapper_monster|mappers]] → [[refgraph]] → [[emit]]. See [[Content-Pipeline]].

## Scale (as of 2026-06-09)
22 packages ≈ 32 MB: ~3,540 monsters, ~1,955 spells, ~2,319 magic items, 26 classes / 125 subclasses, 63 species, 58 backgrounds, 91 feats.

## Python staging tooling
`open5e-api-staging/scripts/`: `data_manipulation/` (v1→v2 conversion, enrichment), `crossreference/` (ref detection engine), smoke/benchmark tests, deploy scripts.

## Related
- MoCs: [[Content-Pipeline]] · [[Deployment-and-Ops]]
- Licensing: [[Content-Licenses]]
- Source Docs: `flutter_app/docs/open5e_import_roadmap.md`
