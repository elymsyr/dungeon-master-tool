---
type: file-note
domain: world-content
path: flutter_app/lib/domain/services/free_srd_pack.dart
layer: domain
language: dart
status: active
updated: 2026-10-28
tags: [file]
---

# `free_srd_pack.dart`

> [!abstract] Primary Purpose
> The free SRD package's converter (`docs/free-template/SRD-FREE-ALANLAR.md` §8, K11): the one place that turns the core SRD pack's cards into the shape the ready-made free template (`srdFreeTemplate`) reads. It runs when the package is seeded, so the free package needs no read-time conversion; the core pack itself never changes (ROADMAP K1). The work grows phase by phase (A1–A10, §11); A1 only writes into the data what [[free_field_styles]] and [[free_srd_levels]] read out of the SRD shapes.

## Inputs / Outputs
**Inputs**
- One pack card ([[entity]], `_lookup` placeholders unresolved, ids already the free package's) and every pack card by id.
- `srdFreeTemplate`'s categories ([[free_template]]).

**Outputs**
- `freeSrdFields(card, byId)` → the card's fields as the free template shows them.
- `freeSrdPackVersion` — bumped whenever the converter writes something new; the free package re-seeds on a change.

## Dependencies & Links
- Depends on: [[free_field_styles]] (`freeFieldValue`, `structuredListAsMarkdown`), [[free_srd_levels]] (through `freeFieldValue`), [[entity_ref]] (`entityRefName`), [[free_template]] (`srdFreeTemplate`)
- Used by: [[srd_core_package_bootstrap]] `_ensureFree` (the only caller)
- Domain map: [[World-and-Content]]
- Spec / reference: `docs/free-template/SRD-FREE-ALANLAR.md` §8, §11

## Key Logic / Variables
- **A1 (2026-10-28):** for every field of the card's category in the free template, the stored value becomes what `freeFieldValue` shows: `srd_read` Level tables and Grants (class / subclass features with slots and level-bound pools, spells at level, own pools) as free rows and items with `_id`; Monster / Animal flat AC / HP / Initiative as the Combat stats block; a markdown field's SRD list (starting equipment, player choices, subspecies options) as its markdown text. A value that reads as nothing but was not empty (a feat's level-bound pool, granted from the class rows) is stored empty, never left in its SRD shape.
- Refs and `_lookup` placeholders stay: the world resolves them when it synthesises the card ([[builtin_synth]]), the installer when it copies it.
- Categories the free template lacks pass through untouched.

## Notes
- Tests: `test/domain/services/free_srd_pack_test.dart` — A1 equivalence (every card and field shows the same as the SRD read did, placeholders resolved as a world resolves them), "stored data needs no read", and the G7 guard (filled fields declared in the copy except the known leftovers of later phases, no link to a missing category, every added field filled somewhere).
