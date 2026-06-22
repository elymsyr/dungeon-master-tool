---
type: system
domain: world-content
updated: 2026-06-22
tags: [system]
---

# Template System — Dynamic Schema & Rules Architecture

> [!summary] What this is
> The approved migration (2026-06-10) from hardcoded schema + per-card DSL rules to a user-editable JSON Template that owns both field definitions and rule semantics. An entity card becomes pure data; rules fire from field semantics declared once in the template. Owned by [[World-and-Content]] / [[Character-System]].

## Why it exists — Current pain points
1. **Schema is code.** 74 categories in `builtin_dnd5e_v2_schema.dart`; changing a field requires an app build.
2. **Rules live on cards.** Every card is a tiny program (effects DSL, `rule_effects`, `granted_modifiers`…); creators must understand DSL to author content.
3. **Template editor is read-only.** Users cannot create, copy, or edit templates.

## Target architecture
- A **Template** is a `WorldSchema` JSON document (format version 3) defining categories, fields, and **rule semantics** attached to fields. Dual-hash drift detection + `applyTemplateUpdate` reused verbatim.
- An **entity card is pure data** — the DM fills values; rules fire from the template's field `when_granted` / `when_equipped` / `when_condition` semantics.
- Cards carry a **complete player-facing Markdown description** (prerequisites, level-up effects, equip rules). Automation is a synchronized bonus layer on top of readable text.
- Templates live in a **hub-level library**: list view, copy the built-in, edit copies. Built-in SRD template ships read-only.

## Three strategic shifts (override earlier plans)
1. **Rule reset first.** Built-in template extracted to JSON with zero rule-assigned fields. App runs rule-free on new infrastructure before any rule exists.
2. **Just-In-Time template evolution.** A rule-bearing field is added to the template **only at the moment a card needs it**. End-state: zero dead fields (enforced by automated usage audit).
3. **Description-first cards.** Every card's `description` is completed into standalone standard-format Markdown; the rule fields keep the sheet in sync with the text.

## Phase plan (4 phases, approved 2026-06-10)
See `docs/new_system/master-roadmap.md` for the authoritative detail. High-level:

| Phase | Focus | Status |
|---|---|---|
| **Phase 1** | Infrastructure: Template JSON schema, hub library UI, TemplateEditor (responsive), copy/edit/rename/delete flows, rule-reset built-in | Planned |
| **Phase 2** | SRD card description pass (description-first, static field preservation, checklist `docs/new_system/static-field-preservation-checklist.md`) | Planned |
| **Phase 3** | JIT rule wiring — add rule-bearing fields to template one category at a time, automated usage audit gate | Planned |
| **Phase 4** | Content converter pipeline (`docs/new_system/content-convert.md`), Open5e pack re-emit on new format | Planned |

## Template Editor — Responsive UI
```
Hub ── Templates tab (list: built-in [View][Copy] · copies [Edit][Rename][Delete])
       └─ /template/edit  →  TemplateEditorScreen
            desktop ≥1200 ── 3-pane: [Categories 240px] | ResizableSplit( [Fields] | [Field Inspector] )
            tablet 600-1199 ─ 2-pane: [Categories ⇄ Fields drill] | [Field Inspector]
            phone <600 ────── stacked: Categories → Fields → Field Edit
```
Follows existing `ScreenType` breakpoints + `ResizableSplit` pattern (as in `database_screen.dart`).

## Key Invariants
- **PC sheet pixel parity** — new field types reuse existing value wire-shapes verbatim (no 20k-card value migration).
- **Dual-stack authority** — worlds on v2 embedded schema keep resolving on the old engine until migrated; no character breaks mid-transition.
- **Static fields are sacred.** Narrative text/markdown fields (story, biography, notes, description) are never deleted; governed by `docs/new_system/static-field-preservation-checklist.md`.
- **Closed rule vocabulary.** Rule kinds are a closed set; mechanics that don't fit go into `description` Markdown. New kinds are never invented mid-migration.

## Participants (once implemented)
- [[builtin_schema]] — will emit JSON template on build instead of Dart code.
- [[world_schema]] / [[entity_category_schema]] / [[field_schema]] — extended with template fields + rule semantics.
- [[srd_helpers]] — rule DSL authoring moves to template field config.
- [[character_resolver]] — reads rules from template field semantics instead of per-card effect rows.

## Related
- MoCs: [[World-and-Content]], [[Character-System]], [[Content-Pipeline]]
- Supersedes: Rules Engine initiative (frozen after R6; R7 cancelled); see `rules_engine_initiative_jun10` memory.
- Source Docs: `docs/new_system/master-roadmap.md` (authoritative), `docs/new_system/the-template-system.md` (format spec), `docs/new_system/content-convert.md` (converter pipeline), `docs/new_system/static-field-preservation-checklist.md`.
