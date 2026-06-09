---
type: moc
domain: data-layer
updated: 2026-06-09
tags: [moc]
---

# Data Layer — Map of Content

> [!summary] Scope
> Local persistence: Drift (SQLite) schema v12, ~29 codegen tables + side tables, the DAOs that query them, and the repository implementations bridging domain interfaces to data. Mirrors the Supabase schema ([[Backend-Infra]]) row-for-row.

## Key Files
- [[drift_database]] — `AppDatabase` core; schema v12 (fresh-cut, legacy migrations dropped).
- [[tables-worlds]] — grouped: worlds, members, invites, entities, characters, mind-map, sessions, settings.
- [[tables-combat]] — grouped: encounters, combatants, combat_conditions, map_pins, world_map_data.
- [[tables-packages]] — grouped: packages, package_entities, package_schemas, personal/installed.
- [[tables-sync]] — `sync_outbox` (coalescing) + side tables (asset_refs, sync_telemetry, bm_mark_ops).
- [[daos-index]] — DAO catalog (those not covered in their own domain notes).
- [[repositories-index]] — `*_repository_impl` bridging domain ↔ data.
- [[remote-datasources-index]] — `data/datasources/remote/*` Supabase DS catalog.

> Domain-specific DAOs are documented in their domain folders: [[sync_outbox_dao]] ([[Sync-and-Realtime]]), [[world_entities_dao]] / [[worlds_dao]] / [[packages_dao]] ([[World-and-Content]]), [[combat_dao]] / [[world_map_data_dao]] / [[map_pins_dao]] ([[Combat-and-VTT]]), [[world_members_dao]] / [[world_invites_dao]] ([[Multiplayer-and-Online]]).

## Data Flow
Domain calls repository interface → `*_repository_impl` → DAO → Drift table. Writes that need sync also enqueue to [[sync_outbox_dao]] (see [[CDC-Sync-Flow]]).

## Related Domains
- Every domain reads/writes here. Closest: [[Sync-and-Realtime]] (outbox), [[World-and-Content]], [[Backend-Infra]] (mirror shape).

## Source Docs
- `flutter_app/docs/full_drift_migration_plan_may16.md`, `system_optimization_roadmap.md` (DB index finding S1).
