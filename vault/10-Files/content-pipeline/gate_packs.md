---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/gate.dart
layer: tool
language: dart
status: stable
updated: 2026-08-19
tags: [file]
---

# `gate.dart` / `bin/gate_packs.dart`

> [!abstract] Primary Purpose
> **Relational** sanity gate (audit phase **T3**). The four censuses ask about one field or one entity at a time; this asks whether an entity has the *relations* it must have — a monster with actions, a child row someone points at, a ref that lands somewhere. `bin/gate_packs.dart` is the CLI; the rules live in `gate.dart` so they can be tested in-process, and [[build_packs]] runs the same gate over what it just wrote.

## Inputs / Outputs
**Inputs**
- `dart run tool/open5e_import/bin/gate_packs.dart [--packs assets/open5e_packs] [--examples N]`
- **No snapshot needed** — everything it checks is inside the packs plus the built-in name index ([[builtin_schema]] seed rows + [[srd_core_pack]]).

**Outputs**
- Violations grouped by rule with examples; **exits 1 on any violation**.
- `gatePacks(packs, builtinIndex)` is the pure entry point the tests drive; `gatePackDir(dir)` is the file-reading wrapper [[build_packs]] calls.

## Dependencies & Links
- Depends on: [[builtin_schema]], [[srd_core_pack]] (the name index). Imports no mapper.
- Used by: [[build_packs]] (post-write gate).
- Sibling of: [[audit_packs]] (presence), [[dupe_census]] (redundancy), [[diff_packs]] (rebuild delta), [[verify_packs]] (value correctness).
- Consumers: `flutter_app/docs/open5e_content_audit.md` §3.8.
- Domain map: [[Content-Pipeline]]

## Key Logic / Variables
- **Eight rules**: `monster-actionless` (all five action buckets empty), `orphan-child` (a `creature-action`/`trait` no statblock references), `dangling-hard-ref` (a uuid `_ref` with no entity behind it), `dangling-soft-ref` (`{slug|_lookup, name}` that resolves nowhere), `qualifier-strip`, `empty-equipment-option`, `bucket-skew`, `escape-residue`.
- **R2 (2026-08-19) — `escape-residue`.** Yayınlanan hiçbir `name`/
  `description` yarım çözülmüş unicode kaçışı (`æ` + dört hex, `Væ00e6ttir`)
  taşıyamaz. [[mapper_monster]] onarımı yapıyor; bu kural geri gelmesini
  engelliyor. Yayınlanan pakette 8 ihlal yakalıyor, yeniden üretilende 0.
- **`bucket-skew` is §3.5's defect stated as a rule, not as a count.** Every statblock has actions and only some have bonus/reaction/legendary/lair ones, so a pack whose base `action_refs` are *strictly* outnumbered is a partial conversion — `open5e-tob3` shipped 2 against 307. Guarded by a 20-monster floor (`tdcs` ships 4 creatures) and strict `<`, so a tie reads as thin, which is [[audit_packs]]' question.
- **`qualifier-strip` is an alarm, not a report.** [[mapper_monster]]'s `_ensureChild` disambiguates a colliding child with the creature name ("Scimitar (Firetamer)") and `findEntityIdByName` strips exactly that qualifier on a miss, so L0 measured **3,501** bundled rows whose stripped name is a built-in card. Nothing points at them today; the rule fires the day something does, instead of the ref silently landing on the generic card.
- **Resolution scope matches the runtime**: a soft ref resolves across every installed package, so the index is the built-in pack plus the whole bundled corpus, keyed `(slug, name)` **case-sensitively** and NUL-separated — the same key [[dupe_census]] section C uses.
- **Exceptions are allow-listed by name, with a checked reason.** `_actionlessUpstream` holds `a5e-mm`'s Frog and Seahorse: the snapshot has no `CreatureAction` row parented to either and neither name is in any v1 `Monster.json`, so B8's backfill has nothing to recover. By name, so a pack that loses a *different* creature's actions still fails.

## Notes
- First run over the shipped assets: **198 violations, every one already filed** — 196 `monster-actionless` + 1 `bucket-skew` (both tob3, fixed in the importer by B8, red until the rebuild is promoted) and 1 `dangling-soft-ref` (`"Spare The Dying"`, L3's, found independently of [[dupe_census]]). **As of 2026-08-13 the gate is green: 0 violations** — the D1 promotion cleared the 197 tob3 rows and L3's casing fix cleared the soft ref. The four rules that came back **0** are the new information: `orphan-child` and `empty-equipment-option` had never been checked at all.
- **`empty-equipment-option` counted only in-pack uuids until audit B6 (2026-08-14)** — the same blindness the wizard's commit flow had, and the reason 159 empty gear stubs looked correct: a synthesised in-pack ref counted, a real cross-pack softRef did not. It now resolves a softRef item against `nameIndex` too. With B6's links in place 46 of 50 options resolve at least one card; the other 4 sit in **`_kitlessUpstream`**, a by-name allowlist with the same contract as `_actionlessUpstream` (a *different* option going empty still fails). Their kits name only generic categories ("a set of artisan's tools"), gear SRD 5.2.1 does not ship ("common clothes", "snowshoes", "donkey"), or a holy symbol — which is three cards, so picking one is a coercion.
- Adding a rule means adding it in `gate.dart` (**not** in `bin/`) plus a provoking case *and* a healthy case in `flutter_app/test/tool/gate_packs_test.dart` — a rule that never fires looks exactly like a clean corpus, which is how 396 actionless statblocks shipped.
