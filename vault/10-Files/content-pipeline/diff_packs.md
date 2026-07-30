---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/bin/diff_packs.dart
layer: tool
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `diff_packs.dart`

> [!abstract] Primary Purpose
> Offline CLI that answers **"what did my rebuild change?"** — the question neither [[audit_packs]] (*are the fields filled?*) nor [[dupe_census]] (*should this entity exist?*) can answer. [[build_packs]] writes 25 MB of **minified single-line** JSON, so `diff` on the assets is unreadable: one changed field shows up as one 1.3 MB line. This tool loads both pack directories, joins entities on their uuidv5 id, and aggregates every difference into change *classes* — `(category, field, kind) → count` plus a worked example each — so a rebuild that moved 30 k values reduces to a handful of decisions. Built for the audit's Stage A0 gate (*"every diff hunk is explained", not "no diff"*) and intended to run after every mapper fix in Stage B.

## Inputs / Outputs
**Inputs**
- `--new <dir>` (**required**) — the rebuilt pack directory.
- `--old <dir>` — default `assets/open5e_packs`, i.e. what ships.
- `--only <slug,slug>` — restrict to categories; `--examples N` (default 1) — examples per class; `--markdown`.
- Reads `<dir>/*.pkg.json` only (`manifest.json` / `unmapped_report.json` ignored). No Flutter, no built-in schema import — pure `dart:io` + `dart:convert`.

**Outputs**
- stdout, plain or markdown. Five reports + one table:
  1. **pack set** — packs only in old / only in new (a new upstream document, or one that failed its ref gate and was therefore not written, shows up here);
  2. **metadata** — per-pack `metadata` key diffs;
  3. **counts** — per-pack, per-category entity counts;
  4. **entity churn** — added / removed / changed ids per category;
  5. **change classes** — the aggregation, sorted by count;
  plus **spell class-tag coverage** old vs new, per pack.
- Exit code is always 0 — it reports, it does not gate. (A gating relational check is the audit's separate **T3** phase.)

## Dependencies & Links
- Depends on: nothing in `lib/` — deliberately. Compare with [[dupe_census]], which imports [[builtin_schema]] + [[srd_core_pack]].
- Reads the output of: [[build_packs]] / [[emit]].
- Siblings: [[audit_packs]], [[dupe_census]], [[migrate_pack_assets]].
- Domain map: [[Content-Pipeline]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §4 A0 (the phase that added it, and the classified diff it produced), §7 (commands).

## Key Logic / Variables
- **Identity is the uuidv5 id**, which [[refgraph]] derives from package + slug + name and is therefore stable across rebuilds. Consequence: a *renamed* entity reads as one removal + one addition, and a re-mapped field reads as a change. That is the correct reading — a rename changes the id, which changes what every soft ref resolves to.
- `_diffEntity` walks the 10 scalar/short-list top-level wire keys (`_topLevelKeys`: name, type, source, description, tags, image_path, images, dm_notes, pdfs, location_id) **and** every key of `attributes`, keyed as `attributes.<k>`. Comparison is `jsonEncode` equality, so ordering inside a list counts as a difference by design (list order is meaningful for `_refs`).
- Change kind is derived from presence, not value: absent-in-old → `added`, absent-in-new → `removed`, else `changed`. So a field the importer stopped writing is visibly distinct from one it started writing.
- **`spell.tags` gets its own permanent table** because it is the only thing making bundled spells visible in character creation (`spell.class_refs` is 0% — audit §2.3.1), and it is recovered from the `data/v1` fixtures by [[build_packs]]'s `_v1ClassIndex`. A snapshot cloned without `v1`, or a new document missing from `_v1DocForV2`, silently empties it while every other number improves. Counted three ways per pack: total spells, spells with any tag, spells with a tag matching one of the 13 `_classNames`. Plain output flags a drop with `← REGRESSED`.
- Arg parser accepts both `--k=v` and `--k v` (copied from [[dupe_census]]) — deliberately *unlike* [[build_packs]]'s parser, which takes the space form only and silently ignores `--out=X`.
- Self-check: run with `--old` == `--new`; it must print "Identical".

## Notes
- Not to be confused with the audit's planned **T1** `verify_packs.dart`, which diffs **source fixture ↔ asset** (is the value *right*?). This one diffs **asset ↔ asset** (did the value *move*?). They are complementary and neither subsumes the other.
- First run (A0, 2026-07-30, snapshot `d4276c58`) found the shipped assets reproducible: 17 values in 4 classes across 20,712 entities, zero entity churn, spell tags unchanged. Full classification in the audit's §4 A0.
