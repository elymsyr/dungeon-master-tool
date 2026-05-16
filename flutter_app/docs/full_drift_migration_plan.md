# Full Drift Migration Plan — Postgres-Mirrored Local Schema

**Date**: 2026-05-16
**Status**: Planning
**Scope**: Replace all structured local persistence with Drift. Mirror Supabase Postgres schema 1:1 where it makes sense. No backwards compatibility — greenfield rewrite, beta users wiped.

---

## Goals

1. **Single source of truth locally**: Drift. No more MsgPack `data.dat`, no character JSON files, no JSON sidecars for sync-relevant data.
2. **Schema parity with Postgres**: Table names, column names, types, and PKs match Supabase. Realtime CDC apply becomes near-identity copy.
3. **No backwards compat**: Drop `state_json` blob, rename `campaign_id` → `world_id`, retire legacy columns. Drop v1–v11 migrations; ship v12 as fresh schema.
4. **Files only for binaries**: Images, PDFs, generated assets stay on disk. Index lives in Drift.

## Non-Goals

- SharedPreferences (UI theme/tab state) stays. Lightweight, not sync-relevant.
- Marketplace links sidecar stays (cache mapping, not canonical).
- Encounters/combat/timeline (no Postgres counterpart) stay Drift-local.

---

## Target Schema (Drift v12 — fresh)

### Core (mirror Postgres exactly)

| Drift Table | Postgres Source | PK | Notes |
|-------------|-----------------|----|----|
| `worlds` | worlds (026) | id TEXT | rename `campaigns` → `worlds`. Add owner_id, template_id, template_hash. Drop state_json. |
| `world_members` | world_members (026) | (world_id, user_id) | role enum 'dm'\|'player' |
| `world_entities` | world_entities (026) | id TEXT | rename `entities` → `world_entities`. Rename campaign_id → world_id |
| `world_characters` | world_characters (026) | id TEXT | rename `characters` → `world_characters`. Add referenced_entity_ids JSON. owner_id UUID-string |
| `world_mind_map_nodes` | (026) | id | rename, scope by world_id |
| `world_mind_map_edges` | (026) | id | rename, scope by world_id |
| `world_sessions` | world_sessions (042) | id | data_json TEXT, sort_order INT. Drop legacy notes/logs |
| `world_map_data` | world_map_data (042) | world_id | data_json TEXT |
| `world_settings` | world_settings (042) | world_id | settings_json TEXT |
| `world_packages` | world_packages (043) | (world_id, package_id) | unchanged |
| `entity_shares` | entity_shares (026) | id | NEW |
| `character_claim_pool` | character_claim_pool (026) | character_id | NEW |
| `world_invites` | world_invites (026) | code | NEW (DM cache for invite mgmt) |

### Personal / hub

| Drift Table | Postgres Source | PK |
|-------------|-----------------|----|
| `personal_characters` | personal_characters (033) | id |
| `personal_packages` | personal_packages (033) | (owner_id, package_name) |
| `packages` | (local catalog) | id |
| `package_schemas` | (internal) | package_id |
| `package_entities` | (internal) | (package_id, entity_id) |
| `installed_packages` | (internal) | package_id |

### Sync infrastructure (Drift-only)

| Drift Table | Purpose |
|-------------|---------|
| `sync_outbox` | unchanged (v10) |
| `trash_items` | NEW — replaces `/trash/` files. (kind, source_id, payload_json, deleted_at) |

### Local-only (no Postgres)

`encounters`, `combatants`, `combat_conditions`, `map_pins`, `timeline_pins` — unchanged.

---

## PR Sequence

### PR-D0: Schema definition + fresh DB

- Write v12 schema from scratch (`app_database.dart`). Drop all prior `MigrationStrategy` steps. `onCreate` only.
- Define all tables above with Postgres-aligned column names/types.
- Generate `.g.dart`. Compile-check.
- Bump `schemaVersion = 12`. On app boot: if existing `dmt.sqlite` found, **delete** it (no migration path). Optional: rename to `dmt.sqlite.legacy` once for safety, then ignore.
- **LOC**: ~600 schema + 50 boot. **Days**: 2.

### PR-D1: DAOs

- Replace 10 existing DAOs with new set keyed to v12 names.
- `WorldsDao`, `WorldEntitiesDao`, `WorldCharactersDao`, `WorldMindMapDao`, `WorldSessionsDao`, `WorldMapDataDao`, `WorldSettingsDao`, `WorldMembersDao`, `WorldPackagesDao`, `EntitySharesDao`, `CharacterClaimPoolDao`, `WorldInvitesDao`, `PersonalCharactersDao`, `PersonalPackagesDao`, `PackagesDao`, `InstalledPackagesDao`, `TrashDao`, `SyncOutboxDao`, `CombatDao`, `MapPinsDao`, `TimelinePinsDao`.
- Each DAO mirrors Postgres CRUD semantics. Streams via `watch*` for reactive providers.
- **LOC**: ~1800. **Days**: 3.

### PR-D2: Delete file datasources

- Delete `campaign_local_ds.dart` (278 LOC).
- Delete `package_local_ds.dart` (trash logic — replaced by `TrashDao`).
- Delete `pending_release_repository` file reads.
- Keep `marketplace_links_local_ds.dart` (out of scope).
- **LOC**: -500. **Days**: 0.5.

### PR-D3: Repository rewrite — worlds

- Rewrite `campaign_repository_impl.dart` → `world_repository_impl.dart`.
- All methods route to `WorldsDao` + sibling DAOs. State assembly = join queries, not blob deserialize.
- Update all callers (~80 references). Rename `Campaign` model → `World` (keep alias temporarily during refactor for grep'ability, remove in PR-D6).
- **LOC**: ~400 refactor. **Days**: 2.

### PR-D4: Repository rewrite — packages, characters, mind maps, sessions, settings

- `package_repository_impl` → drop trash file branch, use `TrashDao`.
- `character_repository` → split into `WorldCharactersRepo` + `PersonalCharactersRepo`.
- New `WorldSessionsRepo`, `WorldMapDataRepo`, `WorldSettingsRepo`, `WorldMembersRepo`, `EntitySharesRepo`, `CharacterClaimPoolRepo`.
- **LOC**: ~600. **Days**: 2.

### PR-D5: Sync engine + CDC apply rewrite

- `world_mirror_provider.dart`, `cloud_catchup_service.dart`: replace `state_json` apply with per-table upserts.
- `sync_engine.dart` outbox payloads: emit per-table ops (`{table: 'world_sessions', op: 'upsert', row: {...}}`) instead of full-blob diffs.
- `world_reconciler.dart`: last-writer-wins per row, not per campaign.
- `personal_sync_provider.dart`: cache writes go to `personal_characters` / `personal_packages` Drift tables (currently memory-only).
- Outbox idempotency: keyed on (table, pk, op).
- **LOC**: ~500 refactor. **Days**: 2.5.

### PR-D6: UI rename + dead code purge

- `Campaign` → `World` symbol rename across UI (~200 references).
- Delete `world_schemas` table usage (merged into `worlds.template_*`).
- Delete `msgpack_dart` from pubspec.
- Delete `path_provider` usage for structured data (keep for binary assets).
- Delete `CharacterMigrationService` (no longer needed).
- **LOC**: -800 net. **Days**: 1.5.

### PR-D7: Tests

- Drift table tests: CRUD + indexes per DAO.
- Sync apply tests: simulate CDC events from each `world_*` table, verify Drift state.
- Outbox tests: per-table ops, retry, idempotency.
- Repository tests: world create/read/update/delete via Drift only (no file I/O).
- Integration: 2-device FakeAsync sim (extends existing `auto_save_sync` test harness) — verify per-table merge.
- **LOC**: ~1200 tests. **Days**: 3.

### PR-D8: Cleanup + docs

- Update `CLAUDE.md` / arch docs.
- Remove dead `AppPaths.worldsDir`, `AppPaths.charactersDir` constants.
- Verify `dart analyze` clean, no unused imports.
- **LOC**: ~50. **Days**: 0.5.

---

## Totals

| Metric | Value |
|--------|-------|
| PRs | 9 (D0–D8) |
| Net LOC | ~+2200 / -1300 = +900 |
| Engineer-days | 17 serial, ~10 parallel (D0 blocks D1, D1 blocks D2-D5, D5 blocks D7) |
| Risk PRs | D0 (schema fresh-cut), D5 (sync apply rewrite) |

---

## Risk & Mitigations

1. **Beta data loss on v12 cut** — User explicitly accepted. One-shot rename old DB to `.legacy` for 30 days as forensic backup; show one-time "fresh start" notice.
2. **Per-table CDC ordering** — Postgres triggers fire per table; out-of-order events (e.g., entity_share before world_entity) can FK-fail. Mitigation: relaxed FKs (no `ON DELETE CASCADE` in Drift), buffered apply with retry on FK miss.
3. **Outbox payload bloat** — per-row ops more frequent than blob saves. Mitigation: debounce within same tick (already done in `auto_save_sync`), coalesce same-row ops in outbox.
4. **Symbol rename churn** — `Campaign` → `World` across 200+ refs touches UI surface. Mitigation: deprecation typedef in PR-D3, full purge in PR-D6, big-bang rename via IDE refactor not manual grep.
5. **Test surface explosion** — per-table tests add ~30 new test files. Mitigation: shared test fixtures + parameterized DAO test harness.

## Open Questions

- Should `world_schemas` (template snapshot) be merged into `worlds.template_*` columns or kept as separate table for history? Postgres has it flat in `worlds` — proposing flat.
- `installed_packages` — keep local-only or sync via new Postgres `user_installed_packages`? Out of scope; keep local.
- `world_invites` — DM-side cache is convenience only; could stay REST-only. Proposing Drift cache for offline invite management.

---

## Decision Checkpoints

- **Before PR-D0**: Confirm beta data wipe acceptable (user already confirmed).
- **After PR-D2**: Smoke test world create/edit/load loop on dev device. Catch FK + scoping issues before sync rewrite.
- **After PR-D5**: 2-device sync regression test against staging Supabase. Block PR-D6 until green.
- **Before PR-D8**: Profile cold start (target: ≤ pre-migration baseline; expect win from no MsgPack isolate).
