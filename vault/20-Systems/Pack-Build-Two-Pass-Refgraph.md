---
type: system
domain: content-pipeline
updated: 2026-06-09
tags: [system]
---

# Pack Build — Two-Pass Refgraph

> [!summary] What this is
> How a content package is assembled with stable, collision-free ids and fully-resolved internal references. Same two-pass technique used by both the Open5e importer and the hand-authored SRD core. Owned by [[Content-Pipeline]].

## Participants
- [[refgraph]] — PackBuilder (uuidv5 namespace, two-pass resolve, integrity check, child dedup).
- [[srd_core_pack]] — SRD core builder (same pattern).
- [[emit]] — wire-format writer.
- [[normalize]] — Tier-0 enum canonicalization feeding the mappers.

## Flow
1. **Pass 1 — mint:** every entity gets a deterministic `uuidv5(namespace, key)` id. Per-package namespace prevents cross-pack collisions.
2. Child entities (creature actions, traits, features) deduped by content signature within the package.
3. **Pass 2 — rewrite:** every `_ref` placeholder (slug+name) is rewritten to the minted uuid.
4. **Integrity gate:** any unresolved `_ref` → exit non-zero (build fails). Cross-pack links use soft refs instead — see [[Ref-Resolution-Hard-vs-Soft]].
5. [[emit]] writes `<pkg>.pkg.json` + `manifest.json` + `unmapped_report.json` (one package per source document).

## Key Constants / Invariants
- Deterministic ids: same input → same uuids (reproducible builds, stable installs).
- Build fails on dangling hard ref; unmapped enum values logged, never forced into placeholders.

## Related
- MoCs: [[Content-Pipeline]]
- Source Docs: `flutter_app/docs/open5e_import_roadmap.md`
