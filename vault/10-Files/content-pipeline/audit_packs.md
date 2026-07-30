---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/audit_packs.dart
layer: tool
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `audit_packs.dart`

> [!abstract] Primary Purpose
> Field census over the bundled Open5e packs. Joins two things the rest of the toolchain never compares: the **declared** shape of a category (`generateBuiltinDnd5eV2Schema()` — every field, its `FieldGroup`, whether it is required) and the **actual** contents of `assets/open5e_packs/*.pkg.json`. One row per declared field, with how many shipped entities carry a value. This is the machine behind `flutter_app/docs/open5e_content_audit.md` §3.1/§5, so those tables are regenerated, never hand-maintained.

## Inputs / Outputs
**Inputs**
- `dart run tool/open5e_import/bin/audit_packs.dart [--packs <dir>] [--only <slugs>] [--markdown]`
- Reads the shipped assets only — **no source snapshot needed**, so it runs on any checkout.

**Outputs**
- Per-category tables on stdout; `--markdown` emits them in the audit doc's exact shape.
- An "Undeclared keys" footer for attributes the packs carry that the schema does not declare (`description` everywhere, `prereq_clauses` on `feat`).

## Dependencies & Links
- Depends on: [[builtin_schema]] (the declared side), [[emit]] (the shape it reads).
- Sibling of: [[dupe_census]] — that tool asks *"should this entity exist at all?"*, this one asks *"are its fields filled?"*.
- Consumers: `flutter_app/docs/open5e_content_audit.md`.
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **`_auditedSlugs`** — the 12 categories a pack can ship. Tier-0 lookups and Tier-2 DM categories are excluded as noise.
- **Filled** = non-null and not an empty string/list/map. `0` and `false` count as filled: the mapper wrote them on purpose (`repeatable: false`), and treating them as absent would hide real coverage.
- **`⚠ const`** — when every entity in a category carries the *identical* value, the mapper wrote a constant instead of reading the source (species `creature_type_ref` hardcoded `Humanoid`; gear stubs all `cost_cp: 0`). This is why a 100% column is not proof of coverage, and why the audit doc carries a whole re-verification phase for green rows.

## Notes
- Filled ≠ *read*. A field can be 100% and still reach no sheet if [[character_resolver]] has no pass for it — the audit doc pairs every fill target with `bundled_pack_resolve_test`.
