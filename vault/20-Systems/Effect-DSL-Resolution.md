---
type: system
domain: chargen
updated: 2026-06-10
tags: [system]
---

# Effect-DSL Resolution

> [!summary] What this is
> How descriptive content entities (class/subclass/species/feat + their child features) become a typed `EffectiveCharacter`. Content carries an effect DSL; [[character_resolver]] is a pure read-time function that folds 50+ effect kinds into derived stats. Owned by [[Character-System]].

## Participants
- [[srd_helpers]] — authoring side: `effect(kind, targetKind, value, predicates, scalesWith, activation)`, `predicate`, `scalesWith`, `activation`, `autoGrantBy`.
- [[character_resolver]] — application side: walks granted features, applies effects.
- [[effective_character]] — output view (carries warnings for dropped refs).
- [[level_up_planner]] / resolvers — derive counts (extra attack, mastery, pools) from effects.

## Flow
1. Character holds class_levels, subclass_id, feat_ids, species, equipment_choices.
2. Resolver gathers auto-granted features (`autoGrantBy` + `at_level` gates) and chosen options.
3. For each effect, check `predicates` (AND-combined) and `scalesWith` (class-level tables).
4. Apply by `kind`: ability/AC/speed/HP bonus, proficiency, expertise, sense (e.g. Drow 120 ft darkvision), language/spell/cantrip grant, damage/condition immunity, extra_attack, crit_range, resource_pool (with `count_formula`), state grant, advantage/disadvantage, etc.
5. Missing refs silently dropped → surfaced as warnings on [[effective_character]].
6. **Prerequisite pass (PR-R1, warn-keep):** after folding, every chosen feat's prerequisite clauses ([[prereq_evaluator]]) are re-checked against the final state; failures become typed `UnmetPrerequisite` warnings on [[effective_character]] (mechanics stay applied). The same interpreter filters the feat picker, so the two surfaces can't drift.

## Key Constants / Invariants
- Resolver is **stateless / pure** — safe to call per read; no side effects.
- 50+ effect kinds. Effects gated by predicates + level. Refs may be hard or soft → see [[Ref-Resolution-Hard-vs-Soft]].

## Related
- MoCs: [[Character-System]], [[Content-Pipeline]]
- Source Docs: `flutter_app/docs/chargen_mechanics_wiring.md`, `missing_mechanical_effects_audit.md`
