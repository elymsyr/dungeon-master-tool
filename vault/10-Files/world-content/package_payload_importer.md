---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/package_payload_importer.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `package_payload_importer.dart`

> [!abstract] Primary Purpose
> Imports an Open5e-style content payload (`package_name` + `metadata` + `entities`) into the local package store, attaching the LIVE built-in v2 schema (not a frozen copy) so the pack always renders against the current category/field definitions. Shared by the bundled-assets installer and the marketplace official-catalog installer.

## Inputs / Outputs
**Inputs**
- Constructor: `PackageRepository _repo`.
- `install(payload, installedFrom, extraMetadata?)`.

**Outputs**
- Returns the local package name.
- Writes via `_repo.save(packageName, {...})` — `entities`, `world_schema` (live built-in v2 JSON), `template_id` = `builtinDnd5eV2SchemaId`, `template_original_hash` = `builtinDnd5eV2OriginalHash`, `metadata`.

## Dependencies & Links
- Depends on: [[srd_core_pack]] (built-in v2 schema generator), `PackageRepository` (`package_repository`), [[packages_dao]] (via repo)
- Used by: [[bundled_packs_bootstrap]], [[first_party_catalog_service]] (official-catalog installer)
- Domain map: [[World-and-Content]]
- System flow: [[Content-Pipeline]]
- Spec / reference: [[Open5e-API]]

## Key Logic / Variables
- **Name resolution**: prefers human title `metadata.title` (e.g. "Adventurer's Guide") over the machine slug `package_name` (e.g. `open5e-a5e-ag`); falls back to slug when no title.
- **Metadata merge order**: payload `metadata` <- `extraMetadata` <- forced `installed_from`. `installed_from` ('assets' bundled / 'official' R2 catalog) is read back by `packageMetadataProvider` to tag the source in the package list and is what the admin uninstall path keys on.
- Always attaches `generateBuiltinDnd5eV2Schema().schema.toJson()` as the pack's `world_schema` — content is schema-versionless and follows the app's current built-in schema.

## Notes
- 53 lines. The two callers differ only in payload source (rootBundle vs R2) and the `installedFrom` marker.
