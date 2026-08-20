---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/normalize.dart
layer: tool
language: dart
status: stable
updated: 2026-08-20
tags: [file]
---

# `normalize.dart`

> [!abstract] Primary Purpose
> Maps raw Open5e enum strings ("neutral good", "humanoid", "fire") to the exact canonical Tier-0 lookup names the app will match at import time. The single source of truth is the built-in v2 schema's Tier-0 seed rows (`buildTier0Lookups`) — every seeded lookup name is indexed case-insensitively. Values that don't map are NOT forced into a placeholder; they are recorded in an `UnmappedSink` and the caller decides to drop or pass through. Since audit **B9** (2026-07-30) a **second canon sits behind the first** — Open5e's own Tier-0 vocabulary fixtures ([[vocab]]) — consulted only when the built-in index misses.

## Inputs / Outputs
**Inputs**
- `buildTier0Lookups(...)` from `lib/.../builtin/lookups.dart` (see [[builtin_schema]]) — builds the canonical name index at construction.
- `Normalizer.vocab` ([[vocab]], settable, defaults empty) — the upstream vocabulary. `Normalizer.tier0Seeder` (settable, defaults null) — mints a Tier-0 row in the pack currently being built; [[build_packs]] rebinds it per pack.

**Outputs**
- `Normalizer` class:
  - `canonical(slug, raw)` → canonical name or null (tries raw + title-cased).
  - `lookupRef(slug, raw, {context})` → `{_lookup, name}` placeholder or null (records a miss in the sink).
  - `lookupRefList(slug, raws, {context})` → list of placeholders, skipping unknowns.
  - `namesFor(slug)` → all canonical names seeded for a slug (used by mappers that scan free text for any canonical value).
- `UnmappedSink unmapped` — accumulates `<slug> → {value(+context) → count}`; `toJson()` is written to `unmapped_report.json` by [[emit]].
- `String titleCase(String)` — "neutral good" → "Neutral Good", "deep_speech" → "Deep Speech". Capitalises **every** word.
- `String canonicalCardName(String)` — the built-in spelling of a *card name* when a measured alias exists, else the trimmed name. Added 2026-08-20 for audit **R6** (F-pass0-07): 17 upstream spellings across 19 cards differ from a built-in card's name by spacing, punctuation or word-splitting only (`Eye bite` → `Eyebite`, `Battle Axe` → `Battleaxe`, `Devil’s Sight` → `Devil's Sight`). A **table, not a fold**: §2.3 keeps `findEntityIdByName` strict on purpose. Applied by [[refgraph]]'s `PackBuilder.add` (the one choke point every card passes) and by [[verify_packs]]'s `_matchKey`, so the fixture row is still found under the renamed card.
- `String titleCaseName(String)` — title case for a *proper name*: interior minor words ("the", "of", "from", "with", …) stay lowercase, first and last always capitalised. "spare the dying" → "Spare the Dying". Added 2026-08-13 for audit **L3**: soft refs are resolved case-sensitively, and `titleCase` on a prose-derived spell name emitted `"Spare The Dying"`, the corpus's one dangling ref. Used by [[mapper_chargen]]'s `_parseSpellGrants`; the other 15 `titleCase` call sites are vocabulary values, not names, and are unchanged.

## Dependencies & Links
- Depends on: [[builtin_schema]] (`buildTier0Lookups`, `lookups.dart`), [[srd_helpers]] (`lookup`), [[vocab]] (the second canon; the import is mutual — [[vocab]] uses `titleCase`).
- Used by: [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]], [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Index shape: `slug → (lowercased name → canonical name)`. Built once in the factory by walking every Tier-0 `seedRows` name.
- `canonical` lookup falls back to a title-cased variant of the raw string before giving up.
- **`lookupRef` is a three-outcome ladder** (B9). ① built-in canon hits → `{_lookup: slug, name}` (via [[srd_helpers]] `lookup`), resolved at install time against the world's Tier-0 row UUIDs. ② canon misses but [[vocab]] knows the pk → retry the canon with the *upstream display name* (`thieves-cant` → `Thieves' Cant`, which the built-in pack does ship); still missing → `tier0Seeder` mints a pack-local Tier-0 row and returns a build-gated `{_ref}`. ③ nothing defines it → sink entry + null, exactly as before. **Order matters**: the vocabulary is never consulted for a value that already mapped, so B9 cannot change existing output — and with no seeder installed the behaviour is byte-for-byte the old one (asserted in `test/tool/vocab_test.dart`).
- `canonical` / `namesFor` are unchanged and do **not** see the vocabulary: they return built-in canonical names, and handing a caller `"Void Speech"` from them would produce a `{_lookup}` that dangles.
- `UnmappedSink.toJson` sorts each slug's values by descending count.

## Notes
- The sink is why `unmapped_report.json` lists every non-SRD enum value with a frequency — used to triage which mapper aliases to add. **After B9 it holds one bucket**: 70 free-text `alignment` values, which no fixture can fix (audit **B10**). The `language` (72) and `size` (2) buckets are closed.
