---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/monster.dart
layer: tool
language: dart
status: stable
updated: 2026-08-19
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

> [!success] R2 — canavar aksiyon sadakati (2026-08-19)
> On bir bulgu bu dosyada kapandı. Yeni kurallar:
> - `_ensureChild`'ın içerik-hash'ine **ad** katıldı (F-pass0-17) — metni
>   birebir aynı iki farklı silah artık tek kartta birleşmiyor.
> - `is_attack`, attack fixture'ı yoksa satırın kendi metnindeki
>   *"Melee/Ranged … Attack:"* açılışını okuyor (F-pass0-25, `_descIsAttack`).
> - `_primaryDamageType`: `damage_type` boş **ve** `extra_damage_die_type` de
>   boşsa `extra_damage_type` **birincil** tiptir (F-pass0-18).
> - `_formQualified`: `limited_to_form` upstream'in kendi geleneğiyle
>   `desc`'in başına `(Skunk Form Only) ` diye yazılıyor (F-pass0-21).
> - `_collapsedColumn`: bir belgenin `alignment` sütunu tek değere çökmüşse
>   (`n_distinct == 1 && n_rows > 20`) alan **hiç yazılmıyor** (F-pass0-26);
>   [[verify_packs]] aynı kuralı öğrendi, yoksa düzelmiş kart `absent` okur.
> - `_costsActionsName`: aynı ebeveynde aynı metinli `LEGENDARY_ACTION` varsa
>   `… (Costs N Actions)` adlı `ACTION` satırı atlanıyor (F-pass0-22).
> - `legendary_action_uses` v1 `legendary_desc` düzyazısından geliyor, yoksa
>   SRD varsayılanı 3 (F-tob-01; indeks [[build_packs]]'te).
> - `_repairRow` üç onarımı tek yerde topluyor: `_fixEscapes` (F-pass0-27, `æ`
>   + dört hex → hex'in adlandırdığı karakter; [[gate_packs]]'e
>   `escape-residue` kuralı eklendi), v2 kesikse v1'in **önek olan ve belirgin
>   uzun** kopyası (F-tob-2023-01), ve `desc` boşken kuralı `name`'den alıp
>   kısaltılmış başlıkla yayımlama (F-a5e-mm-01).
> - **v1 kurtarması artık satır bazında** ve **metinle** eşleşiyor
>   (F-pass0-24): kova dolu olsa da metni hiçbir çocukta olmayan v1 satırı
>   yayımlanıyor. Ölçüm bulgunun 11'i değil **tob3 dışında 161** çıktı — aynı
>   kusurun aynı biçimi (v2 yalnız efsanevi kısayolu çevirmiş).
>
> Ölçüm: 8 canavar paketinde **5.397 değer**, net **+346 varlık**;
> `verify_packs` 0 disagree / 0 absent, `unsourced` 3.303 sabit; `gate_packs`
> yeşil; `dupe_census` 0. Testler: `test/tool/monster_fidelity_test.dart` (24)
> + `creature_action_fallback_test.dart` (yeniden yazıldı), `test/tool/`
> **158/158**. `assets/open5e_packs/` promote **edilmedi**.

- **Action split by `action_type`**: BONUS_ACTION → `bonus_action_refs`, REACTION → `reaction_refs`, LEGENDARY_ACTION → `legendary_action_refs` (+ `legendary_action_uses: 3` SRD default since Open5e omits the count — **measured against v1 on 2026-08-18**: `cc`'s `legendary_desc` says "can take 3 legendary actions" on 20/20 and `tob2`'s on 9/9, and corpus-wide only **2** rows disagree, both in `tob` — **filed 2026-08-18 as F-tob-01, fixed by R2 2026-08-19**, cause `M`: `Jotun Giant` and `Zmey` say "can take 1", and `Vampire Warlock - Variant` states no count at all, yet all three ship `3`; the preamble sentence itself never reaches the pack, so the card cannot be checked against it. **Widened 2026-08-19 by the `a5e-mm` unit:** the v1 sweep could not see `a5e-mm`, which has no v1 document and puts the count in a v2 `CreatureAction.name` (*"The aboleth can take 2 legendary actions"*) — **16 of 66** declarations there contradict the constant, so the record is corpus-wide at **19**), LAIR_ACTION → `lair_action_refs`, else `action_refs` (always present, schema-required).
  - ✅ **`open5e-tob3`'s empty Actions block was never this switch's fault** (audit **B8**, fixed 2026-07-31). The pack shipped **2** `action_refs` against 136 bonus / 96 reaction / 75 legendary, and the natural reading was a mis-set enum. The pinned snapshot says otherwise: `tob3/CreatureAction.json` genuinely holds 309 rows for 397 creatures with 2 `ACTION` among them, and the three non-`ACTION` buckets match `v1/tob3/Monster.json` **row for row** (136 / 96 / 75). Upstream's v2 conversion dropped one column; the mapper was faithful. Nothing caught it — the refs that existed all resolved, so the build gate passed, and the per-field census still read `action_refs` as "filled". **[[gate_packs]] is that gate, and it shipped 2026-08-10**: `monster-actionless` plus `bucket-skew` ("the base action bucket cannot be outnumbered by the situational ones"), run by [[build_packs]] over its own output.
- **v1 action backfill** (audit **B8**): after the v2 loop, any of the four buckets **left entirely empty for this creature** is filled from `v1Actions[rawName.toLowerCase()]` through the *same* `_cleanChildName` + `_ensureChild` path, so recovered rows inherit the sanitizer, the content dedup and the `Name (Creature)` disambiguation.
  - **F-pass0-24 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `M`):** "entirely
    empty" is the wrong granularity. A bucket v2 converted **partially** is not
    empty, so the v1 rows behind it are never read — and B8's write-up puts the
    cost of that at "one monster: Abaasy". Measured by **text** across the
    corpus (name comparison is unusable here — see F-pass0-17) the real cost is
    **11 actions on 10 creatures**: `tob-2023` 5, `tob` 3, `tob3` 3. The Red Hag
    ships with no `Multiattack`; the Tosculi Hive-Queen's *Glitter Dust*
    survives only as the legendary shortcut *"The hive-queen uses Glitter
    Dust"*, the action itself is nowhere. B8's argument against the loose
    name-based rule (~2,000 duplicate rows) is untouched — a text-equality
    trigger recovers the 11 without it. Do not "fix" this by loosening to names.
  - **Empty-bucket-only is the safety argument, and it is measured.** The looser "add any v1 row whose name is absent" rule would add **~2,000 rows corpus-wide** — v1 and v2 disagree about action *names*, not about which actions exist, so it would ship duplicates dressed as recoveries. The conservative rule's whole cost is one monster (Abaasy, the single tob3 creature v2 partially converted, keeps 2 and forgoes 5).
  - The join key is the **raw** upstream name, not `_cleanMonsterName`'s output — that is what reaches tob3's 15 `Npc: …` monsters.
  - `_v1ActionRow` emits prose only: v1 has no `CreatureActionAttack` equivalent, so `attack_bonus`/`damage_dice`/`attack_kind` are absent rather than reverse-engineered out of the text. tob3 ships no attack fixture at all, so nothing is lost. The visible consequence is that `creature-action.attack_kind`/`damage_dice` *shares* fall (41%→35%, 40%→34%) while their absolute counts are unchanged.
  - Result on the rebuild: `monster.action_refs` **86% → 99.8%** (2880/2885), tob3's actionless monsters **396 → 1**. Tests: `flutter_app/test/tool/creature_action_fallback_test.dart` (8 cases).
- **`tags_line` comes from **v1**, not from splitting `type`** (audit B5, 2026-08-14). `_creatureType` does split `"humanoid (elf)"` correctly, but that form occurs on **0 of 3,541** v2 `Creature.type` rows — the v2 conversion moved the subtype into its own column and then dropped it. `mapCreatures(v1Subtypes:)` takes a `lowercased name → subtype` map built by [[build_packs]]' `_v1SubtypeIndex` from `v1/<doc>/Monster.json`, keyed by the same `_v1DocForCreatures` map B8's action backfill uses. **A v2 tag always wins**, so the backfill can never override a sourced value. 292 of 2,885 shipped monsters carry one; pinned by `test/tool/monster_tags_line_test.dart`.
- **`damage_type_ref` is 0% and cannot be fixed here** (audit B5). The mapper reads and resolves `CreatureActionAttack.damage_type`; all 576 source rows that carry one are in `srd-2014`/`srd-2024`, which [[build_packs]] skips publisher-wide. Every attack row in a shipping document is null. Don't "fix" the mapper — there is nothing to read.
  - **F-pass0-18 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `M`):** the "nothing
    to read" half is wrong — only the *column that is read* is empty. When an
    attack row has no genuine extra damage (`extra_damage_die_type` null), the
    neighbouring `extra_damage_type` holds the **primary** damage type:
    **3,479 rows in shipping documents** (`a5e-mm` 828, `tob` 652, `bfrd` 512,
    `tob2` 506, `tob-2023` 505, `ccdx` 473, `tdcs` 3). The column is overloaded
    rather than ambiguous — the other 828 filled rows all carry a real second
    damage, which has no schema counterpart at all.
- **`trait_kind` is hardcoded `Other` on every trait row, and that is correct** (audit V1, 2026-08-14; **re-read against `ccdx`, `tob2`, `tob` and `tob3` 2026-08-18** — `CreatureTrait.type` is null on 1,016/1,016, 1,060/1,060, 1,123/1,123 and 1,230/1,230 there, so the constant is honest). `CreatureTrait.json` carries a `type` column but it is **null on all 8,613 rows in every document** in the pinned snapshot, so there is nothing to map. Do not "improve" this by classifying the trait's name or `desc` into the schema's six-value enum — that invents a field upstream does not have, which is exactly the `hp_dice` fabrication audit phase B11 was filed to remove. The cost is a `trait_kind` filter that cannot discriminate; that is a schema question, not a mapper one.
- **Alignment is three-way, and only one branch gets the relation** (audit **B10**, 2026-08-14). `_alignment` routes `Creature.alignment` by shape: one of the nine canonical values → `alignment_ref`; anything else that contains an alignment word (`any|lawful|chaotic|neutral|good|evil|unaligned`) → **`alignment_note`** prose beside a *null* ref; neither → dropped and logged to the [[normalize]] sink. None of the 29 free-text expressions upstream (`any alignment`, `chaotic neutral or chaotic evil`, `Neutral Evil (50%) or Lawful Evil (50%)`) reduce to a canonical value, so a synonym normalizer would have converted 0 of 70 — and picking one arm of an "or" is the `hp_dice` fabrication again. The third branch is exactly the three rows corrupt in `Creature.json` itself (`Titan)`, `Shapechanger)` ×2), which must not be laundered into a prose field. 67 monsters carry a note; `unmapped_report.json` 70 → 3. **Re-measured 2026-08-19 by the `tob-2023` unit and confirmed**: those 3 rows are *the whole file*, all `tob-2023`'s, corrupt in v1 too; the document's other 13 unmatched values reach `alignment_note` losslessly, and its `alignment` column carries **21** distinct values, so F-pass0-26 does not spread here. Pinned by `test/tool/monster_alignment_test.dart`.
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
  - **F-pass0-23 (F3 / Dalga 4, 2026-08-18, ❓ open, cause `M`):** `senses` is
    built from four v2 columns only (`darkvision_range`, `blindsight_range`,
    `tremorsense_range`, `truesight_range`) and the Tier-0 `sense` canon
    (`lookups.dart` `_senseCategory`) holds those same four rows, so a sense
    named anywhere else is dropped. Black Flag replaced darkvision with
    **keensense** and its v2 `Creature.json` has no `darkvision_range` column at
    all: **90** `bfrd` creatures lose their only sense, **41** of them shipping
    an empty `senses` list. With `tob`'s 6 (*blood sense*, *blindsense*,
    *devil sight*, *impaired sight*) and `ccdx`'s 1 that is **97** creatures.
    The value is in v1 `Monster.senses`, the same file already read for
    `tags_line`.
- **Child dedup** (`_ensureChild`): content-hashed (`type|description|sorted-attrs`) so identical actions/traits across creatures are authored once; name collisions on different content are disambiguated with ` (CreatureName)` / ` (CreatureName N)`.
  - **F-pass0-17 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `D`):** **the name is
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
    `_contentHash` costs ~457 extra entities corpus-wide. *(Count corrected
    twice: **382 → 487** by the `tob3` unit — the recipe read v2 only and
    `tob3`'s 1,370 actions come from v1 — then **487 → 457** by the `a5e-mm`
    unit, where 30 of the 106 hits turned out to be an artefact of matching an
    **empty** `desc` against the pack's one empty-description entity; on
    non-empty rows the loose and parent-scoped methods agree, 76 ⟷ 76.)*
- **v2 is read; v1 is only a fallback — and v1 is sometimes the *better* copy.**
  B8's recovery fills a bucket v2 left **entirely** empty; it never repairs a v2
  row that exists but is wrong. Two 2026-08-19 findings live in that gap.
  - **F-tob-2023-01 (F3 / Dalga 4 — **fixed by R2, 2026-08-19**, cause `S`+`M`):** Mirror Hag's
    *Reconfiguring Curse* is 1,030 characters in `v1/tob-2023/Monster.json` and
    **333** in v2 — v2 stops exactly where the four named curses (Disfigured,
    Sickly, Twisted, Withered, all mechanical) begin, and the card ships v2.
    A corpus-wide v1 ⟷ v2 length sweep finds **exactly one** such row.
  - **F-pass0-27 (F3 / Dalga 4 — **fixed by R2, 2026-08-19**, cause `S`+`M`):** v2 half-decoded some
    unicode escapes (`\u00e600e6`), and the residue reaches the card —
    **8 cards / 3 packs**: `væ00e6ttir` (`tob-2023`, 3 descriptions + one card
    **name**), `collæ00e1is` (`tob2`, 2), and `tob3`'s two numeric rows where
    `×` became `æ00d7` (*"2æ00d7 damage dice"*). v1 is clean in all three.
    No gate sees either one: [[verify_packs]] compares the card against **v2**,
    so a faithful copy of a broken row is `ok`.
- **`legendary_action_cost` is never read** (**F-pass0-28**, F3 / Dalga 4,
  2026-08-19, ❓ open, cause `D`+`M`). The column has no `creature-action`
  schema field and no reader in `tool/` or `lib/`. Of **267** corpus rows
  costing 2 or 3 actions, **152** lose the cost, so the card reads as a 1-cost
  legendary action. Survival is accidental: when B8 recovers the row from v1 the
  cost rides along inside the name (`Tail Attack (Costs 2 Actions)`), which is
  why the distribution follows the recovery and not the source — `bfrd` 59/59
  and `tob2` 13/13 kept, `a5e-mm` 52/52 and `tob-2023` 52/52 lost. Distinct from
  **F-pass0-22** (the *duplicate* legendary row) and **F-tob-01** (the per-turn
  `legendary_action_uses` count).
- **Name sanitization** (Open5e scraper mis-segments stat blocks): `_cleanMonsterName` strips `Npc:` prefix + re-cases small-words. `_cleanChildName` drops trailing periods, lifts roll-table range rows (`1-4: Arm`→`Arm`), recovers a label from desc for purely-numeric names, strips leading list-counts and leaked attack clauses, reduces `Label: effect sentence`→`Label` (gated), and DROPS clearly-spurious full-sentence fragments (`_looksLikeSentenceFragment`: ≥4 lowercase-initial words, multiple sentences, or legendary-action preamble) — returning null skips the ref so no orphan ships.
  - **F-a5e-mm-01 (F3 / Dalga 4, 2026-08-19 — **fixed by R2, 2026-08-19**, cause `M`):** in
    `open5e-a5e-mm` the mis-segmentation runs the *other* way — the rule text is
    in `name` and its continuation in `desc` — so the fragment guard drops the
    row and its rule ships nowhere: **57 rows on 41 monsters**, 19 of them
    mechanical (Gelatinous Cube's escape DC, Medusa's DC 14 petrification).
    30 of the 57 have an **empty** `desc` (the corpus's only such rows); 5 of
    those survive the `Label: sentence` reduction as `Luck` but carry no text,
    and `_ensureChild` folds all five into one card that 3 monsters reference —
    the corpus's only child entity with an empty `description`. Measuring this
    requires counting **soft refs** as present: L1 hands 9 `a5e-mm` and 6
    `bfrd` rows to the built-in, and `bfrd`'s child side is otherwise
    **lossless** (2,519/2,519).
- **`hp_dice` is copied or absent, never invented** (audit **B11**, fixed 2026-08-10). `_monsterRow` used to write `hit_dice ?? '1d4'`, and `open5e-bfrd` has `hit_dice: null` on **all 360** of its creatures — so that pack shipped a `1d4` die pool next to a 165-HP Aboleth's own `hp_average`. Neither census could see it (`hp_dice` was a filled string on every row of every pack, so [[audit_packs]] read 100% and the corpus-wide-constant ⚠ could not fire); [[verify_packs]]' `unsourced` column is what caught it. Of the two honest shapes, **omit** was chosen over deriving from `hp_average` + CON + size — a derivation is inference, not source, and would owe an `unverifiable` rule declaring the field unmeasurable. Rebuild effect: 360 removals, **all in `open5e-bfrd`**, no other pack moved; corpus `unsourced` 3,663 → 3,303. Tests: `flutter_app/test/tool/monster_hp_dice_test.dart` (4 cases).
- **`alignment_ref` is copied, and in two documents the copy is a constant.**
  - **F-pass0-26 (F3 / Dalga 4, 2026-08-19 — **fixed by R2, 2026-08-19**, cause `S`):** v2
    `Creature.alignment` is `"chaotic evil"` on **946/946** rows of `a5e-mm` +
    `bfrd` — the other eight documents carry 10–21 distinct values — so every
    monster in those two packs, Pixie and Unicorn included, ships as
    `Chaotic Evil`. The mapper is faithful and [[verify_packs]] passes it; the
    right answer is not elsewhere in the source either (`bfrd`'s v1 `alignment`
    is empty on 360/360, `a5e-mm` has no v1). The field is optional, so
    silence — or `alignment_note` — was available.
- **Stat derivation**: `_crString` maps decimals to fractions (0.125→`1/8`); `_profForCr` and `_xpByCr` (full CR→XP table 0..30) backfill proficiency bonus + XP when Open5e omits them. `_saveTable`/`_skillTable` reconstruct proficiency tables by back-solving `misc = bonus - abilityMod - PB`.
- Attack mapping (`_actionRow`): derives `attack_kind` (Melee/Ranged × Weapon/Spell from reach/range/attack_type), `damage_dice` (`XdY±Z`), recharge (`RECHARGE_ON_ROLL`→`recharge_min_roll`, `PER_DAY`→`uses_per_day`).
  - **F-pass0-25 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `M`):** `is_attack`
    is written as `attack != null` (and hardcoded `false` on the v1 recovery
    path), i.e. "no `CreatureActionAttack` row" is published as the positive
    claim *"not an attack"*. `tob3` has **no attack fixture at all**, so the
    field is `false` on 1,577/1,577 there and `audit_packs` prints `⚠ const`;
    **634** of those rows begin *"Melee Weapon Attack: +N to hit"*. Corpus-wide
    **681** rows in 5 packs (`tob3` 634, `a5e-mm` 32, `tob` 10, `tob-2023` 3,
    `tob2` 2). The empty `attack_kind`/`attack_bonus`/`damage_dice`/`reach_ft`
    next to it are a different thing: those are honest blanks with a written
    reason (§6 B8, cause `S`). The schema field is a plain boolean, so there is
    no "unknown" to write — deriving `true` from the row's own text is the only
    fix that invents nothing.
  - **F-pass0-21 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `M`):** `_actionRow`
    never reads `CreatureAction.limited_to_form`, so a shapechanger's form-locked
    attack ships unconditional — Aniwye's `Rock` (*Giant Form Only*) and
    `Bite`/`Claw` (*Skunk Form Only*) all render as always-available. The column
    is filled on **262** corpus rows (**218** shipping; `a5e-mm` 60,
    `tob-2023` 48, `bfrd` 37, `tob2` 30, `ccdx` 24, `tob` 18, `tob3` 1) and only
    **1** of them repeats the qualifier in `desc`; a separate 13 rows carry it
    only in `desc`, and those do reach the card. `legendary_action_cost` (29 rows
    in `tob2`) is the harmless neighbour — no schema field, but the action name
    already says *"(Costs 2 Actions)"*.
  - **F-pass0-22 (F3 / Dalga 4, 2026-08-18 — **fixed by R2, 2026-08-19**, cause `S`):** that name is
    the other half of the story. Upstream emits the same legendary action
    **twice** — once `LEGENDARY_ACTION` with `legendary_action_cost`, once
    `ACTION` named `… (Costs N Actions)` — and since `_contentHash` includes the
    type, both survive; the parent refs both, so `action_refs` offers a
    legendary action at will (`Aboleth, Nihilith` → `Psychic Drain (Costs 2
    Actions)`). **114 rows** (`bfrd` 58, `ccdx` 24, `tob` 19, `tob2` 13), each
    matching a same-parent, same-text legendary row with the same cost.

## Notes
- Largest mapper (~24KB). The name-sanitization heuristics are deliberately conservative (real titles like "Keen Hearing and Smell" pass through). Two recent commits (323924a, ac2d186) tuned mis-segmented name handling.
- **`_ensureChild`'s content-hash dedup is the model to copy, not the name-based dedup the audit once proposed for whole packs.** Within a pack it shares a child only when the text is byte-identical and otherwise mints `Name (Creature)` (**but byte-identical text does not mean the same name** — see F-pass0-17 above); measured over the shipped assets that yields 905 legitimately-shared rows and **zero orphaned** `creature-action`/`trait` rows. Across packs the same names are 90% *different* text, which is why [[dupe_census]] section B is not a deletion list for these categories. The qualified names it mints are also why a cross-pack softRef must never rely on [[entity_ref]]'s qualifier-stripping fallback — [[gate_packs]]' `qualifier-strip` rule now asserts that no ref does (corpus-wide 0).
