---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/normalize.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `normalize.dart`

> [!abstract] Primary Purpose
> Maps raw Open5e enum strings ("neutral good", "humanoid", "fire") to the exact canonical Tier-0 lookup names the app will match at import time. The single source of truth is the built-in v2 schema's Tier-0 seed rows (`buildTier0Lookups`) — every seeded lookup name is indexed case-insensitively. Values that don't map are NOT forced into a placeholder; they are recorded in an `UnmappedSink` and the caller decides to drop or pass through.

## Inputs / Outputs
**Inputs**
- `buildTier0Lookups(...)` from `lib/.../builtin/lookups.dart` (see [[builtin_schema]]) — builds the canonical name index at construction.

**Outputs**
- `Normalizer` class:
  - `canonical(slug, raw)` → canonical name or null (tries raw + title-cased).
  - `lookupRef(slug, raw, {context})` → `{_lookup, name}` placeholder or null (records a miss in the sink).
  - `lookupRefList(slug, raws, {context})` → list of placeholders, skipping unknowns.
  - `namesFor(slug)` → all canonical names seeded for a slug (used by mappers that scan free text for any canonical value).
- `UnmappedSink unmapped` — accumulates `<slug> → {value(+context) → count}`; `toJson()` is written to `unmapped_report.json` by [[emit]].
- `String titleCase(String)` — "neutral good" → "Neutral Good", "deep_speech" → "Deep Speech".

## Dependencies & Links
- Depends on: [[builtin_schema]] (`buildTier0Lookups`, `lookups.dart`), [[srd_helpers]] (`lookup`).
- Used by: [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]], [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Index shape: `slug → (lowercased name → canonical name)`. Built once in the factory by walking every Tier-0 `seedRows` name.
- `canonical` lookup falls back to a title-cased variant of the raw string before giving up.
- `lookupRef` returns the `{_lookup: slug, name}` placeholder (via [[srd_helpers]] `lookup`), which the app resolves at install time against the world's Tier-0 row UUIDs. Misses go to the sink instead of producing a fake placeholder.
- `UnmappedSink.toJson` sorts each slug's values by descending count.

## Notes
- The sink is why `unmapped_report.json` lists every non-SRD enum value with a frequency — used to triage which mapper aliases to add.
