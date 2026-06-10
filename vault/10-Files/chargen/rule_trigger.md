---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/rules/rule_trigger.dart
layer: domain
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `rule_trigger.dart`

> [!abstract] Primary Purpose
> The 8-trigger taxonomy of the rules engine (PR-R2): `always_on`, `when_granted`, `when_level_up`, `when_equipped`, `when_attuned`, `prereq_to_grant`, `prereq_to_equip`, `prereq_to_attune` — wire strings + `fromWire` + `isPrereq` + backward-compatible `defaultFor(categorySlug)`.

## Key Logic / Variables
- **`when_granted` ≡ `always_on` at fold time** — the resolver is a stateless re-resolve with no event timeline; the distinction drives pending-choice generation + editor display only. The doc table in the file is the authoritative semantics spec.
- `defaultFor`: weapon/armor/magic-item `rule_effects` → whenEquipped; everything else → alwaysOn; feature-row effects → whenLevelUp (caller passes `inFeatureRow`). Absent `trigger` keys = these defaults, which is what keeps every existing pack/SRD row resolving unchanged.
- `when_attuned` rules are inert until the attunement runtime (PR-R4); prereq triggers never fold stats (warn-keep via [[prereq_evaluator]]).

## Dependencies & Links
- Used by: [[rule_compiler]], [[character_resolver]], rule editor (R3), `rule_validator`.
- Domain map: [[Character-System]] · System flow: [[Rules-Engine-Triggers]]
