---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/character_draft.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `character_draft.dart`

> [!abstract] Primary Purpose
> Immutable Freezed value object holding every answer the character-creation wizard collects. Survives step navigation in memory; committed to `characterListProvider` only on the Review step. All entity-id fields reference entities the active campaign/packages already provide — the wizard never authors new entities.

## Inputs / Outputs
**Inputs**
- Freezed `@freezed` data class; JSON-serializable (`fromJson`/`g.dart`). No providers/DAOs/IO of its own.

**Outputs**
- Public API: the `CharacterDraft` record + all its fields; mutated only via `copyWith` (driven by [[character_draft_notifier]]).

## Dependencies & Links
- Depends on: [[ability_score_method]] (`AbilityScoreMethod`), `freezed_annotation`.
- Used by: [[character_draft_notifier]] (state type), the wizard steps, and the commit path that builds the persisted `Character`.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
Notable fields and their semantics (defaults in parens):
- Source selection: `worldName` and `sourcePackages` are **mutually exclusive** (picking a world clears packages and vice-versa); built-in SRD always implicit. `sourcePackages` persisted onto the committed character's `source_packages` so the editor re-resolves the same entities.
- `templateId`/`templateName` — must contain a Player category; resolved up-front by the launcher.
- Core refs: `raceId`, `classId`, `backgroundId`, `subclassId` (resolver gates by `granted_at_level`), `subspeciesId` (lineage key resolved against species `subspecies_options`).
- `level` (1) clamp 1-20; `alignment` (free text).
- Choice maps/lists, each capped against a class/background field: `equipmentChoices` (key = `group_id`, value = `option_id`), `skillChoiceIds` (cap `skill_proficiency_choice_count`; background skills auto-applied separately), `toolChoiceIds`, `languageChoiceIds` (origin step, cap `OriginConstants.standardLanguageChoiceCount`), `bonusLanguageChoiceIds` (class-granted, separate cap), `weaponMasteryChoiceIds` (Barb 2 / Fighter 3 / others 2, filtered by `weapon_mastery_filter`), `backgroundToolVariantId`, `l1OrderChoiceId` (Cleric Divine / Druid Primal Order — adds a feat), `cantripIds` (`level==0`), `preparedSpellIds` (level ≥1).
- Feats: `featIds` (background `origin_feat_ref` added implicitly), `originFeatChoices` (key `<featId>:<groupId>` → option_id).
- Flavor: personalityTraits/ideals/bonds/flaws/backstory/trinket (free text, not gated).
- Abilities: `abilityMethod` (default standardArray); `baseAbilities` (all 10s default); `racialBonuses` (stored separately so racial reassignment doesn't lose base scores).

## Notes
- Generated parts `character_draft.freezed.dart` + `.g.dart` (not authored).
