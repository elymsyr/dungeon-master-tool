---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/rules/prereq_evaluator.dart
layer: domain
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `prereq_evaluator.dart`

> [!abstract] Primary Purpose
> Shared prerequisite-clause interpreter (rules-engine PR-R1; roadmap 1.1+1.2). One clause vocabulary, two consumers with different policies: picker dialogs FILTER candidates; [[character_resolver]] WARN-KEEPs (typed `UnmetPrerequisite` on [[effective_character]], mechanics still applied).

## Inputs / Outputs
**Inputs**
- Pure functions — no providers, DAOs, or events. Callers supply a `PrereqContext` snapshot + entity map.

**Outputs**
- `PrereqContext` — character-state snapshot (characterLevel, abilityScores by abbrev, hasSpellcasting, lowercased armor/weapon proficiency names, proficient skill NAMES, nullable `classLevelsById`/`speciesId`/`alignmentId` where null = unknown → matching clauses never block).
- `evaluatePrereqClauses(clauses, ctx, entitiesById)` → `PrereqResult {passed, clauses: [ClauseResult {passed, description}]}` with human-readable failed descriptions for banners.
- `effectivePrereqClauses(fields)` — typed `prereq_clauses` when present, else flat `prereq_*` fields lowered into clause shapes (incl. the previously-unenforced `prereq_class_refs`/`prereq_species_refs`/`prereq_requires_spellcasting` — intended tightening).

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef`), `entity.dart`.
- Used by: [[character_resolver]] (Pass 10 warn-keep), `pending_choice_resolver_dialog` (feat candidate filtering), `PrereqClausesFieldWidget` shape spec.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]

## Key Logic / Variables
- Clause semantics: ALL-of across clauses; OR within option lists (`ability_min`, `skill_proficiency`, `class_ref`, `species_ref`, `alignment_ref`); `other`/unknown types NEVER block — ported verbatim from the dialog's historical `_passesPrereqClauses`.
- Clause types: `character_level {min_level}`, `ability_min {ability_options[], min_score}`, `spellcasting`, `armor_proficiency {category|category_ref}`, `weapon_proficiency {weapon_class: simple|martial|any}`, `skill_proficiency {skill_options[]}`, `class_ref {class_options[], min_level?}`, `species_ref`, `alignment_ref`.
- Option refs tolerate both wire shapes: entity-id `String` and importer `{_lookup/_ref, name}` maps (name fallback for display + ability abbrev mapping).
- Skill comparison is by NAME (dialog legacy), not id.

## Notes
- The wire shape spec also lives on `FieldType.prereqClauses` (field_schema.dart). `prereq_clauses` declared on feat (content.dart `_featCategory`) as of template v2.5.0 — closes the 22-feat undeclared-key hole.
