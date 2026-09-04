---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/template_mechanics.dart
layer: domain
language: dart
status: stable
updated: 2026-09-04
tags: [file]
---

# `template_mechanics.dart`

> [!abstract] Primary Purpose
> The single predicate that decides whether a template runs automatic mechanics. Only the shipped built-in D&D 5e template does; every user template — **including a byte-identical copy of the built-in** — is pure schema-driven data.

## Inputs / Outputs
**Inputs**
- `templateIdHasMechanics(String? templateId)` — the world/character `template_id`.
- `schemaHasMechanics(WorldSchema?)` — convenience wrapper over `schema.schemaId`.

**Outputs**
- `bool`. Nothing else; no state, no config.

## Dependencies & Links
- Depends on: [[builtin_schema]] (`builtinDnd5eV2SchemaId`), [[world_schema]]
- Used by: `character_creation_wizard_screen` (template list filter), `templates_tab` / `template_editor_screen` (read-only vs editable, "No automation" badge)
- Domain map: [[World-and-Content]]
- System flow: [[Template-System]], [[Grant-Resolution]]

## Key Logic / Variables
- `templateIdHasMechanics(id) => id == builtinDnd5eV2SchemaId`. That is the whole rule.
- **Why a copy is also mechanics-free** (decision 2026-09-04): grant resolution, the chargen wizard, SRD bootstrap and spell-slot/resource derivation are all bound to built-in category slugs (`class`, `species`, `player`, …) and the closed `CharacterResolver.grantFieldKeys` contract. A copy is editable, so the moment a category or field moves the resolver produces silently wrong output. A rule of "works until you break it" has no observable boundary; "built-in only" does.
- The gate is enforced by **omission**, not by branches inside the resolver: the wizard never offers a non-built-in template, so no character is ever created with one, so `effectiveCharacterProvider` never resolves against custom data. `WorldRepositoryImpl.create` and `world_repository_impl.load` already gate SRD bootstrap on the same id, and `synthesizeWorldBuiltins` self-gates on the SRD pack being installed.

## Notes
- Adding a new automatic mechanic means asking whether it belongs behind this predicate. If it reads a built-in slug or a `grantFieldKeys` key, it does.
