---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/chargen.dart
layer: tool
language: dart
status: stable
updated: 2026-07-30
tags: [file]
---

# `mappers/chargen.dart`

> [!abstract] Primary Purpose
> Maps the v2 Open5e character-build documents — `CharacterClass`(+ClassFeature), `Species`(+SpeciesTrait), `Background`(+BackgroundBenefit), `Feat`(+FeatBenefit) — onto the app's `class` / `subclass` / `species` / `subspecies` / `background` / `feat` entities. The largest mapper (~50KB): besides folding child rows into the parent's description markdown, it parses every typed schema field the `CharacterResolver` can consume (ASI, granted skills/senses/languages, damage resist/immune/vuln, condition immunity, alt speeds, caster kind, prereq clauses, innate spells, equipment choice groups, subclass/subspecies parent links). These are not mere reference cards.

## Inputs / Outputs
**Inputs**
- `mapClasses`, `mapSpecies`, `mapBackgrounds`, `mapFeats` — each takes `(pack, norm, source, <parent fixtures>, <child fixtures>)` from [[loaders]]. `mapClasses` also takes `featureItems` (`ClassFeatureItem.json`, optional — defaults to `const []`, so a document without it maps as before).

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
- **Backgrounds** (`mapBackgrounds`): benefit rows keyed by `type` → `granted_skill_refs`, `ability_score_options` (+`asi_distribution_options` `['+2/+1','+1/+1/+1']` for 3-ability SRD-2024; A5e "+1 and one other" widens to all six so the resolver's `background_asi` gate doesn't drop the floating pick), `granted_language_count`, `origin_feat_ref` softRef. Equipment: `_parseEquipmentChoiceProse` parses SRD-2024 A/B prose into structured `equipment_choice_groups`; `_fixedEquipmentGroup` is the A5e/Open5e fallback that synthesises minimal in-pack `adventuring-gear` entities (build-safe hard ref, grantable) for kit items that don't resolve.
- **Feats** (`mapFeats`): `category_ref` from `type`; `_parseFeatPrereq` builds `prereq_clauses` (ability_min with `ability_options` list, character_level, spellcasting, armor/weapon/skill proficiency) + legacy flat fields; `_isJunkPrereq` strips `N/A`/`None`/`-`; `_parseFeatAsi` handles SRD-2024 + A5e ASI phrasings; the feat-benefit parser emits only high-confidence unconditional grants into the named fields (`granted_armor_proficiencies`, `speed_bonus_ft`, Tough-style `hp_bonus_per_level: 2`); explicit "choose N skills/tools" prose becomes a `player_choices` row.
- **The level table** (`_levelFeatures`, audit phase **B1**, 2026-07-30). `ClassFeature` has no level; its child `ClassFeatureItem` does, keyed `parent` → the feature's pk. Two shapes share that file and only one is a granted feature: a **granted feature** has one item per level it arrives or improves at (`column_value == null`) and becomes a `classFeatures` row; a **class-table column** has 20 items each carrying a `column_value` (`Proficiency Bonus`, `Augment Effects Known`, spell slots) and is skipped — that is B2's typed `*_by_level` fields. **No shipped document mixes the two inside one feature**, which is what makes "every item has a `column_value`" a safe test rather than a heuristic. A feature that improves gets one row per distinct level; `detail` (`'2 dice'`, `'two attacks'`) is upstream's only distinguisher, so it carries the follow-up rows' description while the first keeps the prose. `subclass.granted_at_level` = the lowest level the subclass's own non-table features arrive at, absent when it has none. No grant refs are emitted — the prose names no entity we could resolve (B5).
- `_addUnique` disambiguates same-slug name collisions (3rd-party docs reuse generic subclass/feat names) by suffixing the parent tag or a counter.

## Notes
- ⚠️ **`assets/open5e_packs/` predates B1.** The mapper fills the level table; the shipped assets do not carry it, because promoting a rebuild is a separate decision (audit Stage D). `test/tool/class_feature_levels_test.dart` therefore drives the mapper directly — fixture → `mapClasses` → `CharacterResolver` — rather than reading a bundled asset, which could only prove the old emptiness. `bundled_pack_resolve_test` gains the asset-side assertion at promotion.
- **One subclass will never have a level**: `Path of Hellfire` (`open5e-toh`) ships a `CharacterClass` row and zero `ClassFeature` rows upstream. 100 of 101, and the 101st is a source hole.
- "Honest source limits" left empty (not faked): ~~leveled class features, subclass `granted_at_level`~~ (**both fixed by B1** — the level was in `ClassFeatureItem` all along), feat grants/ASI beyond the conservative parses, and any "of your choice" grant — all stay folded in the description. Wiring doc removed after all phases (C1-C7, D1-D9) shipped 2026-06-09; see BG-equipment + official-pkg-chargen-rules memory entries for final state.
- Retargeted onto the named grant-block fields in the 2026-07-28 rule-system removal (see [[Grant-Resolution]]): the mapper no longer emits `granted_modifiers` or `effects` rows. `tool/open5e_import/test/monster_mapper_check.dart` asserts the new shapes. **Packs built before that date still carry the old rows** — they are converted at install time by [[rule_effects_migration]], but a pack rebuild is the durable fix.
