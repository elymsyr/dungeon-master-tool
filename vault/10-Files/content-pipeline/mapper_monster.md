---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/monster.dart
layer: tool
language: dart
status: stable
updated: 2026-08-18
tags: [file]
---

# `mappers/monster.dart`

> [!abstract] Primary Purpose
> Maps a v2 Open5e `Creature` (+ its `CreatureAction` / `CreatureActionAttack` / `CreatureTrait` child rows) onto the app's `monster` + `creature-action` + `trait` package entities. Depth = stats + descriptive text: every derivable stat field is filled, but mechanical effect/grant DSL is NOT attempted. Actions/traits are minted as separate entities the monster references by name (resolved to ids in PackBuilder Pass 2), exactly like the SRD core pack. Includes heavy upstream-data sanitization to drop mis-segmented junk rows.

## Inputs / Outputs
**Inputs**
- `mapCreatures(pack, norm, source, creatures, actions, attacks, traits, v1Actions)` — fixture lists from [[loaders]] (`groupBy(actions,'parent')`, etc.).
- `Normalizer norm` for Tier-0 lookups ([[normalize]]).
- `V1ActionIndex v1Actions` (audit **B8**) — `lowercased monster name → action_type bucket → [{name, desc}]`, built by [[build_packs]] from `data/v1/<doc>/Monster.json`. Defaults to `const {}`, which is the exact pre-B8 behaviour.

**Outputs**
- Adds `monster`, `creature-action`, `trait` entities to the `PackBuilder` ([[refgraph]]). Monster references children by name via `ref('creature-action', name)` / `ref('trait', name)`.

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]], [[refgraph]], [[srd_helpers]] (`packEntity`), `dnd5e_constants` (`abilityModifier`, `proficiencyTableDefault`, `kDnd5eSavingThrows`, `kDnd5eSkills`).
- Used by: [[build_packs]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]], [[SRD-5.2.1]]

## Key Logic / Variables
- **Action split by `action_type`**: BONUS_ACTION → `bonus_action_refs`, REACTION → `reaction_refs`, LEGENDARY_ACTION → `legendary_action_refs` (+ `legendary_action_uses: 3` SRD default since Open5e omits the count — **measured against v1 on 2026-08-18**: `cc`'s `legendary_desc` says "can take 3 legendary actions" on 20/20 and `tob2`'s on 9/9, and corpus-wide only **2** rows disagree, both in `tob` ("can take 1"), handed to that scan unit), LAIR_ACTION → `lair_action_refs`, else `action_refs` (always present, schema-required).
  - ✅ **`open5e-tob3`'s empty Actions block was never this switch's fault** (audit **B8**, fixed 2026-07-31). The pack shipped **2** `action_refs` against 136 bonus / 96 reaction / 75 legendary, and the natural reading was a mis-set enum. The pinned snapshot says otherwise: `tob3/CreatureAction.json` genuinely holds 309 rows for 397 creatures with 2 `ACTION` among them, and the three non-`ACTION` buckets match `v1/tob3/Monster.json` **row for row** (136 / 96 / 75). Upstream's v2 conversion dropped one column; the mapper was faithful. Nothing caught it — the refs that existed all resolved, so the build gate passed, and the per-field census still read `action_refs` as "filled". **[[gate_packs]] is that gate, and it shipped 2026-08-10**: `monster-actionless` plus `bucket-skew` ("the base action bucket cannot be outnumbered by the situational ones"), run by [[build_packs]] over its own output.
- **v1 action backfill** (audit **B8**): after the v2 loop, any of the four buckets **left entirely empty for this creature** is filled from `v1Actions[rawName.toLowerCase()]` through the *same* `_cleanChildName` + `_ensureChild` path, so recovered rows inherit the sanitizer, the content dedup and the `Name (Creature)` disambiguation.
  - **Empty-bucket-only is the safety argument, and it is measured.** The looser "add any v1 row whose name is absent" rule would add **~2,000 rows corpus-wide** — v1 and v2 disagree about action *names*, not about which actions exist, so it would ship duplicates dressed as recoveries. The conservative rule's whole cost is one monster (Abaasy, the single tob3 creature v2 partially converted, keeps 2 and forgoes 5).
  - The join key is the **raw** upstream name, not `_cleanMonsterName`'s output — that is what reaches tob3's 15 `Npc: …` monsters.
  - `_v1ActionRow` emits prose only: v1 has no `CreatureActionAttack` equivalent, so `attack_bonus`/`damage_dice`/`attack_kind` are absent rather than reverse-engineered out of the text. tob3 ships no attack fixture at all, so nothing is lost. The visible consequence is that `creature-action.attack_kind`/`damage_dice` *shares* fall (41%→35%, 40%→34%) while their absolute counts are unchanged.
  - Result on the rebuild: `monster.action_refs` **86% → 99.8%** (2880/2885), tob3's actionless monsters **396 → 1**. Tests: `flutter_app/test/tool/creature_action_fallback_test.dart` (8 cases).
- **`tags_line` comes from **v1**, not from splitting `type`** (audit B5, 2026-08-14). `_creatureType` does split `"humanoid (elf)"` correctly, but that form occurs on **0 of 3,541** v2 `Creature.type` rows — the v2 conversion moved the subtype into its own column and then dropped it. `mapCreatures(v1Subtypes:)` takes a `lowercased name → subtype` map built by [[build_packs]]' `_v1SubtypeIndex` from `v1/<doc>/Monster.json`, keyed by the same `_v1DocForCreatures` map B8's action backfill uses. **A v2 tag always wins**, so the backfill can never override a sourced value. 292 of 2,885 shipped monsters carry one; pinned by `test/tool/monster_tags_line_test.dart`.
- **`damage_type_ref` is 0% and cannot be fixed here** (audit B5). The mapper reads and resolves `CreatureActionAttack.damage_type`; all 576 source rows that carry one are in `srd-2014`/`srd-2024`, which [[build_packs]] skips publisher-wide. Every attack row in a shipping document is null. Don't "fix" the mapper — there is nothing to read.
  - **F-pass0-18 (F3 / Dalga 4, 2026-08-18, ❓ open, cause `M`):** the "nothing
    to read" half is wrong — only the *column that is read* is empty. When an
    attack row has no genuine extra damage (`extra_damage_die_type` null), the
    neighbouring `extra_damage_type` holds the **primary** damage type:
    **3,479 rows in shipping documents** (`a5e-mm` 828, `tob` 652, `bfrd` 512,
    `tob2` 506, `tob-2023` 505, `ccdx` 473, `tdcs` 3). The column is overloaded
    rather than ambiguous — the other 828 filled rows all carry a real second
    damage, which has no schema counterpart at all.
- **`trait_kind` is hardcoded `Other` on every trait row, and that is correct** (audit V1, 2026-08-14; **re-read against `ccdx` and `tob2` 2026-08-18** — `CreatureTrait.type` is null on 1,016/1,016 and 1,060/1,060 there, so the constant is honest). `CreatureTrait.json` carries a `type` column but it is **null on all 8,613 rows in every document** in the pinned snapshot, so there is nothing to map. Do not "improve" this by classifying the trait's name or `desc` into the schema's six-value enum — that invents a field upstream does not have, which is exactly the `hp_dice` fabrication audit phase B11 was filed to remove. The cost is a `trait_kind` filter that cannot discriminate; that is a schema question, not a mapper one.
- **Alignment is three-way, and only one branch gets the relation** (audit **B10**, 2026-08-14). `_alignment` routes `Creature.alignment` by shape: one of the nine canonical values → `alignment_ref`; anything else that contains an alignment word (`any|lawful|chaotic|neutral|good|evil|unaligned`) → **`alignment_note`** prose beside a *null* ref; neither → dropped and logged to the [[normalize]] sink. None of the 29 free-text expressions upstream (`any alignment`, `chaotic neutral or chaotic evil`, `Neutral Evil (50%) or Lawful Evil (50%)`) reduce to a canonical value, so a synonym normalizer would have converted 0 of 70 — and picking one arm of an "or" is the `hp_dice` fabrication again. The third branch is exactly the three rows corrupt in `Creature.json` itself (`Titan)`, `Shapechanger)` ×2), which must not be laundered into a prose field. 67 monsters carry a note; `unmapped_report.json` 70 → 3. Pinned by `test/tool/monster_alignment_test.dart`.
- **Two `Creature` columns the mapper never opens** (F3 / Dalga 4, 2026-08-18):
  - **F-pass0-19 (❓ open, cause `M`):** `nonmagical_attack_resistance` /
    `nonmagical_attack_immunity`. Upstream states "from nonmagical attacks" in a
    boolean beside the flat list (and in full in `damage_*_display`); `_dmgList`
    reads only the list, so **618 shipping creatures** (514 resistance + 104
    immunity) claim b/p/s resistance **unconditionally** and a magic weapon
    reads as resisted. [[verify_packs]] calls the rows `ok` — the loss is
    *between* columns. There is no `resistance_note` twin of `alignment_note`,
    so the fix is a schema question as much as a mapper one.
  - **F-pass0-20 (❓ open, cause `M`):** `languages_desc`, filled on 354 of
    `ccdx`'s 356 rows. **769 shipping creatures** whose structured `languages`
    list is empty ship with no language line while the source states one
    ("understands Common but can't speak" 10, "understands the languages of its
    creator" 22, "all, telepathy 120 ft." 12). Filled lists lose names too —
    `Umbral` ×13, `Darakhul` ×5, `Aquan` ×4, `Common` ×3 live only in the prose.
    The 17 languages the list does carry all resolve.
- **Child dedup** (`_ensureChild`): content-hashed (`type|description|sorted-attrs`) so identical actions/traits across creatures are authored once; name collisions on different content are disambiguated with ` (CreatureName)` / ` (CreatureName N)`.
  - **F-pass0-17 (F3 / Dalga 4, 2026-08-18, ❓ open, cause `D`):** **the name is
    not in the hash.** Statblock attack text is formulaic, so two different
    weapons with the same numbers hash identically and merge — the first name
    wins and the other creature's ref lands on it. **382** child rows across 7
    packs (`creature-action` 328, `trait` 54) render under another creature's
    name: the Elite Kobold's *Mining Pick* is `Bite (Ahuizotl)`, the Light
    Cavalry's *Cavalry Saber* is `Claw (Bathhouse Drake)`. On 6 traits the name
    carries a mechanic and the merge rewrites it — `Shadow Traveler (1/Day)`
    ships as `(3/Day)`, three uses instead of one. Neither gate sees it:
    [[verify_packs]] judges only `monster` rows and [[gate_packs]] is green
    because the ref resolves — to the wrong card. Adding `name` to
    `_contentHash` costs ~382 extra entities corpus-wide.
- **Name sanitization** (Open5e scraper mis-segments stat blocks): `_cleanMonsterName` strips `Npc:` prefix + re-cases small-words. `_cleanChildName` drops trailing periods, lifts roll-table range rows (`1-4: Arm`→`Arm`), recovers a label from desc for purely-numeric names, strips leading list-counts and leaked attack clauses, reduces `Label: effect sentence`→`Label` (gated), and DROPS clearly-spurious full-sentence fragments (`_looksLikeSentenceFragment`: ≥4 lowercase-initial words, multiple sentences, or legendary-action preamble) — returning null skips the ref so no orphan ships.
- **`hp_dice` is copied or absent, never invented** (audit **B11**, fixed 2026-08-10). `_monsterRow` used to write `hit_dice ?? '1d4'`, and `open5e-bfrd` has `hit_dice: null` on **all 360** of its creatures — so that pack shipped a `1d4` die pool next to a 165-HP Aboleth's own `hp_average`. Neither census could see it (`hp_dice` was a filled string on every row of every pack, so [[audit_packs]] read 100% and the corpus-wide-constant ⚠ could not fire); [[verify_packs]]' `unsourced` column is what caught it. Of the two honest shapes, **omit** was chosen over deriving from `hp_average` + CON + size — a derivation is inference, not source, and would owe an `unverifiable` rule declaring the field unmeasurable. Rebuild effect: 360 removals, **all in `open5e-bfrd`**, no other pack moved; corpus `unsourced` 3,663 → 3,303. Tests: `flutter_app/test/tool/monster_hp_dice_test.dart` (4 cases).
- **Stat derivation**: `_crString` maps decimals to fractions (0.125→`1/8`); `_profForCr` and `_xpByCr` (full CR→XP table 0..30) backfill proficiency bonus + XP when Open5e omits them. `_saveTable`/`_skillTable` reconstruct proficiency tables by back-solving `misc = bonus - abilityMod - PB`.
- Attack mapping (`_actionRow`): derives `attack_kind` (Melee/Ranged × Weapon/Spell from reach/range/attack_type), `damage_dice` (`XdY±Z`), recharge (`RECHARGE_ON_ROLL`→`recharge_min_roll`, `PER_DAY`→`uses_per_day`).
  - **F-pass0-21 (F3 / Dalga 4, 2026-08-18, ❓ open, cause `M`):** `_actionRow`
    never reads `CreatureAction.limited_to_form`, so a shapechanger's form-locked
    attack ships unconditional — Aniwye's `Rock` (*Giant Form Only*) and
    `Bite`/`Claw` (*Skunk Form Only*) all render as always-available. The column
    is filled on **262** corpus rows (**218** shipping; `a5e-mm` 60,
    `tob-2023` 48, `bfrd` 37, `tob2` 30, `ccdx` 24, `tob` 18, `tob3` 1) and only
    **1** of them repeats the qualifier in `desc`; a separate 13 rows carry it
    only in `desc`, and those do reach the card. `legendary_action_cost` (29 rows
    in `tob2`) is the harmless neighbour — no schema field, but the action name
    already says *"(Costs 2 Actions)"*.

## Notes
- Largest mapper (~24KB). The name-sanitization heuristics are deliberately conservative (real titles like "Keen Hearing and Smell" pass through). Two recent commits (323924a, ac2d186) tuned mis-segmented name handling.
- **`_ensureChild`'s content-hash dedup is the model to copy, not the name-based dedup the audit once proposed for whole packs.** Within a pack it shares a child only when the text is byte-identical and otherwise mints `Name (Creature)` (**but byte-identical text does not mean the same name** — see F-pass0-17 above); measured over the shipped assets that yields 905 legitimately-shared rows and **zero orphaned** `creature-action`/`trait` rows. Across packs the same names are 90% *different* text, which is why [[dupe_census]] section B is not a deletion list for these categories. The qualified names it mints are also why a cross-pack softRef must never rely on [[entity_ref]]'s qualifier-stripping fallback — [[gate_packs]]' `qualifier-strip` rule now asserts that no ref does (corpus-wide 0).
