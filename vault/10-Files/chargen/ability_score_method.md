---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/ability_score_method.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `ability_score_method.dart`

> [!abstract] Primary Purpose
> Defines the `AbilityScoreMethod` enum (the ability-generation method picked in the wizard) plus the canonical SRD ability-score constants. Each method maps to a different validator + UI affordance.

## Inputs / Outputs
**Inputs**
- None — pure declarations (enum + extension + `const` constants).

**Outputs**
- Public API: `enum AbilityScoreMethod { standardArray, pointBuy, random, manual }`; `AbilityScoreMethodX.label` (display strings); constants `kAbilityKeys`, `kStandardArray`, `kPointBuyBudget`, `kPointBuyCosts`.

## Dependencies & Links
- Depends on: nothing.
- Used by: [[ability_score_validator]], [[character_draft]], [[character_draft_notifier]] (initial-score layouts + `kAbilityKeys`).
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1

## Key Logic / Variables
- `kAbilityKeys = ['STR','DEX','CON','INT','WIS','CHA']` — canonical order.
- `kStandardArray = [15,14,13,12,10,8]` (descending).
- `kPointBuyBudget = 27`.
- `kPointBuyCosts = {8:0, 9:1, 10:2, 11:3, 12:4, 13:5, 14:7, 15:9}` — scores outside 8-15 are unbuyable.
- Method semantics (from doc comments): standardArray = distribute 15/14/13/12/10/8; pointBuy = 27 pts, 8-15; random = 4d6-drop-low ×6; manual = free entry, clamped 3-20 by the validator.

## Notes
- Holds only data + the enum; all rule enforcement lives in [[ability_score_validator]].
