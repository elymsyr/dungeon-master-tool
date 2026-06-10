---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/rules/choice_spec.dart
layer: domain
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `choice_spec.dart`

> [!abstract] Primary Purpose
> Constrained-choice descriptor (rules engine PR-R5; roadmap 1.4): "pick N of set / pick a distribution" as first-class data. Unifies background ASI distributions (`asi_distribution_options` → `[[2,1],[1,1,1]]`), class/subclass skill+tool pick counts, background bonus languages, and feat `choice_group` rows (legacy wire = alias of `choice_spec`).

## Inputs / Outputs
- `ChoiceSpec {specId, label, pickKind, pick, options, distributions}`.
- `parseDistributions(['+2/+1', ...])` · `matchesDistribution(picks)` (empty distributions = unconstrained — official packs ship none, so no new warnings on imported content) · `fromEffectRow` (`choice_spec` | `choice_group`).

## Dependencies & Links
- Used by: [[rule_compiler]] `compileChoiceSpecs` (per-attachment derivations), [[pending_choices]] `seedFeatChoicePendings`, [[level_up_planner]] (when_level_up `choice_spec` rows → featureOptionPicks, PR-R6), [[character_resolver]] (background_asi distribution validation — warning only).
- Domain map: [[Character-System]] · System flow: [[Rules-Engine-Triggers]]
