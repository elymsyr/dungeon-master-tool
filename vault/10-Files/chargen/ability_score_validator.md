---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/ability_score_validator.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `ability_score_validator.dart`

> [!abstract] Primary Purpose
> Pure, UI/IO/Riverpod-free validator for ability-score assignments against the chosen `AbilityScoreMethod`, plus the SRD ability-modifier helper and the Background-ASI soft-cap check. Returns `null` on success or a human-readable reason string.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — static class methods + one top-level function.
- Reads: caller-supplied `AbilityScoreMethod method` and `Map<String,int> scores` / `bonuses`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `AbilityScoreValidator.validate({method, scores})`, `.pointBuyCost(scores)`, `.validateBackgroundAsi(bonuses)`; top-level `int abilityModifier(int score)`.

## Dependencies & Links
- Depends on: [[ability_score_method]] (`kAbilityKeys`, `kStandardArray`, `kPointBuyCosts`, `kPointBuyBudget`), `rule_config.dart` (`RuleConfig.dnd5eDefaults.abilityModifier`).
- Used by: the wizard Abilities step; [[character_draft_notifier]] / commit path validation.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1

## Key Logic / Variables
- `validate`: first checks all six `kAbilityKeys` present (missing key → error); then switches by method:
  - standardArray — must be an exact permutation of `kStandardArray` (consume-from-remaining check).
  - pointBuy — each score in 8-15, total `pointBuyCost <= 27`.
  - random — range 3-18.
  - manual — range 3-20.
- `pointBuyCost`: sum of `kPointBuyCosts`; returns **-1** if any score is outside the buyable 8-15 window (caller treats as invalid).
- `validateBackgroundAsi` (SRD 2024 soft cap): each ability bonus ≥ 0 and ≤ +2, total ≤ +3 (allows +2/+1, +1/+1, or +1/+1/+1).
- `abilityModifier(score)` = `floor((score-10)/2)` via the single `RuleConfig` source; negative scores allowed.

## Notes
- Missing scores default to 10 in all range/cost checks.
