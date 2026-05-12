# SRD Fix Roadmap

Audit date: **2026-05-12**. Branch: `template_first_opt`.

Prioritized fix list from the comprehensive audit of SRD content, character creation, and level-up mechanics. Item #1 (HP CON modifier) is **done**; items #2–#10 remain.

Severity legend: 🔴 correctness bug · 🟠 missing mechanic · 🟡 content/UX gap · 🟢 nice-to-have.

---

## Status

| # | Title | Severity | Status | Scope |
|---|---|---|---|---|
| 1 | HP CON modifier on level-up | 🔴 | ✅ DONE 2026-05-12 | planner + dialog |
| 2 | Spell slot table delta on level-up | 🟠 | ✅ DONE 2026-05-12 | planner + dialog + editor |
| 3 | Class resource scaling auto-apply | 🟠 | ✅ DONE 2026-05-12 | resource resolver + level-up hook |
| 4 | New spells picker on level-up | 🟠 | ✅ DONE 2026-05-12 | dialog + editor |
| 5 | Hit dice tracker increment | 🟠 | ✅ DONE 2026-05-12 | editor + dialog |
| 6 | Backgrounds 5–12 content | 🟡 | ✅ DONE 2026-05-12 | srd_core/backgrounds.dart |
| 7 | Saving throw proficiency from subclass | 🟠 | ✅ DONE 2026-05-12 | resolver + planner + dialog |
| 8 | Extra Attack L11 / L20 Fighter scaling | 🟠 | ✅ DONE 2026-05-12 | resolver + planner + dialog |
| 9 | Subrace / lineage picker | 🟡 | ✅ DONE 2026-05-13 | race step + species data + resolver |
| 10 | Multiclass support | 🟠 | ✅ DONE 2026-05-13 (MVP) | helper + resolver + editor (large) |

---

## #2 · Spell slot table delta on level-up 🟠 — ✅ DONE 2026-05-12

**Resolution.** `defaultSpellSlotsByLevel(kind, level)` in [caster_progression.dart](../flutter_app/lib/application/character_creation/caster_progression.dart) emits SRD full/half/third/pact tables. `LevelUpPlan` gained `prevSpellSlots`/`newSpellSlots` (entity table overrides default), plus a `spellSlotsDelta` getter. Dialog `_casterBlock` renders "Slots — L1:4 L2:0→3" + a "New: +2 at L3" line. Editor writes `spell_slots_by_level` (max) and `spell_slots_remaining_by_level` (carries spent slots forward + adds fresh capacity). 14 new planner tests, 422-test suite green.

**Problem.** Caster level-up dialog *displays* `cantripsKnownAtNewLevel`, `preparedSpellsAtNewLevel`, `maxSpellLevelAtNewLevel` but the actual slot table on the character entity is never written. Casters can see "Max spell level: 3" yet attempting to cast a L3 spell finds 0 slots.

**SRD §1.5.** Spell slots per class follow tables by `caster_kind`:
- **Full caster** (Bard, Cleric, Druid, Sorcerer, Wizard): full slot progression L1–L20
- **Half caster** (Paladin, Ranger): slots start L2, peak at L5
- **Third caster** (Eldritch Knight, Arcane Trickster — subclass-only): slower
- **Pact caster** (Warlock): few slots, all at max level, restored on short rest

**Files to touch.**
- [flutter_app/lib/application/character_creation/caster_progression.dart](../flutter_app/lib/application/character_creation/caster_progression.dart) — likely has `defaultPreparedSpells` / `maxPreparableSpellLevel`; add `defaultSpellSlotsByLevel(kind, level) → Map<int, int>` returning slot count per spell-level key 1..9.
- [flutter_app/lib/application/character_creation/level_up_planner.dart](../flutter_app/lib/application/character_creation/level_up_planner.dart) — add `spellSlotsAtNewLevel` field to `LevelUpPlan`. Read from `classEntity.fields['spell_slots_by_level']` first (authored data), fall back to default table.
- [flutter_app/lib/presentation/screens/characters/level_up_dialog.dart](../flutter_app/lib/presentation/screens/characters/level_up_dialog.dart) — add `_casterBlock` row showing slot delta per spell level (e.g. "L1: 3 → 4, L2: 0 → 2"). No user choice needed; informational.
- [flutter_app/lib/presentation/screens/characters/character_editor_screen.dart](../flutter_app/lib/presentation/screens/characters/character_editor_screen.dart) `_maybeRunLevelUp` — write computed slot map to `spell_slots_by_level` and `spell_slots_remaining_by_level` (latter set equal to max on level-up).

**Edge.** Warlock pact slots restore on short rest, not long — separate field path. Don't conflate.

**Test.** Planner test: full-caster Cleric 4→5 returns `{1:4, 2:3, 3:2}`. Half-caster Paladin 1→2 returns `{1:2}`. Pact Warlock 4→5 returns `{slotLevel:3, count:2}` (slot level scales).

---

## #3 · Class resource scaling auto-apply 🟠 — ✅ DONE 2026-05-12

**Resolution.** New file [resource_pool_resolver.dart](../flutter_app/lib/application/character_creation/resource_pool_resolver.dart) walks `entities` for feats whose `auto_granted_by` matches the active class/subclass at level ≤ N, then reads each `resource_pool_grant` effect's `scales_with.table` (largest lvl ≤ level) or literal `count`. `LevelUpPlan.prevResourcePools` + `newResourcePools` + `resourcePoolDeltas` getter. Editor writes `class_resource_pools` (max) + `class_resource_pools_remaining` (carries spent forward + fresh capacity). Dialog renders "Class Resources" block with prettified pool names. **count_formula path (`cha_mod_min_1`, `paladin_level_x5`) intentionally skipped — pools using it stay manual until formula evaluation lands.** 8 resolver tests; 434 full suite green.

**Problem.** Resource pools (Rage uses, Channel Divinity, Sorcery Points, Ki / Focus Points, Lay on Hands, Bardic Inspiration die, Wild Shape uses) are defined in [feats_class.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/feats_class.dart) via `scalesByClass([[level, value], ...])` but the planner never reads them, so level-up doesn't bump the character's current pool.

**Data shape.** Effects with `kind: 'resource_pool_grant'` carry `scalesWith` table. Example: Barbarian Rage uses `[[1,2],[3,3],[6,4],[12,5],[17,6],[20,99]]`.

**Files to touch.**
- New file: `flutter_app/lib/application/character_creation/resource_pool_resolver.dart` — pure function `Map<String, int> resolveResourcePoolsAt({Entity classEntity, Entity? subclassEntity, int level, List<Entity> activeFeats})`. Walks effects, returns `{poolKey: capValue}`.
- Planner: add `resourcePools Map<String, int>` and `resourcePoolDeltas Map<String, int>` to `LevelUpPlan` (diff `from`→`to` levels).
- Dialog: render deltas in a "Class resources" section.
- Editor: write pool maxes to character `class_resources` (map field) on apply.

**Care.** Some pools cap at "unlimited" (Monk Focus Points at L20). Use sentinel like -1 or string "∞"; UI handles display.

**Test.** Barbarian 2→3: Rage 2→3. Monk 1→2: Focus 1→2. Sorcerer 4→5: Sorcery 4→5. Paladin 4→5: Lay on Hands 20→25.

---

## #4 · New spells picker on level-up 🟠 — ✅ DONE 2026-05-12

**Resolution.** `LevelUpPlan` gained `cantripsKnownAtPrevLevel`/`preparedSpellsAtPrevLevel` + `cantripsKnownDelta`/`preparedSpellsDelta` getters. `LevelUpDialog` accepts `classId` + `existingSpellIds`; renders two chip pickers (`_spellsSection` → `_spellChips`) capped at the SRD delta, filtered by `class_refs` and `level ≤ maxSpellLevel`. `LevelUpResult.newSpellIds` flows back to editor which dedup-appends to `spells_known`. Wizard/Cleric/etc. all share this code path (Wizard "spellbook" is just `spells_known`).

**Problem.** Dialog shows new `cantripsKnownAtNewLevel` / `preparedSpellsAtNewLevel` but doesn't prompt the player to *pick* the new spells. Character `cantrip_ids` / `prepared_spell_ids` lists are not extended.

**SRD §1.5.** On caster level-up:
- Cantrip: pick new cantrips from class list when cantrip count increased
- Known/prepared: pick new spells from class list, level ≤ `maxPreparableSpellLevel`
- Wizard: also copies 2 free spells into spellbook from any spell level they can cast
- Spell swap: most classes allow swapping one known spell on level-up (optional rule)

**Files to touch.**
- Dialog: add `_spellsSection` rendering two pickers when deltas > 0 — "Add N cantrips" and "Add M spells". Filter by class's `class_refs` membership and `level ≤ maxPreparableSpellLevel`.
- `LevelUpResult`: add `newCantripIds List<String>` + `newPreparedSpellIds List<String>` + `newSpellbookIds List<String>` (Wizard only).
- Editor: append picks to entity lists.

**Pre-req.** Needs #2 (knows new slot caps) and reads spells from entity map (same as feats step). Reuse `_FeatsCache` pattern for spell-by-class+level lookup.

**Test.** Wizard 1→2: shows 2-spellbook picker. Sorcerer 4→5: cantrip count unchanged (still 5), spell count 5→6 — only spells picker shown.

---

## #5 · Hit dice tracker increment 🟠 — ✅ DONE 2026-05-12

**Resolution.** Short/long rest dialogs already used `hit_dice_remaining` with max derived from `level` — no schema work needed. Editor `_maybeRunLevelUp` now bumps `hit_dice_remaining` by `plan.levelsGained` (clamped to new level). Dialog shows a "Hit Dice: NdX → MdX" row for visibility.

**Problem.** Characters gain 1 hit die per level (used for short-rest healing). No field tracks remaining hit dice; level-up doesn't increment.

**SRD §1.6.** Short rest: spend ≤ N hit dice (where N = remaining); each rolls `1d{hitDieFaces} + CON mod` HP. Long rest restores `floor(maxHitDice / 2)`, min 1.

**Files to touch.**
- Character entity field: `hit_dice_remaining int` and `hit_dice_max int` (or per-class map for multiclass).
- Editor `_maybeRunLevelUp`: bump both by `levelsGained`.
- Short-rest dialog: dice spend UI.
- Long-rest hook: restore formula.

**Pre-req.** None. Independent.

**Test.** Fighter 3→5: `hit_dice_remaining` 3→5, `hit_dice_max` 3→5. Short rest spend 2: `hit_dice_remaining` 5→3, HP gains 2×(1d10+CON). Long rest at 0/5 → restore to 2 (floor(5/2)).

---

## #6 · Backgrounds 5–12 content 🟡 — ✅ DONE 2026-05-12

**Resolution.** Added 12 missing SRD 5.2.1 (Free Rules 2024) backgrounds to [backgrounds.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/backgrounds.dart): Artisan, Charlatan, Entertainer, Farmer, Guard, Guide, Hermit, Merchant, Noble, Sailor, Scribe, Wayfarer. Each ships with ability_score_options (3 abilities for 2024 floating ASI), origin_feat_ref, granted_skill_refs (2), granted_tool_refs (1), starting_gold_gp + 50 GP alternative, and equipment_choice_groups (option A typed kit + option B 50 GP). Origin feats reuse existing entries (Crafter / Skilled / Musician / Tough / Alert / Magic Initiate / Healer / Lucky / Tavern Brawler / Savage Attacker). New `backgrounds_test.dart` locks in the 16-entry count + structural invariants (455 suite green).

**Problem.** Only 4 of 12+ SRD backgrounds shipped (Acolyte, Criminal, Folk Hero, Sage).

**Missing per SRD 5.2.1 §1.4.**
- Charlatan, Entertainer, Guide, Guild Artisan, Hermit, Merchant, Noble, Sage *(present)*, Sailor, Scribe, Soldier, Wayfarer

**Files to touch.**
- [flutter_app/lib/domain/entities/schema/builtin/srd_core/backgrounds.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/backgrounds.dart) — add 8+ entries. Each: name, description, ability_score_options (for 2024 SRD floating ASI), skill_proficiencies (2), tool_proficiency or language (1), starting_equipment_groups, origin_feat_ref.
- Each needs personality_traits, ideals, bonds, flaws random tables (8 entries each per SRD).

**Pre-req.** None. Content-authoring grind, no code changes.

**Test.** Each background loads via `buildBuiltinSrdEntities()`, picker shows 12 entries, wizard creates valid character with each.

---

## #7 · Saving throw proficiency from subclass 🟠 — ✅ DONE 2026-05-12

**Resolution.** Two paths now flow into `proficiencies.savingThrowAbilityIds`:

1. **Top-level subclass refs.** [CharacterResolver](../flutter_app/lib/domain/services/character_resolver.dart) Pass 8 now also reads `saving_throw_refs` (plus `weapon_proficiency_categories` and `armor_training_refs`) off the active subclass entity, mirroring the class-side path.
2. **Subclass feature-row effects.** Pass 4 already walks subclass `features[*].effects` through `applyEffect`, so any feature row with `kind: proficiency_grant` + `target_kind: saving_throw|ability` already lands in `saves`. Added test coverage to lock it in.

`LevelGain` gained `grantedSaveProficiencyNames` (extracted by the planner from each new feature's `proficiency_grant` effects). [Level-up dialog](../flutter_app/lib/presentation/screens/characters/level_up_dialog.dart) renders a bold "You gain proficiency in X saving throws." line under the feature description when the list is non-empty. 2 resolver tests + 3 planner tests; 453-test suite green.

**Problem.** Some subclass features grant new saving throw proficiencies (e.g. Cleric L1 Divine Order option, Sorcerer L20 Soul of Sorcery — varies). Resolver doesn't add these to `save_proficiencies`.

**SRD §1.4-1.5.** Each class grants 2 saving throw profs at L1. Some subclasses extend. Magic Initiate's spellcasting also adds save DC calculations.

**Files to touch.**
- Resolver path (look for `save_proficiencies` writer in resolver). Subclass features with `grants_save_proficiency_ref` field should fold into PC.
- Schema: ensure `grants_save_proficiency_ref` exists on subclass features.
- Level-up: if new feature has this field, dialog notes "You gain proficiency in {save}".

**Test.** Cleric 1 with Life Domain: save profs include WIS + CHA. Wizard 1: INT + WIS.

---

## #8 · Extra Attack L11 / L20 Fighter scaling 🟠 — ✅ DONE 2026-05-12

**Resolution.** New [extra_attack_resolver.dart](../flutter_app/lib/application/character_creation/extra_attack_resolver.dart) walks auto-granted feats whose `effects` include `extra_attack_count` (or the legacy `extra_attack_bump`), takes the max value across matching grants at level ≤ N. SRD data already declares Fighter L5/L11/L20 grants in [feats_class.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/feats_class.dart), so no class-entity field was added. `LevelUpPlan` gained `prevExtraAttackCount`/`newExtraAttackCount` + `extraAttackCountDelta` getter; `isExtraAttackLevel` now fires whenever the resolver delta is positive (so L11 and L20 are flagged for Fighter and the L5 fallback heuristic still triggers when no entities map is supplied). Dialog notice text adapts to the new count via `_extraAttackText` ("strike twice", "strike three times", "strike four times"). The PC entity isn't written — `CharacterResolver` Pass 4b already computes `extra_attack_count` dynamically each render. 9 resolver tests + 5 planner tests + 447-test suite green.

**Problem.** Planner detects L5 only via `_extraAttackLevels = {5}`. Fighter gets +1 more at L11 (3 attacks) and L20 (4 attacks). Other classes stay at 2.

**Files to touch.**
- Planner: add `extraAttackCount int` to plan, computed from class's `extra_attack_scaling` table OR hardcoded set per class name.
- Classes data: add `extra_attack_scaling: [[5,2],[11,3],[20,4]]` to Fighter entity.
- Dialog: notice text adapts ("strike three times").
- Resolver: write `extra_attack_count` to PC entity.

**Pre-req.** None. Small scope.

**Test.** Fighter 4→5: count 1→2. Fighter 10→11: count 2→3. Paladin 4→5: count 1→2 (no further scaling).

---

## #9 · Subrace / lineage picker 🟡 — ✅ DONE 2026-05-13

**Resolution.** New `subspecies_options` field on species entities (registered in [content.dart](../flutter_app/lib/domain/entities/schema/builtin/content.dart) as a markdown-typed wire key; rows authored as structured data in [species.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/species.dart)). Five species now ship lineage rows:

- **Dragonborn** — 10 ancestries (Black/Blue/Brass/Bronze/Copper/Gold/Green/Red/Silver/White) — each grants a `granted_damage_resistances` ref.
- **Elf** — Drow / High Elf / Wood Elf — Wood Elf gets `speed_bonus: +5`.
- **Gnome** — Forest / Rock — prose-only (cantrip-based lineage benefits deferred).
- **Goliath** — Cloud / Fire / Frost / Hill / Stone / Storm Giant — Fire/Frost/Storm grant damage resistance refs.
- **Tiefling** — Abyssal / Chthonic / Infernal — each grants a damage resistance.

`CharacterDraft` gained `subspeciesId` (regenerated via build_runner). `CharacterDraftNotifier.setRace` clears it on species swap; new `setSubspecies(key)`. New `_RaceStep` widget composes `_EntityPickStep` with a second-tier RadioListTile picker that appears only when the chosen species declares `subspecies_options`. Wizard commit writes `subspecies_id` to the PC entity. `CharacterResolver` Pass 5 walks the chosen subspecies row and folds its `granted_modifiers` / `granted_senses` / `granted_damage_resistances` / `granted_languages` / `granted_skill_proficiencies` the same way as the species-level fields. Spells/active abilities (breath weapon, Cloud's Jaunt, Stone's Endurance) live in prose — deferred. 3 resolver + 5 species-data tests; **463-suite green**.

**Problem.** Race step shows top-level species (Elf, Dragonborn, etc.) but no UI for subrace (High Elf vs Wood Elf, Chromatic vs Metallic Dragonborn). SRD 2024 collapses many subraces into top-level lineages — verify which still apply.

**Files to touch.**
- Race step UI: detect species with `subspecies_options List<String>` field, render second picker.
- Species data: populate subspecies refs (or migrate to flat lineages per 2024 SRD).
- Resolver: fold subspecies traits into PC.

**Test.** Pick Dragonborn → second picker for ancestry color → damage_resistance + breath weapon damage type match.

---

## #10 · Multiclass support 🟠 — ✅ DONE 2026-05-13 (MVP)

**Resolution.** New [multiclass_helper.dart](../flutter_app/lib/application/character_creation/multiclass_helper.dart) ships four pure functions: `checkMulticlassPrereq` (SRD §1.10 ability gate with `AND` / `any_of` semantics + 13-default min), `totalCharacterLevel`, `combinedCasterLevel` (full = level, half = floor/2 from L2, third = floor/3 from L3, pact excluded), and `multiclassSpellSlotsFor` (returns the full-caster table at the blended level when 2+ caster classes share a sheet, `null` otherwise so single-class falls through to the planner's progression).

`CharacterResolver` Pass 2 [character_resolver.dart](../flutter_app/lib/domain/services/character_resolver.dart) replaces the prior `max(class_levels)` subclass heuristic with a `parent_class_ref`-driven gate: the active subclass fires its features at the **parent class's** level, not the character's max class level. So a Cleric 2 / Wizard 5 with Life Domain (granted_at_level 3) **doesn't** prematurely unlock Disciple of Life.

`character_editor_screen.dart` gains a multi-class level-up flow:
- `_levelUp(character)` opens a `_LevelUpClassPicker` listing each current class with its level plus an "Add new class (multiclass)" row. The secondary picker enumerates every class entity the character doesn't yet have; on tap, `checkMulticlassPrereq` runs and a warning dialog fires when the SRD §1.10 ability prereq isn't met (player can confirm anyway for rule-zero / homebrew).
- `_maybeRunLevelUp` takes an optional `targetClassId` (the class being advanced) and an `isNewClass` flag. The planner is still single-class — `_maybeRunLevelUp` passes the *target* class's entity and per-class from/to levels so HP / PB / features / spell-slot / resource deltas track the right table.
- `_subclassForClass` walks `subclass_refs` and matches each candidate's `parent_class_ref.name` to the target class entity's name; falls back to first entry for legacy single-subclass sheets.
- Write-back updates `class_levels[targetClassId]`, appends the class id to `class_refs`, and rewrites `level` as `totalCharacterLevel(class_levels)` so the rest of the sheet (rest dialogs, level-up table, sheet) keep working off the existing flat `level` field.
- Hit-dice pool max is now `totalCharacterLevel(class_levels)` rather than `plan.toLevel` (the prior code under-clamped when adding a new class at L1 to a higher-level character).
- Multi-caster spell slots: when `isMulticlassCaster` fires, the write block overrides `plan.newSpellSlots` with `multiclassSpellSlotsFor(...)` and recomputes the previous map by reverting the target class to its from-level — so the delta = blended-now minus blended-prev. Single-caster characters keep the planner's authored / SRD table.

13 new tests (`multiclass_helper_test.dart`: 12; `character_resolver_test.dart`: 2 multiclass subclass-gate cases). 477-test suite green (was 463).

**Deferred (post-MVP):**
- Per-class hit-dice pool (current single combined `hit_dice_remaining` doesn't preserve the d8 vs. d10 distinction for short-rest dice spending).
- ASI/feat gating per class level vs. character total (SRD §1.10 says per class). Planner's `_asiOrFeatLevels` runs against the *class level*, which is correct — but the editor doesn't currently surface the ASI-from-class-1-only nuance.
- Spell-list partitioning (spells known per class, vs. one merged `spells_known`).
- Per-class hit-die in long-rest restore formula.
- Multiclass starting proficiencies (the limited-proficiency entry-grant per SRD §1.10 — class entities ship a `multiclass_granted_proficiencies` markdown field but the editor doesn't auto-apply it on entry yet).
- Multi-subclass support (Fighter 5 / Wizard 3 currently picks one subclass total). Schema accepts `subclass_refs` list; resolver loops would need extending.

**Problem.** No multiclass. Wizard assumes single class. Planner takes a single class entity.

**SRD §1.10 multiclass rules.**
- Entry ability prereq (Fighter STR or DEX 13, Wizard INT 13, etc.)
- Class proficiencies on entry: limited subset (not full L1 prof list)
- Hit dice per class
- Proficiency bonus: total character level, not per class
- Spellcasting: combined-level slot table for full+half casters (Paladin 4 + Wizard 4 = slot table at level 6 entry)
- ASI: per class level (not total)
- Extra Attack: doesn't stack across classes

**Files to touch.** Big. Wizard needs class-picker that supports multiple. Editor needs per-class hit die tracking. Planner needs to accept `Map<String, int>` of class→level.

**Scope.** Multi-sprint effort. Defer until #2–#8 done.

---

## Recommended order

1. ✅ #1 HP CON mod
2. ✅ #5 Hit dice tracker
3. ✅ #2 Spell slots delta
4. ✅ #4 New spells picker
5. ✅ #3 Class resources
6. ✅ #8 Extra Attack scaling
7. ✅ #7 Saving throws
8. ✅ #6 Backgrounds content
9. ✅ #9 Subrace picker
10. ✅ #10 Multiclass (large, last)

**Rationale.** #2 + #4 unlock the most player-visible value (casters get usable spell access on level-up). #5 is cheap and enables short-rest economy. #3 + #7 + #8 polish the level-up dialog. #6 is independent content. #9 + #10 are larger scope, save for dedicated sprints.

---

## Conventions

When implementing any item:

- **Planner stays pure**: no UI imports, no campaign reads — accept entities + level as params, return data
- **Dialog is the choice surface**: reads from planner, accepts user picks, returns `LevelUpResult`
- **Editor owns mutation**: applies result atomically to character entity
- **Test the planner**: pure functions are easy to unit-test
- **Reuse `_FeatsCache` pattern** for any cross-entity lookup on level-up (single scan per build)
- **Update [docs/character_creation_level_audit.md](character_creation_level_audit.md) §4** roadmap when shipping each item

Related: [srd_5e_mechanic_audit.md](srd_5e_mechanic_audit.md), [character_creation_level_audit.md](character_creation_level_audit.md).
