---
type: file-note
domain: chargen
path: flutter_app/lib/domain/entities/character/effective_character.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `effective_character.dart`

> [!abstract] Primary Purpose
> Immutable Freezed value object: the read-time computed view of a `Character` produced by `CharacterResolver.resolve`. **Never persisted** — recompute on every read. Aggregates every derived stat (abilities, proficiencies, AC, speeds, HP bonuses, grants, resource pools, conditional/state-gated grants) that the character sheet and editor render.

## Inputs / Outputs
**Inputs**
- Pure Freezed data classes; JSON-serializable. No providers/DAOs/IO.

**Outputs**
- Public API: `EffectiveCharacter` (the main aggregate) plus the line-item types `ResolvedInventoryItem`, `ResolvedFeatureRow`, `ResolvedProficiencies`.

## Dependencies & Links
- Depends on: `freezed_annotation` only.
- Used by: [[character_resolver]] (constructs it), the character sheet / editor UI (reads it).
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- `ResolvedInventoryItem`: `entityId`, `quantity`, free-form `source` tag (`class:Fighter:option:A`, `background:Soldier`, `feat:Magic Initiate`).
- `ResolvedFeatureRow`: `{level, description, sourceEntityId}` — narrative only (mechanics flow through auto-grant on the feat/trait entity, not the row).
- `ResolvedProficiencies`: skillIds, toolIds, savingThrowAbilityIds, languageIds, weaponCategoryIds, armorCategoryIds.
- `EffectiveCharacter` notable fields: `classLevels`, `subclassId`, `featIds`, `effectiveAbilities` (post-grant, default all 10), `proficiencies`, `acBonus` + computed `armorClass` (sheet prefers this over manual `combat_stats.ac`) + `armorNotes` (SRD 5.2.1 worn-armor penalties), `speedBonus` + `extraSpeeds` (fly/swim/climb/burrow, larger-wins), `hpBonusFlat`/`hpBonusPerLevel`, `initiativeBonus`, granted spell/cantrip ids, `activeFeatures`, `inventory`, `senseEntityIds` + `senseRanges` (per-sense ft overrides, e.g. Drow 120ft, larger-wins), damage res/imm/vuln ids, condition immunity ids, `conditionalGrants` (state-gated `{state, kind, ids, source}`), `tempHpGrants`, `expertiseSkillIds`, `alwaysPreparedSpellIds`, `autoGrantedFeatIds` / `autoGrantedTraitIds` (rendered as "Class Features" vs chosen), granted action/bonus-action/reaction ids, `unarmoredFormulas` (raw effect rows for AC composition), `extraAttackCount` (multiclass takes max not sum), `critRangeMin` (default 20), `resourcePools` (`{pool_ref, max, recharge}`), `grantSources` (id → ordered source names for chip subtitles), `freeCastSpellIds`, `ritualBookSpellIds`, `activeConditionIds`, `warnings`.

## Notes
- Generated parts `effective_character.freezed.dart` + `.g.dart` (not authored). Field doc-comments in the source carry the precise "larger wins" / "runtime writes happen elsewhere" invariants reflected above.
