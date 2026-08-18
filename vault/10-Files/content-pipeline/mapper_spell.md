---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/spell.dart
layer: tool
language: dart
status: stable
updated: 2026-08-18
tags: [file]
---

# `mappers/spell.dart`

> [!abstract] Primary Purpose
> Maps v2 Open5e `Spell.json` rows onto the app's `spell` package entity. Every typed field the spell schema carries is filled (level, school, casting time, range, components, duration, save, damage types, attack). The originating class list is written **both** as entity **tags** and (audit **L3**, 2026-08-13) as `class_refs` softRefs: a hard `_ref` would dangle, but `softRef('class', name)` name-resolves at read time against the built-in class that is in scope in every world.

## Inputs / Outputs
**Inputs**
- `mapSpells(pack, norm, source, spells, {v1ClassByName, knownClasses})` — spell fixtures from [[loaders]].
- `knownClasses`: class **names** a softRef may target, derived in [[build_packs]] from `builtinNameIndex()` ([[gate]]). Anything outside it stays a tag only.
- `v1ClassByName`: `spellNameLower → v1 dnd_class` string, built in [[build_packs]] to recover class linkage when v2 `classes` is empty (most 3rd-party docs).

**Outputs**
- Adds `spell` entities to the `PackBuilder` ([[refgraph]]) with class tags **and** `attributes.class_refs`.
- `classTagsFromV2` is public so [[verify_packs]] can restate the `class_refs` contract without re-implementing the slug→name transform.

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]] (`titleCase`), [[refgraph]], [[srd_helpers]] (`packEntity`), [[mapper_chargen]] (`softRef`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- `_schoolAlias = {'transformation': 'Transmutation'}` (only the a5e variant needs folding; rest title-case 1:1 via Tier-0 lookup).
- `_castingTime`: parses `'10minutes'`/`'bonus-action'` → `(amount, unit)`; unknown words → `'Special'`.
- `_range`: prefers structured `range`/`range_unit` (feet/miles→ft, `any`→Unlimited); falls back to `range_text` keywords (self/touch/sight/unlimited) and a numeric grab. Miles × 5280.
  - **F-spells-that-dont-suck-01 (F3 / Dalga 2, 2026-08-18, ❓ open, cause `M`):**
    the `self` keyword ends the branch, so a parenthesised area — `Self (60-foot
    radius)`, `Self (10-foot dome)`, `Self (1-mile radius)` — ships as
    `range_type: Self` with `range_ft`, `area_shape_ref` and `area_size_ft` all
    null. 8 cards, all in `spells-that-dont-suck`, the only document that writes
    `Self (N …)`; the structured `range` column is `0` on those rows, so the
    number exists only in the text. B4's `area-shape` canon already has the rows
    it would need.
- `_duration`: maps the long tail of free-text durations onto the 6 canonical units; instantaneous/dispelled/permanent special-cased; unparseable → `'Special'` (a canonical row, never logged unmapped).
  - **F-pass0-11 (F3 / Dalga 2, 2026-08-18, ❓ open):** the `permanent` special case sends 25 cards to `Until Dispelled` — a claim the source never makes, since the Tier-0 `duration-unit` canon has no "permanent" row (`a5e-ag` 12, `deepm` 9, `kp` 2, `deepmx` 1, `spells-that-dont-suck` 1). `Special`, the function's own fallback, is the honest value; see `flutter_app/docs/pack_conformance_findings.md`.
  - **F-wz-01 (F3 / Dalga 2, 2026-08-18, ❓ open):** the numeric grab takes the first `number + unit` pair and ignores the tail, so `1 hour/caster level` ships as a flat `Hours 1` (1 card corpus-wide, `wz`'s `Order of Revenge`).
  - **F-pass0-12 (F3 / Dalga 2, 2026-08-18, ❓ open):** the regex knows only round/minute/hour/day and the canon tops out at `Days`, so `1 year` durations fall through to `Special` with a null amount — a stated number lost on 3 cards (`deepm` 2, `wz` 1). `Days 365` is writable today.
  - **F-pass0-13 (F3 / Dalga 2, 2026-08-18, ❓ open):** the same numeric grab turns
    ranges and conditions into certainties — `2-12 hours` → `Hours 12` (the upper
    bound, silently) and `24 hours or until …` → `Hours 24`; 4 cards (`deepmx` 2,
    `deepm` 2). Text that matches *no* branch is honest (`until destroyed` →
    `Special`), so the loss only happens when the string starts with a number.
- `requires_concentration`: the source's `concentration` boolean only.
  - **F-wz-02 (F3 / Dalga 2, 2026-08-18, ❓ open):** upstream also states concentration inside the free-text `duration`; `Storm of Axes` has `duration = 'concentration + 1 round'` with the boolean `false`, so the required field ships `false`. Reading the duration text alongside the boolean is a two-line fix; corpus-wide the v2 snapshot has 1 such row.
  - **F-pass0-14 (F3 / Dalga 2, 2026-08-18, ❓ open, cause `S`):** the upstream
    column itself is wrong on 7 cards across 5 packs whose rules text says "until
    you lose concentration" (`deepmx` 2, `deepm` 2, `toh` 1, `wz` 1, `a5e-ag` 1).
    `deepmx` ships the boolean `false` on all 64 rows and v1 `dmag-e` has it
    `null` on all 64 — no code change closes this one.
- Components: V/S/M booleans → Tier-0 `casting-component` rows; material spec adds `material_description` / `material_cost_gp` / `material_consumed`.
  - **F-spells-that-dont-suck-02 (F3 / Dalga 2, 2026-08-18, ❓ open, cause `S`):**
    `material_cost` is written straight through, and in `spells-that-dont-suck`
    the column is `'0'` on 63 of its 81 material rows — 5 of them while the
    `material_specified` text names a price (`…worth at least 665 gp`), so the
    card claims "Material Cost (gp): 0". `deepm` is the harmless shape of the
    same data: its column is `null`, the `if (cost != null)` guard skips the
    field, and 0 of 288 material cards carry a zero. Only these two documents
    fill `material_specified` at all.
- Spell attack: `attack_roll == true` → `attack_type` Ranged if range>5 ft else Melee.
- **Area of effect** (audit **B4**, 2026-07-31): `shape_type` → `area_shape_ref` via the built-in `area-shape` Tier-0 canon, `shape_size` → `area_size_ft`. Upstream uses exactly five shapes (cone/cube/cylinder/line/sphere) and every one is already a built-in row, so nothing reaches the unmapped sink. `shape_size_unit` is null on ~⅔ of rows and `ft`/`feet` on the rest — **no other unit exists anywhere in the snapshot**, so the size is unconditionally feet; no row carries a size without a shape. 103 of 1,297 shipping spells have an area at all, so 7% is the ceiling.
- **Reaction trigger** (audit **B4**): `reaction_condition` → `reaction_trigger` via `_reactionTrigger`. Upstream stores it as the *tail of the casting-time line* ("1 reaction, which you take when…"), so 46 of the 51 rows open with a dangling relative clause; `_reactionLeadIn` strips `which|that you take` and the remainder is capitalised and given a full stop, because the app's field stands alone. Not gated on casting time — all 51 rows are already `reaction`, so a gate could only ever drop data.
- **Class tags**: v2 `classes` (`['srd_wizard']`→`['Wizard']` via `classTagsFromV2`, taking the last `_`-segment + dedup) win; else `_classTagsFromV1` splits the v1 comma-string (`'Druid, Ranger, Sorceror'`→`['Druid','Ranger','Sorcerer']`, applying `_v1ClassFix = {'Sorceror':'Sorcerer'}`). Non-class tokens pass through harmlessly (match no class).
- **`class_refs`** (audit **L3**, 2026-08-13): the same tag list, filtered through `knownClasses`, emitted as `softRef('class', name)` — 1,204 of 1,297 shipping spells. The filter is load-bearing: an unresolvable softRef is a `dangling-soft-ref` violation in [[gate]], and 146 tag values (Artificer, Herald, Anti Paladin) name a class no pack ships. `tags` is deliberately **kept** — 8 spells are tagged only with those names and would disappear from the wizard if it were retired ([[wizard_options]] `spellMatchesClass` reads both).

## Notes
- **B4's premise held** — the first audit phase where it did, after B9/B8/B3/B2 each reversed theirs. Both columns were measured against the pinned snapshot (`d4276c58`) *before* code was written. See `flutter_app/docs/open5e_content_audit.md` §5.6 / §6 B4.
- **F-pass0-15 (F3 / Dalga 2, 2026-08-18, ❓ open):** the mapper writes no
  `spell.effects`, and §5.8 justifies the ⚪ with two reasons — no reader in
  `domain/`/`application/` (true) and no structured damage rows upstream
  (**false**: v2 `Spell.json`'s `damage_roll` is filled on 303 of the 1,297
  shipping spells, 285 of them plain dice, next to `damage_types` and
  `saving_throw_ability`). The verdict stands on the reader half; the written
  reason is what the finding asks to correct.
- The class list lives as tags **as well as** refs: the tag is what still carries the 8 spells whose only class name has no card, and [[wizard_options]] `spellMatchesClass` accepts either. Retiring `tags` is not part of L3.
