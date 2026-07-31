---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/spell.dart
layer: tool
language: dart
status: stable
updated: 2026-07-31
tags: [file]
---

# `mappers/spell.dart`

> [!abstract] Primary Purpose
> Maps v2 Open5e `Spell.json` rows onto the app's `spell` package entity. Every typed field the spell schema carries is filled (level, school, casting time, range, components, duration, save, damage types, attack). The originating class list is stored as entity **tags** (not `class_refs`) — a spell package ships no class entities of its own, so an inter-entity `_ref` would dangle.

## Inputs / Outputs
**Inputs**
- `mapSpells(pack, norm, source, spells, {v1ClassByName})` — spell fixtures from [[loaders]].
- `v1ClassByName`: `spellNameLower → v1 dnd_class` string, built in [[build_packs]] to recover class linkage when v2 `classes` is empty (most 3rd-party docs).

**Outputs**
- Adds `spell` entities to the `PackBuilder` ([[refgraph]]) with class tags.

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]] (`titleCase`), [[refgraph]], [[srd_helpers]] (`packEntity`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- `_schoolAlias = {'transformation': 'Transmutation'}` (only the a5e variant needs folding; rest title-case 1:1 via Tier-0 lookup).
- `_castingTime`: parses `'10minutes'`/`'bonus-action'` → `(amount, unit)`; unknown words → `'Special'`.
- `_range`: prefers structured `range`/`range_unit` (feet/miles→ft, `any`→Unlimited); falls back to `range_text` keywords (self/touch/sight/unlimited) and a numeric grab. Miles × 5280.
- `_duration`: maps the long tail of free-text durations onto the 6 canonical units; instantaneous/dispelled/permanent special-cased; unparseable → `'Special'` (a canonical row, never logged unmapped).
- Components: V/S/M booleans → Tier-0 `casting-component` rows; material spec adds `material_description` / `material_cost_gp` / `material_consumed`.
- Spell attack: `attack_roll == true` → `attack_type` Ranged if range>5 ft else Melee.
- **Area of effect** (audit **B4**, 2026-07-31): `shape_type` → `area_shape_ref` via the built-in `area-shape` Tier-0 canon, `shape_size` → `area_size_ft`. Upstream uses exactly five shapes (cone/cube/cylinder/line/sphere) and every one is already a built-in row, so nothing reaches the unmapped sink. `shape_size_unit` is null on ~⅔ of rows and `ft`/`feet` on the rest — **no other unit exists anywhere in the snapshot**, so the size is unconditionally feet; no row carries a size without a shape. 103 of 1,297 shipping spells have an area at all, so 7% is the ceiling.
- **Reaction trigger** (audit **B4**): `reaction_condition` → `reaction_trigger` via `_reactionTrigger`. Upstream stores it as the *tail of the casting-time line* ("1 reaction, which you take when…"), so 46 of the 51 rows open with a dangling relative clause; `_reactionLeadIn` strips `which|that you take` and the remainder is capitalised and given a full stop, because the app's field stands alone. Not gated on casting time — all 51 rows are already `reaction`, so a gate could only ever drop data.
- **Class tags**: v2 `classes` (`['srd_wizard']`→`['Wizard']` via `_classTags`, taking the last `_`-segment + dedup) win; else `_classTagsFromV1` splits the v1 comma-string (`'Druid, Ranger, Sorceror'`→`['Druid','Ranger','Sorcerer']`, applying `_v1ClassFix = {'Sorceror':'Sorcerer'}`). Non-class tokens pass through harmlessly (match no class).

## Notes
- **B4's premise held** — the first audit phase where it did, after B9/B8/B3/B2 each reversed theirs. Both columns were measured against the pinned snapshot (`d4276c58`) *before* code was written. See `flutter_app/docs/open5e_content_audit.md` §5.6 / §6 B4.
- The class list lives as tags because the spell card's class linkage is matched at runtime by name against installed class entities, not by a hard `_ref`.
