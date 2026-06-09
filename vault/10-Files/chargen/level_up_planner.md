---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/level_up_planner.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `level_up_planner.dart`

> [!abstract] Primary Purpose
> Pure function `planLevelUp(...)` that diffs a character moving from `fromLevel` to `toLevel` against its class + subclass entities and returns a `LevelUpPlan` — every deterministic delta (HP, proficiency bonus, new features, ASI/feat & Extra Attack & Fighting Style & subclass & Divine Order flags, caster caps + slot maps, resource-pool maxes, weapon-mastery cap). The editor's level-up dialog just renders the plan; `pending_choices.dart` translates its flags into deferred player decisions.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — top-level functions + the `LevelUpPlan`/`LevelGain` value classes.
- Reads: caller passes `Entity? classEntity`, `Entity? subclassEntity`, `Map<String,Entity> entities` (for resolver lookups), `Map<String,int> abilities`, `Map<String,int> classLevels`, `RuleConfig config` (default `RuleConfig.dnd5eDefaults`).
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `LevelUpPlan planLevelUp({...})`; helpers `effectiveHpDelta`, `proficiencyBonusFor`, `fixedHpFor`; `LevelUpPlan` with computed getters `cantripsKnownDelta`, `preparedSpellsDelta`, `pbDelta`, `hitDieFaces`, `levelsGained`, `extraAttackCountDelta`, `weaponMasteryCountDelta`, `resourcePoolDeltas`, `spellSlotsDelta`, `isLevelUp`.

## Dependencies & Links
- Depends on: [[caster_progression]] (`parseCasterKind`, `levelTableValue`, `defaultCantripsKnown`, `defaultPreparedSpells`, `maxPreparableSpellLevel`, `spellSlotsForClass`, `CasterKind`), [[extra_attack_resolver]] (`resolveExtraAttackCountAt`), [[weapon_mastery_resolver]] (`resolveWeaponMasteryCountAt`), [[resource_pool_resolver]] (`resolveResourcePoolsAt`), `rule_config.dart`, `entity.dart`.
- Used by: [[pending_choices]] (`pendingChoicesFromPlan` consumes the flags), the editor level-up dialog UI.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Clamps `from`/`to` to [0,20]. `hitDie` normalized via `canonicalHitDie` (imported packs store `8`, SRD stores `"d8"`) — never throws an `as String?` cast.
- HP: `levelsGained * config.hpPerLevelFor(hitDie)` (fixed d6→4/d8→5/d10→6/d12→7). `effectiveHpDelta` adds `levelsGained * conModifier` (CON read post-ASI by the dialog so the screen matches what's applied); honors a manual `rolledTotal` over the average.
- Features: `_featuresInRange` reads `entity.fields['features']`, keeps rows with `afterLevel < level <= throughLevel`, sorts by (level, source). `_saveGrantsFromEffects` extracts save-proficiency names from `proficiency_grant` effects with `target_kind` saving_throw/ability.
- Flags detected over the (from,to] window: `isAsiOrFeatLevel` (`config.isAsiLevel`); `isExtraAttackLevel` (resolver-driven via `resolveExtraAttackCountAt`, with a fallback `_extraAttackFallbackLevels = {5}` only when no entity map); `isSubclassLevel` (feature-name contains "subclass"); `isDivineOrderLevel` (feature name == "Divine Order"); `isFightingStyleLevel` (feature name contains "fighting style" OR class `grants_fighting_style_at_levels` table).
- `featureOptionPicks`: 1-of-N subclass-feature picks from a hardcoded `featureOptionTriggers` set (Hunter's Prey, Defensive Tactics, Multiattack, Superior Hunter's Defense, Pact Boon, Draconic Spells, Fiendish Resilience) PLUS cumulative per-level pickers in `_cumulativePickProgression` (Sorcerer Metamagic 2/1/1 at L2/10/17; Warlock Eldritch Invocations 2/1/1/1/1/1/1 at L1/5/7/9/12/15/18). Option feats must be authored under category `Feature Option: <name>` in `feats_class.dart`.
- Caster fields populated only when `casterKind != none && toLevel > 0`: cantrip/prepared caps prefer authored `cantrips_known_by_level`/`prepared_spells_by_level` tables, fall back to the `caster_progression` defaults; slot maps via `_slotsAt`→`spellSlotsForClass` (authored `spell_slots_by_level` override beats SRD preset).
- `_classLevelsForLevel` builds a snapshot forcing the target class to the prev/new level (other classes preserved) so resource-pool `count_formula`s evaluate correctly across the bump (e.g. Paladin Lay on Hands 20→25).

## Notes
- MVP scope per the doc comment. Resource-pool / extra-attack / weapon-mastery deltas are 0 when no `entities` map is supplied (legacy callers); the L5 extra-attack fallback exists for exactly that case.
