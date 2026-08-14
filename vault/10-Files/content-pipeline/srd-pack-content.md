---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/srd_core/{classes,subclasses,species,subspecies,spells,monsters,feats,feats_class,magic_items,creature_actions,traits,gear,weapons,armor,ammunition,animals,mounts,vehicles,tools}.dart
layer: domain
language: dart
status: stable
updated: 2026-08-14
tags: [file]
---

# SRD Core Pack Content Files (GROUP)

> [!abstract] Primary Purpose
> The hand-authored SRD 5.2.1 (CC-BY-4.0) content rows, split one file per content slug. Each file exports a `srdXxx()` function returning `List<Map<String, dynamic>>` of `packEntity(...)` rows; [[srd_core_pack]] (`_rawRowsBySlug`) calls them all and runs the two-pass UUID/ref build. Tier-0 references use `lookup(slug, name)` placeholders ([[srd_helpers]]); inter-content references use `ref(slug, name)`. This is the built-in "SRD Core" pack — it replaces the WotC SRD Open5e docs entirely (those are skipped at build, see [[build_packs]]).

## Inputs / Outputs
**Inputs**
- None at build time — these are literal/builder-constructed authored rows.

**Outputs (one builder fn each; approximate row counts)**
- `weapons.dart` → `srdWeapons()` — **39** weapons (`_w` builder; SRD p.91 table).
- `armor.dart` → `srdArmor()` — **14** armor rows (`_a`).
- `ammunition.dart` → `srdAmmunition()` — ~6 ammo rows.
- `gear.dart` → `srdAdventuringGear()` — **108** adventuring-gear rows (`_g`).
- `tools.dart` → `srdTools()` — **39** tools (`_t`).
- `mounts.dart` → `srdMounts()` — ~9 mounts.
- `vehicles.dart` → `srdVehicles()` — ~13 vehicles.
- `packs.dart` → `srdPacks()` — ~8 equipment packs (NOT in the group hint list, but bundled by `srd_core_pack`; refs gear/weapons/armor via `ref`).
- `classes.dart` → `srdClasses()` — **12** base classes.
- `subclasses.dart` → `srdSubclasses()` — **12** subclasses.
- `species.dart` → `srdSpecies()` — **9** species.
- `subspecies.dart` → `srdSubspecies()` — ~22 subspecies (`_sub` builder; first-class category since Jun 2026).
- `backgrounds.dart` → `srdBackgrounds()` — **16** backgrounds.
- `feats.dart` → `srdFeats()` — **62** general/origin feats.
- `feats_class.dart` → `srdClassFeats()` + `srdSubclassFeats()` — **130** class feats (`_cf`) + **58** subclass feats (`_sf`) + **43** feature-option feats (`_opt`); all fold into the `feat` slug.
- `spells.dart` → `srdSpells()` — **341** spells (`_spell`; every cantrip + every L1 + a high-impact slice of L2–9).
- `magic_items.dart` → `srdMagicItems()` — **286** magic items (`_mi`).
- `monsters.dart` → `srdMonsters()` — **248** monsters (direct `packEntity`; references trait/creature-action rows by `ref`).
- `animals.dart` → `srdAnimals()` — **97** animals (NPCs/beasts; same shape as monsters).
- `traits.dart` → `srdTraits()` — ~40 reusable traits referenced by monsters.
- `creature_actions.dart` → `srdCreatureActions()` — **137** creature-action rows referenced by monsters.

## Dependencies & Links
- Depends on: [[srd_helpers]] (`packEntity`, `lookup`, `ref`, `withFeatureGrant`, `eqGroup`), `dnd5e_constants`.
- Used by: [[srd_core_pack]] (`_rawRowsBySlug`).
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]], [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]], [[Content-Licenses]], [[builtin_schema]] (the Tier-1 shapes these rows fill)

## Key Logic / Variables
- Each file defines a private compact builder (`_w`, `_a`, `_g`, `_t`, `_spell`, `_mi`, `_cf`, `_sf`, `_sub`, …) that sets every fieldKey from the matching Tier-1 schema in `content.dart` (see [[builtin_schema]]) and wraps the result in `packEntity`.
- **Monster ↔ child wiring**: `monsters.dart`/`animals.dart` reference `trait` and `creature-action` rows by name via `ref(...)`, so `traits.dart` + `creature_actions.dart` must build BEFORE monsters in `_rawRowsBySlug`. Open5e mappers replicate this exact pattern.
- **Feat folding**: class/subclass auto-grant feats + per-feature option feats (Metamagic, Eldritch Invocations, Pact Boon, Hunter picks, …) live in `feats_class.dart` and are concatenated into the single `feat` slug so the resolver's auto-grant and feature-option dialogs find them.
- **Card mechanics are named fields.** `feats_class.dart`, `feats.dart` and `subspecies.dart` were converted off the `effect()` / `granted_modifiers` DSL on 2026-07-28; a card now sets grant-block keys directly (`granted_damage_resistances`, `extra_attack_count_by_level`, `resource_pool_grants`, `active_while_state_ref`, `mechanical_notes`, …). `_helpers.dart` no longer exports effect builders. See [[Grant-Resolution]].
- **`spells.dart` derives three fields from each spell's own description (audit T2-3, 2026-08-14) rather than from a parameter.** `_areas` is a `name → (area-shape, size ft)` table feeding `area_shape_ref`/`area_size_ft` (**64/341**; Cylinder stores the radius, Line the length; `Wall of Force`, `Private Sanctum`, `Antipathy/Sympathy` are recorded non-areas). `_reactionTriggers` covers all **4** Reaction-cast spells. `_upcastHeading` lifts the upcast clause verbatim into `at_higher_levels_text` as a single entry keyed at `level + 1` (**50/341**) — the SRD states upcast as a formula, not a table, and Cantrip Upgrade is excluded because it scales on character level. `test/domain/srd_core_spell_fields_test.dart` re-reads every description to prove nothing was invented, and sweeps the other way so a new spell with an area but no shape fails.
- **`packs.dart` fills `content_quantities` keyed by position in `content_refs`**, not by entity id: the field is a `levelTable` (`Map<int,int>`) and `_resolveRefs` rewrites map values only, so a UUID key was never reachable. Both lists come from the same `contents` map in the same order. The schema label was corrected to match ([[builtin_schema]] `2.5.0 → 2.5.1`).
- Counts are author-progress proxies (`spells.dart` notes the full SRD has ~350; this covers the canonical, most-played slice). Bump `srdCorePackVersion` on any row change.

## Notes
- Per the audit memories, all leveled class features / subclass `granted_at_level` and most "of your choice" grants are present here (unlike the Open5e mappers which leave them folded in prose). Integrity covered by `srd_core_pack_test.dart`.
