---
type: reference
domain: content-pipeline
updated: 2026-06-09
tags: [reference]
---

# Content Licenses

> [!summary] What this is
> Attribution + license tracking for bundled and published content. Each package carries its license in metadata; SRD-overlap packs are flagged to exclude from marketplace publish.

## Licenses in play
- **OGL 1.0a** — Kobold Press, EN Publishing, Green Ronin, SoMany Robots.
- **CC-BY-4.0** — Open5e originals, SRD 5.2.

## Where it's enforced
- Per-package `license` + attribution in [[emit|.pkg.json metadata]] and `first_party/manifest.json` ([[first_party_catalog_service]]).
- `is_srd_overlap` flag gates marketplace publish.
- Banner credits stored alongside catalog banners (R2 `catalog/banners/`).

## Related
- MoCs: [[Content-Pipeline]] · [[Backend-Infra]]
- Reference: [[SRD-5.2.1]] · [[Open5e-API]]
