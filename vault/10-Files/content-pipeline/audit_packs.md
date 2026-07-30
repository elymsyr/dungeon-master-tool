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
- Filled ≠ *read by the wizard* either. The chargen steps have their own readers and several match ids by raw `String` equality, so a correctly-written `{slug, name}` softRef is invisible there even when the sheet resolves it. See [[entity_ref]] and audit doc §2.3.1.
- Filled ≠ *correct*. The tool never compares a value to its fixture, and `⚠ const` only fires when a value is identical across an **entire category** — a mapper default that varies by document slips through. The audit's phase **T1** (`verify_packs.dart`, source ↔ asset differ) is what turns this into a correctness gate.
- **Scope hole: the built-in pack is not measured.** `--packs` defaults to `assets/open5e_packs` and nothing points it at `generateBuiltinDnd5eV2Schema().seedRows` + `buildSrdCorePack()`, even though [[srd_core_pack]] is the target of every softRef the packs emit. Audit phase **T2** adds a `--builtin` mode. Current corpus figure for the bundled side: **407 declared (category, field) slots, 125 filled**.
