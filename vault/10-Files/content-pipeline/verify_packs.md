---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/verify.dart
layer: tool
language: dart
status: stable
updated: 2026-08-13
tags: [file]
---

# `verify.dart` / `bin/verify_packs.dart`

> [!abstract] Primary Purpose
> Source ↔ asset **correctness** gate (audit phase **T1**). [[audit_packs]] counts values; nothing compared them to the fixtures they were built from. For every entity in a shipped pack, this re-reads the pinned-snapshot row it came from and judges each mapped field against the column that should have fed it. `bin/verify_packs.dart` is the CLI; the rule table and the engine live in `verify.dart`.

## Inputs / Outputs
**Inputs**
- `dart run tool/open5e_import/bin/verify_packs.dart --data ../open5e-api-staging/data [--packs <dir>] [--only <slugs>] [--doc <slug>] [--sample N] [--examples N] [--markdown] [--allow-disagreements]`
- **Needs the snapshot** (unlike [[audit_packs]] / [[dupe_census]]). `--packs` grades a scratch rebuild instead of `assets/open5e_packs`.

**Outputs**
- Per-`(category, field, verdict)` findings with worked examples, plus verdict totals.
- **Exits 1 on any `disagree`** — a mapping defect. Holes and fabrications report but do not fail.

## Dependencies & Links
- Depends on: [[loaders]], [[sources]], [[gate]] (`builtinNameIndex`, for the class-name filter L3's `spell.class_refs` rule restates) and one mapper helper, `classTagsFromV2` from [[mapper_spell]] — the slug→name transform, shared rather than re-implemented. **Calls no [[normalize]]** — see below.
- Sibling of: [[audit_packs]] (presence), [[dupe_census]] (redundancy), [[diff_packs]] (rebuild delta), [[gate_packs]] (relations — T3, and the owner of the `creature-action`/`trait` rows this tool's scope excludes).
- Consumers: `flutter_app/docs/open5e_content_audit.md` §3.6.
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **Five verdicts**: `ok` (shipped value *is* the source's), `disagree` (contradiction — the only failing one), `absent` (source has a value the pack lacks), **`unsourced`** (the pack has a value nothing behind it), `unverifiable` (declared per rule, with the reason the mapper derived it from more than one column).
- **`unsourced` is the class no other tool can see.** [[audit_packs]]' ⚠ marker only fires on a value identical across an *entire category corpus-wide*; a mapper default that varies by document slips through it. This counts, per field, the rows carrying a value with no source — 3,663 on the first run, of which one was a live defect ([[mapper_monster]]'s `hp_dice`, audit **B11**) and the rest confirmed constants.
- **Not the mapper checking itself.** The rules are a hand-written restatement of the field ⟷ column contract, read off the fixtures and the schema. Lookup refs are compared by case-folded **name**, which asks "did the source's value land here?" without re-running the canon that decided how to spell it.
- **Scope**: parent categories only (`monster`, `spell`, `magic-item`, `feat`, `class`, `subclass`, `species`, `subspecies`, `background`) — the ones mapping one fixture row to one named entity. `creature-action`/`trait` are content-hash-deduped and renamed on collision, so they have no stable name→row mapping; they are phase **T3**'s relational gate. `adventuring-gear` is synthesised and has no fixture at all (**B6**).

## Notes
- **The rule table was wrong before any mapper was.** The first run reported 893 disagreements and **all 893** were the verifier misstating how a correct value is spelled (pluralised magic-item categories, three-letter ability codes, a5e's "transformation" school, `D10` hit dice, and — most worth remembering — **B9's pack-local Tier-0 rows referenced by resolved uuid rather than a `{_lookup, name}` placeholder**, so a name comparison has to follow the id). All five are pinned by `test/tool/verify_packs_test.dart` so the next rule inherits the lesson.
- Adding a field to the gate means a `_Rule` in `verify.dart` (**not** in `bin/`) plus a case in that test.
- **`spell.class_refs`** (audit **L3**, 2026-08-13) is the newest rule and shows the `unverifiable` escape used honestly: only the 311 spells whose v2 `classes` column is non-empty can be judged; the other 986 get their class list from the **v1** fixtures this tool does not read, and the rule says so instead of pretending to check them.
- An undeclared derivation is indistinguishable from a fabrication; that is why `unverifiable` names a reason per rule instead of skipping the field silently.
