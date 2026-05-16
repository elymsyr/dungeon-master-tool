# Full Drift Migration Plan — Postgres-Mirrored Local Schema

**Date**: 2026-05-16
**Status**: Planning (audited 2026-05-16 against current repo state)
**Scope**: Replace all structured local persistence with Drift. Mirror Supabase Postgres schema 1:1 where it makes sense. No backwards compatibility — greenfield rewrite, beta users wiped.

> **Audit notes (2026-05-16)**: Current `schemaVersion = 11` ([app_database.dart:84](../lib/data/database/app_database.dart#L84)); 10 existing DAOs; v10 S1 hot-path indexes live ([app_database.dart:172-200](../lib/data/database/app_database.dart#L172-L200)); outbox payload is per-kind blob (`payloadJson` + `payloadBytes`), **not** per-row; `auto_save_sync` test harness referenced below does **not yet exist** — must be created in PR-D7. Sync engine files are `world_mirror_applier.dart` + `personal_mirror_applier.dart` (plan originally said `*_provider.dart`). `Campaign` symbol grep ≈92, `campaign_id`/`campaignId` ≈891 — heavy churn on the field name, lighter on the type.

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
| `world_characters` | world_characters (026) | id TEXT | rename `characters` → `world_characters`. Add referenced_entity_ids JSON. owner_id UUID-string. **`payload_json` TEXT preserved as opaque blob — see Character Mechanics Preservation below.** (Postgres uses `payload_json`, not v11's `entity_json` — v12 follows Postgres.) |
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
| `personal_packages` | personal_packages (033) | (owner_id, package_name) |
| ~~`personal_characters`~~ | DROPPED (migration 040) — chars unified into `world_characters` (orphan = ownerless) | n/a |
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
- Bump `schemaVersion = 12`. On app boot: if existing `dmt.sqlite` found, rename to `dmt.sqlite.legacy.<ts>` once for forensic backup (30-day retention), then create fresh DB. **Do not delete on first run** — only purge legacy files older than 30 days on subsequent boots.
- **Index strategy — MUST port S1 indexes to new table names in `onCreate`** (regression risk if skipped — these were the v10 perf win):
  ```sql
  CREATE INDEX idx_world_entities_world         ON world_entities (world_id);
  CREATE INDEX idx_world_entities_category      ON world_entities (world_id, category_slug);
  CREATE INDEX idx_world_entities_package       ON world_entities (package_id) WHERE package_id IS NOT NULL;
  CREATE INDEX idx_world_characters_world       ON world_characters (world_id);
  CREATE INDEX idx_world_characters_owner       ON world_characters (owner_id);
  CREATE INDEX idx_world_mm_nodes_world_map     ON world_mind_map_nodes (world_id, map_id);
  CREATE INDEX idx_world_mm_edges_world_map     ON world_mind_map_edges (world_id, map_id);
  CREATE INDEX idx_world_sessions_world         ON world_sessions (world_id, sort_order);
  CREATE INDEX idx_world_packages_world         ON world_packages (world_id);
  CREATE INDEX idx_world_members_user           ON world_members (user_id);
  CREATE INDEX idx_entity_shares_world          ON entity_shares (world_id);
  CREATE INDEX idx_map_pins_world               ON map_pins (world_id);
  CREATE INDEX idx_encounters_session           ON encounters (session_id);
  CREATE INDEX idx_combatants_encounter         ON combatants (encounter_id);
  CREATE INDEX idx_package_entities_package     ON package_entities (package_id);
  CREATE INDEX idx_outbox_next_attempt          ON sync_outbox (next_attempt_at, created_at);
  CREATE INDEX idx_outbox_table_pk              ON sync_outbox (target_table, target_pk, op);
  CREATE INDEX idx_trash_kind_deleted           ON trash_items (kind, deleted_at);
  ```
- PRAGMA tuning in `onOpen`: `journal_mode=WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`, `mmap_size=64MB`, `foreign_keys=OFF` (per Risk #2 — relaxed FKs, app-level enforcement).
- **LOC**: ~700 schema + 80 boot. **Days**: 2.

### PR-D1: DAOs

- Replace 10 existing DAOs with new set keyed to v12 names.
- `WorldsDao`, `WorldEntitiesDao`, `WorldCharactersDao`, `WorldMindMapDao`, `WorldSessionsDao`, `WorldMapDataDao`, `WorldSettingsDao`, `WorldMembersDao`, `WorldPackagesDao`, `EntitySharesDao`, `CharacterClaimPoolDao`, `WorldInvitesDao`, `PersonalPackagesDao`, `PackagesDao`, `InstalledPackagesDao`, `TrashDao`, `SyncOutboxDao`, `CombatDao`, `MapPinsDao`, `TimelinePinsDao`. (No `PersonalCharactersDao` — table was dropped Postgres-side in migration 040.)
- Each DAO mirrors Postgres CRUD semantics. Streams via `watch*` for reactive providers.
- **Perf rules for DAO impl** (non-negotiable):
  - All multi-row writes wrapped in `db.transaction(...)` — CDC apply batches must commit once, not per row.
  - Use `batch((b) => b.insertAllOnConflictUpdate(...))` for CDC bulk upserts.
  - `watch*` streams: scope by `world_id` always; never expose a global `watchAll`. Use `.distinct()` on equality where applicable to skip no-op rebuilds.
  - Prepared statements (`db.customSelect(..., variables:)`) for any hot-path raw SQL.
  - Avoid N+1: assemble related rows in single join query when feeding UI providers.
- **LOC**: ~2000 (revised — 21 DAOs vs original 10-DAO estimate). **Days**: 3.5.

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

- `world_mirror_applier.dart` (602 LOC), `cloud_catchup_service.dart` (93 LOC): replace `state_json` apply with per-table upserts.
- `sync_engine.dart` (631 LOC) outbox payloads: emit per-table ops (`{table: 'world_sessions', op: 'upsert', row: {...}}`) instead of full-blob diffs.
- `world_reconciler.dart` (210 LOC): last-writer-wins per row, not per world.
- `personal_mirror_applier.dart` + `personal_sync_service.dart`: cache writes go to `personal_characters` / `personal_packages` Drift tables (currently memory-only).
- Outbox schema: add `target_table TEXT`, `target_pk TEXT`, `op TEXT` columns; idempotency keyed on `(target_table, target_pk, op)`. Keep `payload_json` for the row snapshot. **Coalescing**: before enqueue, if a pending row with same `(table, pk, op)` exists and is still in `pending` state, overwrite its payload + bump `updated_at` instead of inserting (prevents outbox bloat under rapid edits).
- **CDC batching**: apply incoming realtime events in 16ms windows, group by table, commit per-window in single transaction. Avoids per-row commit storms when initial catch-up streams hundreds of rows.
- **Perf budget for sync rewrite** (regression gates):
  - Cold catch-up of 500-row world: ≤ current MsgPack blob load time (~150ms target on mid-tier Android).
  - Outbox enqueue: ≤ 1ms p99 (currently blob serialize is ~3-8ms — should win here).
  - Per-row CDC apply: ≤ 0.5ms each in batched transaction.
- **LOC**: ~700 refactor (revised up — outbox schema + batching window are net-new, not just rename). **Days**: 3.5.

### PR-D6: UI rename + dead code purge

- `Campaign` → `World` type rename (~92 hits) + `campaignId`/`campaign_id` → `worldId`/`world_id` (~891 hits, IDE refactor not manual).
- Delete `world_schemas` table usage (merged into `worlds.template_*`).
- Delete `msgpack_dart` from pubspec.
- Delete `path_provider` usage for structured data (keep for binary assets).
- Delete `CharacterMigrationService` (no longer needed).
- **LOC**: -800 net. **Days**: 2 (revised — field-name rename surface larger than type rename).

### PR-D7: Tests + perf harness

- **Prerequisite**: `auto_save_sync` test harness referenced by memory does **not yet exist on disk** (verified 2026-05-16). Build it first (FakeAsync clock + in-memory Drift + fake Supabase realtime channel + 2 simulated clients sharing outbox/CDC). ~400 LOC harness.
- Drift table tests: CRUD + index hit verification (EXPLAIN QUERY PLAN) per DAO.
- Sync apply tests: simulate CDC events from each `world_*` table, verify Drift state, assert single transaction commit per batch window.
- Outbox tests: per-table ops, retry, idempotency, **coalescing** (rapid same-row edits collapse to one pending entry).
- Repository tests: world create/read/update/delete via Drift only (no file I/O).
- Integration: 2-device FakeAsync sim — verify per-table merge, last-writer-wins per row.
- **Perf regression tests** (gates from PR-D5):
  - Bench: 500-row world cold catch-up under target ms.
  - Bench: 1000-edit outbox enqueue burst under target ms total.
  - Run on every PR via `flutter test --reporter=expanded` perf group; CI fails on regression > 20%.
- **LOC**: ~1600 tests + harness. **Days**: 4.

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
| Net LOC | ~+2800 / -1300 = +1500 (revised after audit — D1 +200, D5 +200, D7 +400 for harness) |
| Engineer-days | 20 serial, ~12 parallel (D0 blocks D1, D1 blocks D2-D5, D5 blocks D7) |
| Risk PRs | D0 (schema fresh-cut + index port), D5 (sync apply rewrite + outbox shape change), D7 (harness build-out) |

---

## Risk & Mitigations

1. **Beta data loss on v12 cut** — User explicitly accepted. One-shot rename old DB to `.legacy.<ts>` for 30 days as forensic backup; show one-time "fresh start" notice.
2. **Per-table CDC ordering** — Postgres triggers fire per table; out-of-order events (e.g., entity_share before world_entity) can FK-fail. Mitigation: `PRAGMA foreign_keys=OFF`, app-level parent-exists check on apply, buffered apply with retry on missing parent.
3. **Outbox payload bloat** — per-row ops more frequent than blob saves. Mitigation: debounce within same tick, coalesce same-row pending ops (see PR-D5).
4. **Symbol rename churn** — `Campaign` → `World` (~92 type refs) + `campaign_id` → `world_id` (~891 field refs) across UI. Mitigation: deprecation typedef in PR-D3, full purge in PR-D6, big-bang rename via IDE refactor not manual grep.
5. **Test surface explosion** — per-table tests add ~30 new test files. Mitigation: shared test fixtures + parameterized DAO test harness.
6. **⚠️ Index regression on fresh-cut** — v12 `onCreate` drops all v1-v11 history, including v10 S1 hot-path indexes. Mitigation: index block in PR-D0 is **load-bearing**; PR-D7 includes EXPLAIN QUERY PLAN tests asserting index hits.
7. **⚠️ Catch-up latency regression** — N round-trips to Drift instead of one MsgPack blob load. Mitigation: batched transactional apply (PR-D5), perf budget gates in PR-D7 CI bench. If catch-up regresses > 20%, abort merge.
8. **Provider rebuild storms** — per-row CDC apply may fan out to many `watch*` streams, triggering Riverpod rebuild cascades. Mitigation: `.distinct()` on stream equality, scope subscriptions by `world_id`, avoid global lists, use `select()` in providers to narrow rebuild surface.

## Open Questions

- Should `world_schemas` (template snapshot) be merged into `worlds.template_*` columns or kept as separate table for history? Postgres has it flat in `worlds` — proposing flat.
- `installed_packages` — keep local-only or sync via new Postgres `user_installed_packages`? Out of scope; keep local.
- `world_invites` — DM-side cache is convenience only; could stay REST-only. Proposing Drift cache for offline invite management.

---

## Decision Checkpoints

- **Before PR-D0**: Confirm beta data wipe acceptable (user already confirmed).
- **After PR-D0**: EXPLAIN QUERY PLAN spot-check on all S1-equivalent indexes — index hit confirmed before DAO build.
- **After PR-D2**: Smoke test world create/edit/load loop on dev device. Catch FK + scoping issues before sync rewrite.
- **After PR-D5**: 2-device sync regression test against staging Supabase. Block PR-D6 until green. Perf bench: cold catch-up ≤ pre-migration baseline.
- **Before PR-D8**: Profile cold start + steady-state typing latency on mid-tier Android (target: ≤ pre-migration baseline; expect win from no MsgPack isolate + no JSON sidecar fsync). Profile memory steady-state (expect win from no in-memory campaign blob).

---

## Character Mechanics Preservation (audited 2026-05-16)

**Guarantee**: All character-side D&D mechanics survive the migration **because they are derived, not stored**.

### How mechanics work today

- [character.dart](../lib/domain/entities/character.dart) stores **only choices + metadata**: no `traits[]`, `features[]`, `actions[]`, `spells[]`, `bonuses[]` columns. Just `entity.fields` JSON.
- [character_resolver.dart](../lib/domain/services/character_resolver.dart) is a **pure read-time resolver**: walks `class_levels`, `subclass_id`, `feat_ids`, `race_id`, `subspecies_id`, `base_abilities`, `equipment_choices`, `pending_choices` against SRD tables, produces `EffectiveCharacter` (`grantedSpellIds`, `grantedActionIds`, `damageResistanceIds`, `senseRanges`, etc.). Result **never persisted**.
- SRD content (class features, species traits, feats, spells) is **hardcoded in Dart** ([builtin_srd_entities.dart](../lib/application/services/builtin_srd_entities.dart) + `/srd_core/*.dart`), not DB-resident. Drift migration does not touch it.
- Custom content lives in `package_entities` table; v12 keeps this verbatim.

### Migration rule: `entity_json` is opaque

The `world_characters.payload_json` blob (currently `entityJson` in v11 [characters_table.dart](../lib/data/database/tables/characters_table.dart); renamed to match Postgres) **MUST** round-trip byte-for-byte. Do **not**:

- ❌ Normalize `entity.fields` into per-mechanic columns (would drop `pending_choices`, custom user fields, future-added choice kinds).
- ❌ Parse + re-serialize via a typed model class on write (would silently drop unknown keys when the model lags behind SRD additions).
- ❌ Strip `pending_choices` (deferred ASI/feat/subclass/weapon-mastery picks — losing these orphans the character mid-level-up).

The DAO must read/write `payload_json` as a `String` column without intermediate typed conversion. Only the resolver layer interprets it.

### What round-trips end-to-end (preserved-by-design)

| Mechanic | Source field(s) | Status |
|----------|----------------|--------|
| Action Surge / class features | `class_levels` | ✅ |
| Subclass features (Champion Improved Crit, etc.) | `subclass_id` + `class_levels` | ✅ |
| Species traits (Drow 120ft, Dwarven Resilience) | `race_id`, `subspecies_id` | ✅ |
| Feat grants (ASI, spells, profs) | `feat_ids`, `base_abilities` | ✅ |
| Wizard cantrips/spells known | `class_levels` + player-pick fields in entity | ✅ |
| Weapon Mastery picks | `pending_choices` (deferred) → resolved into entity field | ✅ |
| Equipment-derived AC/HP | `equipment_choices` | ✅ |
| Deferred level-up choices | `pending_choices` | ✅ |

### Migration test gate (added to PR-D7)

A regression test must:

1. Build a Level 12 multiclass character (Fighter 5 / Wizard 7) with all choice kinds populated, including ≥1 `pending_choices` entry.
2. Call `CharacterResolver.resolve()` → snapshot `EffectiveCharacter`.
3. Write through v12 `WorldCharactersDao.upsert()` → re-read → resolve again.
4. Assert resolved snapshots are bytewise-equal (deep-equality on every granted list + sense range + proficiency set).

If this fails, the migration drops mechanics silently. **PR-D7 cannot merge without this gate green.**

---

## Performance Guarantees (must hold post-migration)

| Metric | Baseline (v11) | Target (v12) |
|--------|----------------|--------------|
| Cold-open world (500 rows) | MsgPack blob load + parse, ~150ms p50 | ≤150ms p50, ideally ≤100ms (single indexed read instead of full blob deserialize on UI thread) |
| Outbox enqueue (1 edit) | Blob hash + write, 3-8ms | ≤1ms p99 |
| CDC apply (single row) | Blob merge + reapply, 5-15ms | ≤0.5ms in batch, ≤2ms standalone |
| Typing latency in editor | Affected by debounce + blob save | Unchanged or better (path-level merge already shipped 2026-05-16) |
| Memory steady-state (1 world loaded) | Full state blob in memory | Smaller — only watched rows materialized |
| App size | msgpack_dart dep | -msgpack_dart, +0 (Drift already present) |

These targets are enforced by CI bench tests in PR-D7. Regression > 20% on any metric blocks merge.
