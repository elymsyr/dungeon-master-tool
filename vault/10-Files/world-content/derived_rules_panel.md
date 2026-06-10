---
type: file-note
domain: world-content
path: flutter_app/lib/presentation/widgets/derived_rules_panel.dart
layer: presentation
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `derived_rules_panel.dart`

> [!abstract] Primary Purpose
> Read-only "Rules (compiled)" panel on rule-bearing entity cards (rules engine PR-R3). Runs [[rule_compiler]] `compile(entity, attachment, gateLevel: 20)` and lists every rule the card contributes grouped by trigger, with "compiled from `<field>`" vs "authored" captions and a "not mechanized" badge for prose-only cards / feature levels (roadmap 1.3 placeholder state). Never editable, never persisted.

## Dependencies & Links
- Depends on: [[rule_compiler]], [[bound_rule]], [[rule_trigger]], [[entity_ref]].
- Used by: `entity_card` (mounted after schema fields for class/subclass/species/subspecies/background/feat/trait/weapon/armor/magic-item via `DerivedRulesPanel.supports`).
- Domain map: [[World-and-Content]] · System flow: [[Rules-Engine-Triggers]]

## Key Logic / Variables
- `_attachmentBySlug` maps category slug → `RuleAttachment`; unsupported slugs render nothing.
- "Not mechanized" detection: feature_row levels with prose but no same-level effect rules; or zero mechanical rules + non-empty description.
