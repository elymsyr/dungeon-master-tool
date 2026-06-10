---
type: system
domain: chargen
updated: 2026-06-10
tags: [system]
---

# Rules-Engine Triggers

> [!summary] What this is
> The unified, trigger-based rules engine (initiative 2026-06-10, PR-R1..R7). ALL character/item mechanics flow through one rule model: explicit effect rows + implicit rules **compiled dynamically from the typed fields on each card** by [[rule_compiler]] — no migration of the 20k+ pack cards. Plan: `~/.claude/plans/checkout-system-mechanics-roadmap-md-des-floating-twilight.md`; audit: repo-root `system_mechanics_roadmap.md` + `entity_audit_log.md`.

## Participants
- [[rule_trigger]] — 8-trigger taxonomy + backward-compatible defaults for absent `trigger` keys.
- [[bound_rule]] — compiled rule value type (trigger, gate, provenance, clauses).
- [[rule_compiler]] — field→rule derivation per attachment; PARITY CONTRACT with legacy pass order.
- [[prereq_evaluator]] — clause interpreter; pickers filter, resolver warn-keeps.
- [[character_resolver]] — the interpreter: gather sources → compile → `applyBound` (internal kinds + `applyEffect` funnel) → prereq validation pass.
- `rules/dnd5e_rule_catalog.dart` — declares `prerequisite` kind + per-rule `allowedTriggers`; `rule_validator` checks trigger/clauses placement.

## Flow
1. Resolver gathers grant sources (classes, subclass, species/subspecies, background, feats, traits, equipped items) — unchanged pass skeleton.
2. Per source, [[rule_compiler]] emits ordered BoundRules (explicit rows + field-derived implicit rules, gates pre-applied).
3. `applyBound`: prereq + when_attuned rules skipped; internal kinds run legacy logic verbatim; the rest flow through `applyEffect`.
4. Prereq pass (warn-keep): feat gates evaluated against final accumulators → `UnmetPrerequisite` warnings on [[effective_character]]; same clauses filter the pickers.

## Key Constants / Invariants
- **Parity harness (PR-R2)**: frozen `character_resolver_legacy.dart` + debug assert at `effectiveCharacterProvider` — byte-identical JSON or throw. Deleted in PR-R7.
- `when_granted` ≡ `always_on` at fold time (stateless re-resolve; no event timeline).
- Wire additions are OPTIONAL keys (`trigger`, `trigger_args`, `clauses`) on existing effect rows — absent keys = legacy behavior.
- Internal compiler kinds never appear in the catalog/editor: `trait_grant`, `alternate_speed`, `level_gated_spells`, `background_asi_apply`, `feat_asi_apply`, `proficiency_grant_raw`, `feature_row`.

## Status
- R1 (prereq foundation) + R2 (compiler/interpreter parity refactor) SHIPPED 2026-06-10. R3 editor UI, R4 attunement, R5 choice_spec, R6 level-up, R7 cleanup pending.

## Related
- MoCs: [[Character-System]] · Systems: [[Effect-DSL-Resolution]] · [[Ref-Resolution-Hard-vs-Soft]]
