---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_template.dart
layer: domain
language: dart
status: active
updated: 2026-10-11
tags: [file]
---

# `free_template.dart`

> [!abstract] Primary Purpose
> The pure functions behind free templates (`docs/free-template/DESIGN.md`): the single gate `isFreeTemplate`, the SRD / free copy converter and the empty template. Built-in and free code paths branch only on `isFreeTemplate` (ROADMAP K3).

## Inputs / Outputs
**Inputs**
- A source `WorldSchema` (built-in or free), a new id, name and ISO timestamp.

**Outputs**
- `isFreeTemplate(schema)` — `schema.freeRootId != null`.
- `isSrdLineage(schema)` — lineage root is `builtinDnd5eV2SchemaId`.
- `copyAsFreeTemplate(source, id:, name:, now:)` → new free `WorldSchema`.
- `emptyFreeTemplate(id:, name:, playerCardName:, now:)` → template with only the player card.

## Dependencies & Links
- Depends on: [[world_schema]], [[entity_category_schema]], [[field_schema]], [[builtin_schema]] (id constant only)
- Used by: [[template_provider]]
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/DESIGN.md` §6.2, §16; `docs/free-template/ROADMAP.md` Faz 1

## Key Logic / Variables
- **Lineage:** `freeRootId = source.freeRootId ?? source.schemaId`, so SRD → copy → copy-of-copy all point at the built-in id; an empty template points at itself.
- **SRD copy (v1):** `player-character` gets `isPlayerCard: true`; `crCalculator` fields are dropped (`_droppedOnCopy`). Every other category, field, group, encounter config and metadata is kept verbatim — later phases add conversions here (ROADMAP §6).
- Category/field ids are **kept** (scoped to the schema); every category's `schemaId` is rewritten to the new id.
- `originalHash` is frozen at creation = `computeWorldSchemaContentHash(copy)`.
- `isBuiltin` flags on copied categories/fields are left as is: nothing reads the schema-level flag (checked 2026-10-11; the `isBuiltin` reads in the app are about packages/cards).

## Notes
- Test: `test/domain/services/free_template_test.dart`.
