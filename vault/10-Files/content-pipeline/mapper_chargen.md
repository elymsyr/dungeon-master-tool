---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/chargen.dart
layer: tool
language: dart
status: stable
updated: 2026-07-31
tags: [file]
---

# `mappers/chargen.dart`

> [!abstract] Primary Purpose
> Maps the v2 Open5e character-build documents — `CharacterClass`(+ClassFeature), `Species`(+SpeciesTrait), `Background`(+BackgroundBenefit), `Feat`(+FeatBenefit) — onto the app's `class` / `subclass` / `species` / `subspecies` / `background` / `feat` entities. The largest mapper (~50KB): besides folding child rows into the parent's description markdown, it parses every typed schema field the `CharacterResolver` can consume (ASI, granted skills/senses/languages, damage resist/immune/vuln, condition immunity, alt speeds, caster kind, prereq clauses, innate spells, equipment choice groups, subclass/subspecies parent links). These are not mere reference cards.

## Inputs / Outputs
**Inputs**
- `mapClasses`, `mapSpecies`, `mapBackgrounds`, `mapFeats` — each takes `(pack, norm, source, <parent fixtures>, <child fixtures>)` from [[loaders]]. `mapClasses` also takes `featureItems` (`ClassFeatureItem.json`, optional — defaults to `const []`, so a document without it maps as before).
- `mapSpecies` also takes `V1SpeciesIndex v1Traits` (audit **B3**) — `lowercased species name → [{name, desc}]`, built by [[build_packs]] from `data/v1/<doc>/Race.json`. Defaults to `const {}`, which is the exact pre-B3 behaviour.

**Outputs**
- Adds `class` / `subclass` / `species` / `subspecies` / `background` / `feat` (and synthesised `adventuring-gear`) entities to the `PackBuilder` ([[refgraph]]).

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]], [[refgraph]], [[srd_helpers]] (`packEntity`, `lookup`, `ref`, `eqGroup`/`eqOption`/`eqItem`).
- Used by: [[build_packs]].
- Resolved at runtime by: `character_resolver` (consumes the typed grants).
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]], [[Open5e-API]]

## Key Logic / Variables
- **Three ref kinds**: `lookup()` (Tier-0, resolved at import), `ref()` (hard in-pack, resolved at build — build FAILS if unresolved), and `softRef(slug, name)` = `{slug, name}` with NO `_ref` key (cross-pack; PackBuilder leaves it intact, `CharacterResolver._resolveRef` name-resolves it at resolve time, clean no-op if the target pack isn't installed). softRef is used for subclass→built-in base class, species→spell, subspecies→parent species, background→origin feat.
- **Classes** (`mapClasses`): base classes (`subclass_of == null`) → `class`; rest → `subclass` with `parent_class_ref` (hard `ref` when parent ships in-pack, else `softRef`). Caster kind = Open5e `caster_type` if set, else `_inferCasterKind` from feature rows (Pact Magic→Pact, no spell feature→None, has "Cantrips Known"→Full, spellcasting w/o cantrips→Half — Open5e leaves `caster_type` null for the whole SRD-2014 set). C7: armor/weapon/skill proficiencies parsed from the structured `**Armor:**`/`**Weapons:**`/`**Skills:**` Proficiencies feature ("all armor"→Light+Medium+Heavy).
- **Species/Subspecies** (`mapSpecies`, 3-pass): pass 1 parses Size/Speed from trait rows; pass 2 lets subspecies inherit absent parent values; pass 3 emits with typed grants — D1 damage resist/immune/vuln (regex on "X damage"), D2 condition immunity (explicit immunity phrasing only), D3 fixed skill prof, D4 innate alt speeds (skips conditional/temporary), D9 innate spell/cantrip grants, ASI (`_parseAsi`: fixed bonuses, "each" grants all six → the `ability_bonuses` statBlock map `{'CON': 2}`). Subspecies → first-class `subspecies` entity with `parent_species_ref` softRef.
  - ✅ **Trait rows are matched by name, and that is not a shortcut** (audit **B3**, 2026-07-31). The audit long claimed the fix was to switch to `SpeciesTrait.type`. On the pinned snapshot that column is **null on 100% of the rows we ship** (`toh` 0/184, `open5e` 0/2); only `srd-2024` fills it (18/51), and the publisher-wide SRD skip never builds that document. There is no better key to switch to.
  - **v1 species backfill** (audit **B3**): a species v2 converted with **zero** trait rows gets them from `v1Traits`, reconstructed from v1 `Race.json`'s `***Name.***` markdown. Same all-or-nothing rule as [[mapper_monster]]'s B8 action backfill, so nothing v2 converted is ever overridden. Exactly one species needs it — `toh`'s **Shade** — and it lifts `granted_languages` to 100%.
  - **`size_ref` 63% / `speed_ft` 72% is an upstream hole, not a parser gap.** Four species say the subrace decides (Gearforged, Darakhul, Mushroomfolk, Shade) and **all 29 `toh` subraces carry ASI + flavour traits and no Size/Speed row**, which is also why subspecies sit at 33%/43% — they inherit from parents that defer. v1's structured `size_raw`/`speed_json` are default-filled and deliberately not read: see [[build_packs]].
  - **`_permanentClauses`** (audit **B3**) drops sentences scoped to an activated trait's duration ("During it, …") before the D1/D2 scans. Shade's Ghostly Flesh was granting bludgeoning/piercing/slashing resistance permanently at level 1 for a 3rd-level, 1/long-rest, 1-minute transformation. The filter is per **sentence**, so the unconditional necrotic resistance in the next trait still lands.
- **Backgrounds** (`mapBackgrounds`): benefit rows have **always** been keyed by `type` (`descOfType`) — the other half of B3's premise that did not survive. Rows → `granted_skill_refs`, `ability_score_options` (+`asi_distribution_options` `['+2/+1','+1/+1/+1']` for 3-ability SRD-2024; A5e "+1 and one other" widens to all six so the resolver's `background_asi` gate doesn't drop the floating pick), `granted_language_count`, `origin_feat_ref` softRef. Equipment: `_parseEquipmentChoiceProse` parses SRD-2024 A/B prose into structured `equipment_choice_groups`; `_fixedEquipmentGroup` is the A5e/Open5e fallback that synthesises minimal in-pack `adventuring-gear` entities (build-safe hard ref, grantable) for kit items that don't resolve.
- **`parseToolProficiencies`** (audit **B3**) turns the `tool_proficiency` benefit line into `granted_tool_refs` (softRefs, since tools are built-in cards) + `granted_tool_variant_group`. The canon is `srdTools()` itself, so a tool renamed in the built-in pack can't silently stop matching; matching is punctuation-insensitive (upstream writes `Cartographers’ tools` for `Cartographer's Tools`) with one auditable alias (`Herbalist kit`). **What it refuses to emit is the point** — both failure modes are silent:
  - an `or` makes every named tool an **alternative, not a grant** ("Your choice of one from Thieves' Tools, Forgery Kit, or Disguise Kit" names three real cards and grants none); only a single unambiguous family survives one;
  - **two families emit neither**, because `granted_tool_variant_group` is a single text field and picking the first would delete the second choice;
  - a family **absorbs its own members**, so `Gaming set, thieves' tools` yields the `gaming_set` group + a ref to Thieves' Tools, never the umbrella `Gaming Set` card;
  - vehicles match no card and no family (the SRD ships none) and stay in prose.
  - Result: `granted_tool_refs` **0% → 35%** (19/53), `granted_tool_variant_group` **0% → 22%** (12/53), 23 softRefs all resolving to the built-in pack. The three groups the wizard understands are fixed by `proficiencies_step._toolCategoryNameForGroup`.
- **Feats** (`mapFeats`): `category_ref` from `type`; `_parseFeatPrereq` builds `prereq_clauses` (ability_min with `ability_options` list, character_level, spellcasting, armor/weapon/skill proficiency) + legacy flat fields; `_isJunkPrereq` strips `N/A`/`None`/`-`; `_parseFeatAsi` handles SRD-2024 + A5e ASI phrasings; the feat-benefit parser emits only high-confidence unconditional grants into the named fields (`granted_armor_proficiencies`, `speed_bonus_ft`, Tough-style `hp_bonus_per_level: 2`); explicit "choose N skills/tools" prose becomes a `player_choices` row.
- **The level table** (`_levelFeatures`, audit phase **B1**, 2026-07-30). `ClassFeature` has no level; its child `ClassFeatureItem` does, keyed `parent` → the feature's pk. Two shapes share that file and only one is a granted feature: a **granted feature** has one item per level it arrives or improves at (`column_value == null`) and becomes a `classFeatures` row; a **class-table column** has 20 items each carrying a `column_value` (`Proficiency Bonus`, `Augment Effects Known`, spell slots) and is skipped — that is B2's typed `*_by_level` fields. **No shipped document mixes the two inside one feature**, which is what makes "every item has a `column_value`" a safe test rather than a heuristic. A feature that improves gets one row per distinct level; `detail` (`'2 dice'`, `'two attacks'`) is upstream's only distinguisher, so it carries the follow-up rows' description while the first keeps the prose. `subclass.granted_at_level` = the lowest level the subclass's own non-table features arrive at, absent when it has none. No grant refs are emitted — the prose names no entity we could resolve (B5).
- `_addUnique` disambiguates same-slug name collisions (3rd-party docs reuse generic subclass/feat names) by suffixing the parent tag or a counter.

## Notes
- ⚠️ **`assets/open5e_packs/` predates B1.** The mapper fills the level table; the shipped assets do not carry it, because promoting a rebuild is a separate decision (audit Stage D). `test/tool/class_feature_levels_test.dart` therefore drives the mapper directly — fixture → `mapClasses` → `CharacterResolver` — rather than reading a bundled asset, which could only prove the old emptiness. `bundled_pack_resolve_test` gains the asset-side assertion at promotion.
- ⚠️ **`assets/open5e_packs/` predates B3 too** — same scratch-only rule. `test/tool/chargen_b3_test.dart` (12 cases) drives `parseToolProficiencies` and `mapSpecies` directly; two are honesty guards (a species v2 converted is never overridden; with no v1 index the mapper behaves exactly as before).
- **One subclass will never have a level**: `Path of Hellfire` (`open5e-toh`) ships a `CharacterClass` row and zero `ClassFeature` rows upstream. 100 of 101, and the 101st is a source hole.
- "Honest source limits" left empty (not faked): ~~leveled class features, subclass `granted_at_level`~~ (**both fixed by B1** — the level was in `ClassFeatureItem` all along), feat grants/ASI beyond the conservative parses, and any "of your choice" grant — all stay folded in the description. Wiring doc removed after all phases (C1-C7, D1-D9) shipped 2026-06-09; see BG-equipment + official-pkg-chargen-rules memory entries for final state.
- Retargeted onto the named grant-block fields in the 2026-07-28 rule-system removal (see [[Grant-Resolution]]): the mapper no longer emits `granted_modifiers` or `effects` rows. `tool/open5e_import/test/monster_mapper_check.dart` asserts the new shapes. **Packs built before that date still carry the old rows** — they are converted at install time by [[rule_effects_migration]], but a pack rebuild is the durable fix.
