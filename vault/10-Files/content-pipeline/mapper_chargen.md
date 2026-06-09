---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/mappers/chargen.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `mappers/chargen.dart`

> [!abstract] Primary Purpose
> Maps the v2 Open5e character-build documents — `CharacterClass`(+ClassFeature), `Species`(+SpeciesTrait), `Background`(+BackgroundBenefit), `Feat`(+FeatBenefit) — onto the app's `class` / `subclass` / `species` / `subspecies` / `background` / `feat` entities. The largest mapper (~50KB): besides folding child rows into the parent's description markdown, it parses every typed schema field the `CharacterResolver` can consume (ASI, granted skills/senses/languages, damage resist/immune/vuln, condition immunity, alt speeds, caster kind, prereq clauses, innate spells, equipment choice groups, subclass/subspecies parent links). These are not mere reference cards.

## Inputs / Outputs
**Inputs**
- `mapClasses`, `mapSpecies`, `mapBackgrounds`, `mapFeats` — each takes `(pack, norm, source, <parent fixtures>, <child fixtures>)` from [[loaders]].

**Outputs**
- Adds `class` / `subclass` / `species` / `subspecies` / `background` / `feat` (and synthesised `adventuring-gear`) entities to the `PackBuilder` ([[refgraph]]).

## Dependencies & Links
- Depends on: [[loaders]], [[normalize]], [[refgraph]], [[srd_helpers]] (`packEntity`, `lookup`, `ref`, `effect`, `eqGroup`/`eqOption`/`eqItem`).
- Used by: [[build_packs]].
- Resolved at runtime by: `character_resolver` (consumes the typed grants).
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]], [[Open5e-API]]

## Key Logic / Variables
- **Three ref kinds**: `lookup()` (Tier-0, resolved at import), `ref()` (hard in-pack, resolved at build — build FAILS if unresolved), and `softRef(slug, name)` = `{slug, name}` with NO `_ref` key (cross-pack; PackBuilder leaves it intact, `CharacterResolver._resolveRef` name-resolves it at resolve time, clean no-op if the target pack isn't installed). softRef is used for subclass→built-in base class, species→spell, subspecies→parent species, background→origin feat.
- **Classes** (`mapClasses`): base classes (`subclass_of == null`) → `class`; rest → `subclass` with `parent_class_ref` (hard `ref` when parent ships in-pack, else `softRef`). Caster kind = Open5e `caster_type` if set, else `_inferCasterKind` from feature rows (Pact Magic→Pact, no spell feature→None, has "Cantrips Known"→Full, spellcasting w/o cantrips→Half — Open5e leaves `caster_type` null for the whole SRD-2014 set). C7: armor/weapon/skill proficiencies parsed from the structured `**Armor:**`/`**Weapons:**`/`**Skills:**` Proficiencies feature ("all armor"→Light+Medium+Heavy).
- **Species/Subspecies** (`mapSpecies`, 3-pass): pass 1 parses Size/Speed from trait rows; pass 2 lets subspecies inherit absent parent values; pass 3 emits with typed grants — D1 damage resist/immune/vuln (regex on "X damage"), D2 condition immunity (explicit immunity phrasing only), D3 fixed skill prof, D4 innate alt speeds (skips conditional/temporary), D9 innate spell/cantrip grants, ASI (`_parseAsi`: fixed bonuses, "each" grants all six). Subspecies → first-class `subspecies` entity with `parent_species_ref` softRef.
- **Backgrounds** (`mapBackgrounds`): benefit rows keyed by `type` → `granted_skill_refs`, `ability_score_options` (+`asi_distribution_options` `['+2/+1','+1/+1/+1']` for 3-ability SRD-2024; A5e "+1 and one other" widens to all six so the resolver's `background_asi` gate doesn't drop the floating pick), `granted_language_count`, `origin_feat_ref` softRef. Equipment: `_parseEquipmentChoiceProse` parses SRD-2024 A/B prose into structured `equipment_choice_groups`; `_fixedEquipmentGroup` is the A5e/Open5e fallback that synthesises minimal in-pack `adventuring-gear` entities (build-safe hard ref, grantable) for kit items that don't resolve.
- **Feats** (`mapFeats`): `category_ref` from `type`; `_parseFeatPrereq` builds `prereq_clauses` (ability_min with `ability_options` list, character_level, spellcasting, armor/weapon/skill proficiency) + legacy flat fields; `_isJunkPrereq` strips `N/A`/`None`/`-`; `_parseFeatAsi` handles SRD-2024 + A5e ASI phrasings; `_parseFeatEffects` emits only high-confidence unconditional effects (armor proficiency, flat speed bonus, Tough-style `hp_bonus_per_level: 2`); `_parseFeatChoiceGroups` emits a `choice_group` skill/tool picker on explicit "choose N skills/tools".
- `_addUnique` disambiguates same-slug name collisions (3rd-party docs reuse generic subclass/feat names) by suffixing the parent tag or a counter.

## Notes
- "Honest source limits" left empty (not faked): leveled class features, subclass `granted_at_level` (no level field in ClassFeature), feat effect/ASI DSL beyond the conservative parses, and any "of your choice" grant — all stay folded in the description. See `flutter_app/docs/chargen_mechanics_wiring.md` and the BG-equipment / official-pkg-chargen-rules memory entries.
