---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/tables/ (worlds_table, world_members_table, world_invites_table, world_entities_table, world_characters_table, world_mind_map_nodes_table, world_mind_map_edges_table, world_sessions_table, world_map_data_table, world_settings_table, world_packages_table)
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Tables — Worlds group

> [!abstract] Primary Purpose
> Drift table definitions for the **world** half of the schema — each class mirrors a Postgres `public.*` table (migration numbers noted) and is registered in [[drift_database]] (schema v12). The big v11 `state_json` blob was decomposed (migration 042) into granular `world_map_data` / `world_sessions` / `world_settings` rows for per-row CDC; the old `entities`/`sessions`/`campaign_id` shapes were renamed to the `world_*` family with `world_id` FKs.

## Inputs / Outputs
**Inputs**
- Reads: consumed by [[worlds_dao]], [[world_members_dao]], [[world_invites_dao]], [[world_entities_dao]], `world_mind_map_dao` (`world_mind_map_nodes`/`_edges`), `world_packages_dao`, and the world settings/sessions/map-data DAOs ([[daos-index]]).
- Triggers: `currentDateAndTime` defaults on `createdAt`/`updatedAt`.

**Outputs**
- Public API: Drift row classes (`World`, `WorldMember`, `WorldInvite`, `WorldEntity`, `WorldCharacterRow`, `WorldMindMapNode`/`Edge`, `WorldSession`, `WorldMapDataData`, `WorldSetting`, `WorldPackage`) + Companions.

## Dependencies & Links
- Depends on: `package:drift` only (FKs to `Worlds` are `.references(Worlds, #id)`).
- Used by: [[drift_database]], [[world_repository_impl]], [[entity]], [[character_resolver]].
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: `docs/full_drift_migration_plan.md`

## Key Logic / Variables
- **`Worlds`** (PG `worlds`, mig 026; absorbs old `world_schemas`): PK `id` (text). Cols: `ownerId?`, `worldName`, `templateId?`, `templateHash?`, `templateOriginalHash?`, `createdAt`, `updatedAt`, `lastCloudPushAt?`, `lastPushedHash?`. Legacy `state_json` removed (split to map/sessions/settings).
- **`WorldMembers`** (mig 026): composite PK `{worldId, userId}`. Cols: `role` (`'dm'` | `'player'`), `joinedAt`.
- **`WorldInvites`** (mig 026, DM-side cache): PK `code`. Cols: `worldId`, `createdBy`, `expiresAt?`, `usesLeft` (default 1), `createdAt`.
- **`WorldEntities`** (PG `world_entities`, mig 026; renamed from v11 `entities`, `campaign_id`→`world_id`): PK `id`. Cols: `worldId`, `categorySlug`, `name`, `source`, `description`, `imagePath`, `imagesJson` (`[]`), `tagsJson` (`[]`), `dmNotes`, `pdfsJson` (`[]`), `locationId?`, `fieldsJson` (`{}` — typed mechanics live here), `packageId?`, `packageEntityId?`, `linked` (bool, pack live-link flag), `createdAt`, `updatedAt`.
- **`WorldCharacters`** (PG `world_characters`, mig 026+039; `@DataClassName('WorldCharacterRow')`): PK `id`. Cols: `worldId`, `ownerId?`, `templateId`, `templateName`, **`payloadJson`** (default `{}` — **OPAQUE** serialized `Character.entity` blob; MUST round-trip byte-for-byte, never normalize/re-serialize or level-up state orphans; mechanics derived at read-time by [[character_resolver]]), `referencedEntityIdsJson` (`[]`), `createdAt`, `updatedAt`.
- **`WorldMindMapNodes`** (mig 026): PK `id`. Cols: `worldId`, `mapId`, `label`, `nodeType` (`'note'`), `x`/`y`/`width` (150)/`height` (80) reals, `entityId?`, `imageUrl?`, `content`, `styleJson` (`{}`), `color`, `updatedAt`.
- **`WorldMindMapEdges`** (mig 026): PK `id`. Cols: `worldId`, `mapId`, `sourceId`, `targetId`, `label`, `styleJson` (`{}`), `updatedAt`.
- **`WorldSessions`** (PG `world_sessions`, mig 042; replaces v11 `sessions`, notes/logs collapsed into `dataJson`): PK `id`. Cols: `worldId`, `name`, `dataJson` (`{}`), `isActive` (bool), `sortOrder` (int), `updatedAt`.
- **`WorldMapData`** (PG `world_map_data`, mig 042, **1:1 with world**): PK `worldId`. Cols: `dataJson` (`{}`), `updatedAt`.
- **`WorldSettings`** (PG `world_settings`, mig 042, **1:1 with world**): PK `worldId`. Cols: `settingsJson` (`{}`), `updatedAt`.
- **`WorldPackages`** (PG `world_packages`, mig 043, DM-shared pack state visible to all members): PK `packageId`. Cols: `worldId`, `packageName`, `sharedBy?`, `stateJson` (`{}`), `createdAt`, `updatedAt`.

## Notes
- All `*Json` columns store serialized JSON as `text()`; defaults are `'[]'` / `'{}'`.
- `WorldRepositoryImpl` (D3) still packs schema + misc dynamic keys into `world_settings.settings_json` (key `_world_schema`), with only some keys split into their own tables.
- Indexes for these tables defined in [[drift_database]] `_v12Indexes`.
