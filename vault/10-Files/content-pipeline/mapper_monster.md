---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/monster.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `mappers/monster.dart`

> [!abstract] Primary Purpose
> Maps a v2 Open5e `Creature` (+ its `CreatureAction` / `CreatureActionAttack` / `CreatureTrait` child rows) onto the app's `monster` + `creature-action` + `trait` package entities. Depth = stats + descriptive text: every derivable stat field is filled, but mechanical effect/grant DSL is NOT attempted. Actions/traits are minted as separate entities the monster references by name (resolved to ids in PackBuilder Pass 2), exactly like the SRD core pack. Includes heavy upstream-data sanitization to drop mis-segmented junk rows.

## Inputs / Outputs
**Inputs**
- `mapCreatures(pack, norm, source, creatures, actions, attacks, traits)` — fixture lists from [[loaders]] (`groupBy(actions,'parent')`, etc.).
- `Normalizer norm` for Tier-0 lookups ([[normalize]]).

**Outputs**
- Adds `monster`, `creature-action`, `trait` entities to the `PackBuilder` ([[refgraph]]). Monster references children by name via `ref('creature-action', name)` / `ref('trait', name)`.

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]], [[refgraph]], [[srd_helpers]] (`packEntity`), `dnd5e_constants` (`abilityModifier`, `proficiencyTableDefault`, `kDnd5eSavingThrows`, `kDnd5eSkills`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- **Action split by `action_type`**: BONUS_ACTION → `bonus_action_refs`, REACTION → `reaction_refs`, LEGENDARY_ACTION → `legendary_action_refs` (+ `legendary_action_uses: 3` SRD default since Open5e omits the count), LAIR_ACTION → `lair_action_refs`, else `action_refs` (always present, schema-required).
- **Child dedup** (`_ensureChild`): content-hashed (`type|description|sorted-attrs`) so identical actions/traits across creatures are authored once; name collisions on different content are disambiguated with ` (CreatureName)` / ` (CreatureName N)`.
- **Name sanitization** (Open5e scraper mis-segments stat blocks): `_cleanMonsterName` strips `Npc:` prefix + re-cases small-words. `_cleanChildName` drops trailing periods, lifts roll-table range rows (`1-4: Arm`→`Arm`), recovers a label from desc for purely-numeric names, strips leading list-counts and leaked attack clauses, reduces `Label: effect sentence`→`Label` (gated), and DROPS clearly-spurious full-sentence fragments (`_looksLikeSentenceFragment`: ≥4 lowercase-initial words, multiple sentences, or legendary-action preamble) — returning null skips the ref so no orphan ships.
- **Stat derivation**: `_crString` maps decimals to fractions (0.125→`1/8`); `_profForCr` and `_xpByCr` (full CR→XP table 0..30) backfill proficiency bonus + XP when Open5e omits them. `_saveTable`/`_skillTable` reconstruct proficiency tables by back-solving `misc = bonus - abilityMod - PB`.
- Attack mapping (`_actionRow`): derives `attack_kind` (Melee/Ranged × Weapon/Spell from reach/range/attack_type), `damage_dice` (`XdY±Z`), recharge (`RECHARGE_ON_ROLL`→`recharge_min_roll`, `PER_DAY`→`uses_per_day`).

## Notes
- Largest mapper (~24KB). The name-sanitization heuristics are deliberately conservative (real titles like "Keen Hearing and Smell" pass through). Two recent commits (323924a, ac2d186) tuned mis-segmented name handling.
