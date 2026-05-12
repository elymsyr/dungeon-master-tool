# SRD Fix Roadmap

Audit date: **2026-05-12**. Branch: `template_first_opt`.

Prioritized fix list from the comprehensive audit of SRD content, character creation, and level-up mechanics. Item #1 (HP CON modifier) is **done**; items #2–#10 remain.

Severity legend: 🔴 correctness bug · 🟠 missing mechanic · 🟡 content/UX gap · 🟢 nice-to-have.

---

## Status

| # | Title | Severity | Status | Scope |
|---|---|---|---|---|
| 1 | HP CON modifier on level-up | 🔴 | ✅ DONE 2026-05-12 | planner + dialog |
| 2 | Spell slot table delta on level-up | 🟠 | TODO | planner + dialog + editor |
| 3 | Class resource scaling auto-apply | 🟠 | TODO | resource resolver + level-up hook |
| 4 | New spells picker on level-up | 🟠 | TODO | dialog + editor |
| 5 | Hit dice tracker increment | 🟠 | TODO | editor + rest dialogs |
| 6 | Backgrounds 5–12 content | 🟡 | TODO | srd_core/backgrounds.dart |
| 7 | Saving throw proficiency from subclass | 🟠 | TODO | resolver + level-up hook |
| 8 | Extra Attack L11 / L20 Fighter scaling | 🟠 | TODO | planner + entity field |
| 9 | Subrace / lineage picker | 🟡 | TODO | race step + species data |
| 10 | Multiclass support | 🟠 | TODO | wizard + editor + planner (large) |

---

## #2 · Spell slot table delta on level-up 🟠

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

## #3 · Class resource scaling auto-apply 🟠

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

## #4 · New spells picker on level-up 🟠

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

## #5 · Hit dice tracker increment 🟠

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

## #6 · Backgrounds 5–12 content 🟡

**Problem.** Only 4 of 12+ SRD backgrounds shipped (Acolyte, Criminal, Folk Hero, Sage).

**Missing per SRD 5.2.1 §1.4.**
- Charlatan, Entertainer, Guide, Guild Artisan, Hermit, Merchant, Noble, Sage *(present)*, Sailor, Scribe, Soldier, Wayfarer

**Files to touch.**
- [flutter_app/lib/domain/entities/schema/builtin/srd_core/backgrounds.dart](../flutter_app/lib/domain/entities/schema/builtin/srd_core/backgrounds.dart) — add 8+ entries. Each: name, description, ability_score_options (for 2024 SRD floating ASI), skill_proficiencies (2), tool_proficiency or language (1), starting_equipment_groups, origin_feat_ref.
- Each needs personality_traits, ideals, bonds, flaws random tables (8 entries each per SRD).

**Pre-req.** None. Content-authoring grind, no code changes.

**Test.** Each background loads via `buildBuiltinSrdEntities()`, picker shows 12 entries, wizard creates valid character with each.

---

## #7 · Saving throw proficiency from subclass 🟠

**Problem.** Some subclass features grant new saving throw proficiencies (e.g. Cleric L1 Divine Order option, Sorcerer L20 Soul of Sorcery — varies). Resolver doesn't add these to `save_proficiencies`.

**SRD §1.4-1.5.** Each class grants 2 saving throw profs at L1. Some subclasses extend. Magic Initiate's spellcasting also adds save DC calculations.

**Files to touch.**
- Resolver path (look for `save_proficiencies` writer in resolver). Subclass features with `grants_save_proficiency_ref` field should fold into PC.
- Schema: ensure `grants_save_proficiency_ref` exists on subclass features.
- Level-up: if new feature has this field, dialog notes "You gain proficiency in {save}".

**Test.** Cleric 1 with Life Domain: save profs include WIS + CHA. Wizard 1: INT + WIS.

---

## #8 · Extra Attack L11 / L20 Fighter scaling 🟠

**Problem.** Planner detects L5 only via `_extraAttackLevels = {5}`. Fighter gets +1 more at L11 (3 attacks) and L20 (4 attacks). Other classes stay at 2.

**Files to touch.**
- Planner: add `extraAttackCount int` to plan, computed from class's `extra_attack_scaling` table OR hardcoded set per class name.
- Classes data: add `extra_attack_scaling: [[5,2],[11,3],[20,4]]` to Fighter entity.
- Dialog: notice text adapts ("strike three times").
- Resolver: write `extra_attack_count` to PC entity.

**Pre-req.** None. Small scope.

**Test.** Fighter 4→5: count 1→2. Fighter 10→11: count 2→3. Paladin 4→5: count 1→2 (no further scaling).

---

## #9 · Subrace / lineage picker 🟡

**Problem.** Race step shows top-level species (Elf, Dragonborn, etc.) but no UI for subrace (High Elf vs Wood Elf, Chromatic vs Metallic Dragonborn). SRD 2024 collapses many subraces into top-level lineages — verify which still apply.

**Files to touch.**
- Race step UI: detect species with `subspecies_options List<String>` field, render second picker.
- Species data: populate subspecies refs (or migrate to flat lineages per 2024 SRD).
- Resolver: fold subspecies traits into PC.

**Test.** Pick Dragonborn → second picker for ancestry color → damage_resistance + breath weapon damage type match.

---

## #10 · Multiclass support 🟠

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
2. #5 Hit dice tracker (independent, small)
3. #2 Spell slots delta (foundation for #4)
4. #4 New spells picker (depends on #2)
5. #3 Class resources (independent, medium)
6. #8 Extra Attack scaling (small)
7. #7 Saving throws (small, may piggyback on #3)
8. #6 Backgrounds content (parallel, content-only)
9. #9 Subrace picker (medium)
10. #10 Multiclass (large, last)

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
