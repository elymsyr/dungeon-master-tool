# Open5e Chargen — Mechanical Wiring Roadmap

Upgrade the imported **class / subclass / species / background / feat** package
entities from *descriptive-only* reference cards to *mechanically-typed* content,
filling the schema's typed fields from Open5e source. Driven by the audit
(2026-06-01): content integrity is perfect (counts exact, folding correct, 0
dropped/dup) but typed required fields were empty by the original descriptive
policy. User decision: **complete each gap, step by step.**

Mapper: `tool/open5e_import/mappers/chargen.dart`. Each phase = mapper edit +
golden in `test/monster_mapper_check.dart` + rebuild + coverage verify +
`dart analyze` (0 issues). Severity note: `required_` is enforced only in the
template editor + rule_validator, **not** install/import — so partial coverage
never blocks install/render; it just fills more of the card.

## Phases

| Phase | Scope | Source form | Status |
|---|---|---|---|
| **C1** | feat `category_ref` | structured `type` (GENERAL/Origin/Fighting Style/Epic Boon) | ✅ DONE |
| **C2** | species `size_ref` / `speed_ft` / `creature_type_ref` | `Size`/`Speed` trait rows + subspecies inherit; Humanoid default | ✅ DONE |
| **C3** | species `granted_senses` (Darkvision) / `granted_languages` | named trait rows | ✅ DONE |
| **C4** | species `granted_modifiers` (ASI) | "X score increases by N" → typed modifier DSL | ✅ DONE |
| **C5** | background `granted_skill_refs` / `ability_score_options` / `granted_language_count` / `asi_distribution_options` | benefit rows keyed by `type` (text parse) | ✅ DONE |
| **C6** | subclass `parent_class_ref` | `subclass_of` — in-pack `ref` only (SRD ships base + subs); else descriptive | ✅ DONE |
| **C7** | class `armor_training_refs` / `weapon_proficiency_categories` | structured `Proficiencies` feature (`**Armor:** …`) | ✅ DONE |

## Coverage achieved (final, all 22 packs)

| Type (n) | Field | Coverage | Note |
|---|---|---|---|
| **feat** (91) | category_ref | **91/91** | General 76, Origin 4, Fighting Style 4, Epic Boon 7 |
| **species** (63) | creature_type_ref | **63/63** | Humanoid default |
| | size_ref | 37/63 | rest: no Size trait + no parent |
| | speed_ft | 43/63 | rest: no Speed trait + no parent |
| | granted_senses | 19/63 | = species carrying a Darkvision trait |
| | granted_languages | 19/63 | = species carrying a Languages trait |
| | granted_modifiers (ASI) | 49/63 | rest: no ASI trait or "of your choice"-only |
| **background** (58) | granted_skill_refs | 56/58 | 2 are "choose any" (no fixed skills) |
| | ability_score_options | 31/58 | SRD-2024 + A5e backgrounds |
| | granted_language_count | 32/58 | |
| | asi_distribution_options | 4/58 | only SRD-2024 (3-ability +2/+1 ⟂ +1/+1/+1); A5e single-ability rule → none |
| **subclass** (125) | parent_class_ref | 28/125 | in-pack SRD subs (srd-2014 12, srd-2024 12, a5e 3, bfrd 1); 97 built-in parents left empty |
| **class** (26) | hit_die / saving_throw_refs | 26/26 | |
| | caster_kind | 15/26 | rest: caster_type unset in source |
| | armor_training_refs / weapon_proficiency_categories | 11/26 | SRD-2014 classes whose profs are category-based; SRD-2024 uses a different feature format (none parsed); specific-weapon-only classes correctly yield no category |

Integrity preserved: 363 chargen entities unchanged, 0 unresolved refs, `dart analyze` 0 issues, self-check all green.

## Parsing rules (correctness-first)

- **size:** prefer SRD phrasing `your size is X`; else accept a lone size keyword, but **skip if >1 distinct size word** appears (avoids wrong guess on "Small or Medium").
- **speed:** first `N feet`/`N ft` measurement in the Speed trait.
- **subspecies inheritance:** a subspecies with no own Size/Speed trait inherits the parent species' parsed value (parent always in the same pack).
- **creature type:** default Humanoid (5e default for playable species).
- **ASI:** explicit "X score increases by N" → `{kind: ability_score_bonus, ability, value}`; "ability scores each increase by N" → all six; "of your choice" left to folded text.
- **background grants:** keyed off the benefit `type` (skill_proficiency / ability_score / language); explicit comma/"and" lists become ref lists, "of your choice" yields nothing. Tool profs + origin feat skipped (content-entity refs that would dangle outside the pack).
- **subclass parent:** ref emitted only when the base class ships in the same pack (SRD); built-in parents (toh/a5e) stay descriptive (header + tag).
- **class profs:** parsed from the `**Armor:**` / `**Weapons:**` lines of the SRD `Proficiencies` feature; "All armor" expands to Light+Medium+Heavy; "None" / specific-weapon lists yield no category.

## Known source limits (cannot fill without inventing data)

- class `primary_ability` — empty for all 26 base classes in Open5e v2.
- class profs for **SRD-2024** classes — 2024 restructured the Proficiencies feature (no `**Armor:**` markdown), so none parse; SRD-2014 format only.
- subclass parent link for **non-SRD** packs — parent class is built-in, not shipped in the pack (dangling ref risk).
- background **tool profs / origin feat / equipment / gold** — content-entity refs or free prose; left in folded text.
- typed **leveled class features** (`features` DSL) + spell lists — ClassFeature rows are freeform prose with no structured level field; kept as folded `description`.

---

# Phase D — completing the remaining gaps (2026-06-01)

Follow-up to C1–C7: finish the still-empty *consumed* fields and audit for any
field never wired. An in-app consumption audit confirmed most typed chargen
fields are read by `CharacterResolver` / `level_up_planner.dart` (not cosmetic),
so filling them wires real mechanics onto the sheet. Two user decisions framed
the work: **source-only** (no curated 5e tables — `primary_ability` and subclass
`granted_at_level` stay empty) and **soft name-refs ON** for cross-pack grants.

## `softRef` — the cross-pack reference mechanism

`softRef(slug, name) → {'slug': slug, 'name': name}` (no `_ref` key). The build's
`PackBuilder.resolveRefs` only rewrites maps where `_ref` is a String, so a
softRef passes through untouched (**build stays 0-unresolved**); the import
`_lookup` pass ignores it; and `CharacterResolver._resolveRef` reads
`raw['_ref'] ?? raw['slug']` and name-resolves it at runtime against all
installed content (clean no-op if the target pack isn't installed). Used for
subclass→built-in base class, species→spell, background→origin feat.

## Phases

| Phase | Scope | Form | Status |
|---|---|---|---|
| **D1** | species `granted_damage_resistances` / `_immunities` / `_vulnerabilities` | `resistance/immune/vulnerable to X damage` trait prose (Tier-0, case-insensitive) | ✅ DONE |
| **D2** | species `granted_condition_immunities` | explicit `immune to`/`can't be [condition]` only | ✅ DONE |
| **D3** | species `granted_skill_proficiencies` | `(gain/have) proficiency in the X skill` (excludes conditional "considered proficient") | ✅ DONE |
| **D4** | species alt speeds `speed_fly_ft`/`_swim_ft`/`_climb_ft`/`_burrow_ft` | `<mode> speed of N feet`, conditional/temporary grants skipped | ✅ DONE |
| **D5** | subclass `parent_class_ref` → **125/125** | in-pack hard `ref` (28) + cross-pack `softRef` (97) | ✅ DONE |
| **D6** | feat `prerequisite` + `prereq_ability_ref`/`prereq_min_score`/`prereq_min_character_level` | direct `prerequisite` field copy + parse of `[Ability] N`, `Nth level` | ✅ DONE |
| **D7** | class `skill_proficiency_choice_count` / `_options` | SRD-2014 `**Skills:** Choose two from …` line | ✅ DONE |
| **D8** | class `caster_kind` → **26/26** | source `caster_type`, else **inferred from feature rows** | ✅ DONE |
| **D9** | species `granted_spell_refs`/`_cantrip_refs` + background `origin_feat_ref` | `cast/know the <Name> spell/cantrip`; bg `feat` benefit row | ✅ DONE |

## D8 caster_kind — feature inference (not a curated table)

Open5e leaves `caster_type` **null for the entire SRD-2014 set** (Wizard, Cleric,
Bard, Druid, Sorcerer, Paladin, Ranger, Warlock all null) — a blind `null → None`
default would mark Wizard a non-caster. Instead, when `caster_type` is null,
`_inferCasterKind` reads the class's own feature rows (source-derived, no class
table): **Pact Magic** → Pact; no spell feature → None; spellcasting **with** a
"Cantrips Known" feature → Full; spellcasting **without** cantrips → Half. Yields
the correct kind for all 11 SRD-2014 classes (Wizard/Cleric/Druid/Sorcerer/Bard =
Full, Paladin/Ranger = Half, Warlock = Pact, Fighter/Monk/Rogue = None).

## Coverage achieved (all 22 packs, after D)

| Type (n) | Field | Coverage | Note |
|---|---|---|---|
| **class** (26) | caster_kind | **26/26** | 15 from source + 11 inferred (SRD-2014) |
| | skill_proficiency_choice_count / _options | 14 / 13 | SRD-2014 Proficiencies feature only |
| | armor_training_refs / weapon_proficiency_categories | 11 / 11 | (unchanged from C7) |
| | primary_ability_ref | 0/26 | empty in source — source-only decision |
| **subclass** (125) | parent_class_ref | **125/125** | 28 in-pack uuid + 97 soft name-ref |
| **species** (63) | granted_damage_resistances | 11/63 | = species with a typed-damage resistance trait |
| | granted_damage_immunities / _vulnerabilities | 0 / 0 | no species grants a typed damage immunity/vuln in source |
| | granted_condition_immunities | 0/63 | source uses "advantage on saves vs", not immunity |
| | granted_skill_proficiencies | 15/63 | fixed skill grants only (conditional excluded) |
| | speed_swim_ft / speed_burrow_ft | 1 / 1 | only 2 species carry an innate alt speed |
| | speed_fly_ft / speed_climb_ft | 0 / 0 | only fly mention is Dragonborn's conditional L5 flight (skipped) |
| | granted_cantrip_refs / granted_spell_refs | 7 / 6 | in-pack spell → uuid, else soft name-ref |
| **background** (58) | origin_feat_ref | 4/58 | SRD-2024 `feat` benefit rows (soft name-ref) |
| **feat** (91) | prerequisite | 44/91 | raw text of the `prerequisite` field |
| | prereq_ability_ref / prereq_min_score | 10 / 10 | parsed `[Ability] N` |
| | prereq_min_character_level | 12/91 | parsed `Nth level` / `level N` |

Integrity preserved: 363 chargen entities unchanged, **0 unresolved refs**,
`dart analyze tool/open5e_import` 0 issues, self-check (incl. 20 new D-goldens)
all green.

## D-phase parsing rules (correctness-first)

- **damage / condition / skill matching** is case-insensitive against the Tier-0
  canonical names (`Normalizer.namesFor`), anchored to explicit grant phrasing so
  "fire **damage** dealt by an action" or "**advantage** on saves vs charmed" is
  never mistaken for a grant.
- **alt speeds** require `<mode> speed of N feet` and skip any trait mentioning a
  bonus action / "when you reach" / timed duration / "until you" (conditional
  flight is not a base speed).
- **innate spells** require the article ("cast **the** X spell") to avoid the
  generic "cast a spell"; in-pack spell → hard `ref` (uuid), else `softRef`.
- **feat prereq** keeps the raw text and parses a single ability+score (the field
  is single-valued, so a multi-ability "or" prereq keeps the first) and a level.

## Source limits confirmed empty (honest, not faked)

- `granted_damage_immunities` / `_vulnerabilities` / `granted_condition_immunities`
  / `speed_fly_ft` / `speed_climb_ft` — **no species in the 22 packs** carries the
  source phrasing for these; the fields are wired and tested but have no rows.
- class `primary_ability` (empty in source), subclass `granted_at_level` (no level
  field on ClassFeature → resolver default 1), leveled class `features` DSL + spell
  lists (freeform prose, no level field) — all unchanged source limits, kept folded.
