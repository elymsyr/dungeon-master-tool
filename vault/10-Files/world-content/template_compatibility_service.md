---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/template_compatibility_service.dart
layer: application
language: dart
status: active
updated: 2026-10-12
tags: [file]
---

# `template_compatibility_service.dart`

> [!abstract] Primary Purpose
> Before a package is installed into a world, compares the package's template with the world's and says what won't line up. The import dialog shows the result on each package card and decides whether installing needs a confirmation.

## Inputs / Outputs
**Inputs**
- `check(packageSchema, worldSchema, {usedCategorySlugs})` — `usedCategorySlugs`: categories the package actually has cards in (free path only).

**Outputs**
- `TemplateCompatibility` (`domain/entities/schema/template_compatibility.dart`): `level` (perfect / compatible / incompatible), `warnings`, added / removed fields and categories, `byKey`.

## Dependencies & Links
- Depends on: [[free_template]] (`isFreeTemplate`), [[world_schema]]
- Used by: `import_package_dialog.dart` (`_PackageImportCard`)
- Domain map: [[World-and-Content]]
- Spec: `docs/free-template/DESIGN.md` §15.2 (D11), ROADMAP Faz 5

## Key Logic / Variables
- **Either side free → `_checkByKey`** (Y4): categories by slug, fields by `fieldKey` (a free template's labels change freely). Lists only what won't show: package categories missing from the world (by name) and package fields missing from the world's category (`"Category: Label"`). Categories without package cards are skipped. Nothing missing → `perfect`; else `compatible` + `byKey`, and the dialog asks **Cancel / Install anyway** (the data stays in the package — the installer copies slug + fields verbatim).
- **Built-in ↔ built-in** — the old path, unchanged: hash + lineage (`originalHash`), category names and field labels, `incompatible` when no category is shared (→ "Force" button).
