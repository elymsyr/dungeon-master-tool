---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/rules/bound_rule.dart
layer: domain
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `bound_rule.dart`

> [!abstract] Primary Purpose
> Value types of the rules engine: `RuleAttachment` (how a source entity attaches to the character — classHeld/subclass/species/.../equippedItem/attunedItem) and `BoundRule` — one compiled, character-bound rule: effect row + trigger + gate (`atLevel`/`gateClassId`) + provenance (`sourceLabel` in the historical `kind:Name` shape, `derived`/`derivedFromField` for the editor's read-only "compiled from <field>" captions) + `noteSourceOverride`/`clauses`.

## Dependencies & Links
- Depends on: [[rule_trigger]].
- Used by: [[rule_compiler]] (producer), [[character_resolver]] `applyBound` (consumer), derived-rules panel (R3).
- Domain map: [[Character-System]] · System flow: [[Rules-Engine-Triggers]]

## Notes
- List order is load-bearing (grantSources/skills/warnings orders are user-visible) — see the parity contract in [[rule_compiler]].
