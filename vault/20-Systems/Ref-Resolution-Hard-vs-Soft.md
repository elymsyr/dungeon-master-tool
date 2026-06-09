---
type: system
domain: content-pipeline
updated: 2026-06-09
tags: [system]
---

# Ref Resolution — Hard vs Soft

> [!summary] What this is
> Two ways content entities reference each other. **Hard refs** (`_ref` → uuid) resolve within a package at build time. **Soft refs** (slug + name) resolve at runtime across packages, avoiding dangling refs when content is split across packs. Owned by [[Content-Pipeline]] / [[Character-System]].

## Participants
- [[entity_ref]] — `EntityRef` model + resolution helpers (slug, name, packageId).
- [[refgraph]] — build-time hard-ref minting + rewrite.
- [[character_resolver]] — runtime soft-ref lookup.

## Flow
**Hard ref (intra-package):** [[Pack-Build-Two-Pass-Refgraph]] mints uuidv5 ids (pass 1), rewrites every `_ref` placeholder → uuid (pass 2). Build **fails** on any unresolved `_ref`.

**Soft ref (cross-package):** stored as `{slug, name}` not a uuid. Resolved lazily at read time against the installed entity set (e.g. subclass→parent class, species→granted spells, background→origin feat). Missing target = silently dropped + warning, never a build failure.

## Key Constants / Invariants
- Hard refs cannot dangle (build gate). Soft refs may legitimately be absent (content from an uninstalled pack).
- Subclass parent coverage: 125/125 (28 hard + 97 soft) per chargen audit.

## Related
- MoCs: [[Content-Pipeline]], [[Character-System]], [[World-and-Content]]
- Source Docs: `flutter_app/docs/chargen_mechanics_wiring.md`
