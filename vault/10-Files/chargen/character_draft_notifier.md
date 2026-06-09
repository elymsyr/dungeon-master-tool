---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/character_draft_notifier.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `character_draft_notifier.dart`

> [!abstract] Primary Purpose
> Wizard-scoped `StateNotifier<CharacterDraft>` exposing intent-named mutators for every wizard step. Owned via `StateNotifierProvider.autoDispose` (`characterDraftProvider`) so state resets each time the wizard opens. Encapsulates the cross-field invalidation rules and the ability-score generation logic (random rolls, standard-array swap).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: constructed with an initial `CharacterDraft` (`const CharacterDraft()`); holds a private `Random`.
- Reads / Supabase / CDC / events: none — pure in-memory state.
- Triggers: UI callbacks from wizard steps.

**Outputs**
- Providers exposed: `characterDraftProvider = StateNotifierProvider.autoDispose<CharacterDraftNotifier, CharacterDraft>`.
- Public API: the full set of `set*`/`toggle*`/`clear*`/`add*`/`remove*` mutators.

## Dependencies & Links
- Depends on: [[character_draft]] (state type), [[ability_score_method]] (`AbilityScoreMethod`, `kAbilityKeys`), `flutter_riverpod`, `dart:math`.
- Used by: every character-creation wizard step widget.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Mutually-exclusive sources: `setWorld` clears `sourcePackages`; `setSourcePackages` clears `worldName`.
- Cascading resets (cross-field invalidation): `setRace` clears `subspeciesId`; `setClass` clears `subclassId`, skill/tool/cantrip/preparedSpell/weaponMastery/bonusLanguage choices and `l1OrderChoiceId` (all class-scoped); `setBackground` clears `backgroundToolVariantId`.
- `setLevel` clamps 1-20.
- `toggle*` mutators (skill/tool/language/bonusLanguage/weaponMastery/cantrip/preparedSpell) require a `cap` and **no-op when the cap is reached** so the UI's disabled state matches stored state; paired `clear*` methods empty the list.
- Ability scores: `setAbilityMethod` resets `baseAbilities` to the method's natural starting layout (`_initialScoresFor`: standardArray 15/14/13/12/10/8, pointBuy all 8, random/manual all 10) and zeroes `racialBonuses`. `setAbility` plain set; `swapAbility` (standard array) swaps the value with whichever ability currently holds it to keep a valid permutation. `rollRandomAbilities` = 4d6-drop-lowest ×6 into `kAbilityKeys` order. `rollTrinket(table)` picks a random entry (caller passes `kSrdTrinkets` so the notifier stays Flutter-free).
- Feats: `addFeatId` dedupes; `removeFeatId` filters; `setOriginFeatChoice(key, optionId)` writes into `originFeatChoices`.

## Notes
- `autoDispose` is intentional — opening the wizard always starts from a fresh draft.
