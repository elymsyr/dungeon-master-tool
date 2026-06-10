import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_paths.dart';
import 'daos/character_claim_pool_dao.dart';
import 'daos/combat_dao.dart';
import 'daos/entity_shares_dao.dart';
import 'daos/installed_packages_dao.dart';
import 'daos/map_pins_dao.dart';
import 'daos/packages_dao.dart';
import 'daos/personal_packages_dao.dart';
import 'daos/sync_outbox_dao.dart';
import 'daos/templates_dao.dart';
import 'daos/timeline_pins_dao.dart';
import 'daos/trash_dao.dart';
import 'daos/world_characters_dao.dart';
import 'daos/world_entities_dao.dart';
import 'daos/world_invites_dao.dart';
import 'daos/world_map_data_dao.dart';
import 'daos/world_members_dao.dart';
import 'daos/world_mind_map_dao.dart';
import 'daos/world_packages_dao.dart';
import 'daos/world_sessions_dao.dart';
import 'daos/world_settings_dao.dart';
import 'daos/worlds_dao.dart';
import 'tables/character_claim_pool_table.dart';
import 'tables/combat_conditions_table.dart';
import 'tables/combatants_table.dart';
import 'tables/encounters_table.dart';
import 'tables/entity_shares_table.dart';
import 'tables/installed_packages_table.dart';
import 'tables/map_pins_table.dart';
import 'tables/package_entities_table.dart';
import 'tables/package_schemas_table.dart';
import 'tables/packages_table.dart';
import 'tables/personal_packages_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/templates_table.dart';
import 'tables/timeline_pins_table.dart';
import 'tables/trash_items_table.dart';
import 'tables/world_characters_table.dart';
import 'tables/world_entities_table.dart';
import 'tables/world_invites_table.dart';
import 'tables/world_map_data_table.dart';
import 'tables/world_members_table.dart';
import 'tables/world_mind_map_edges_table.dart';
import 'tables/world_mind_map_nodes_table.dart';
import 'tables/world_packages_table.dart';
import 'tables/world_sessions_table.dart';
import 'tables/world_settings_table.dart';
import 'tables/worlds_table.dart';

part 'app_database.g.dart';

/// v12 fresh-cut schema (PR-D0 of `full_drift_migration_plan.md`).
///
/// Postgres-mirrored local schema. All v1–v11 migration steps deleted: legacy
/// DBs are renamed to `dmt.sqlite.legacy.<ts>` and a fresh v12 DB is created on
/// first boot after upgrade. See [_openConnectionForUser].
///
/// DAOs intentionally absent — they ship in PR-D1. Repositories + UI will not
/// compile against this build until D1 lands.
@DriftDatabase(
  tables: [
    Worlds,
    WorldMembers,
    WorldInvites,
    WorldEntities,
    WorldCharacters,
    WorldMindMapNodes,
    WorldMindMapEdges,
    WorldSessions,
    WorldMapData,
    WorldSettings,
    WorldPackages,
    EntityShares,
    CharacterClaimPool,
    PersonalPackages,
    Packages,
    PackageSchemas,
    PackageEntities,
    InstalledPackages,
    SyncOutbox,
    TrashItems,
    Encounters,
    Combatants,
    CombatConditions,
    MapPins,
    TimelinePins,
    Templates,
  ],
  daos: [
    WorldsDao,
    WorldMembersDao,
    WorldInvitesDao,
    WorldEntitiesDao,
    WorldCharactersDao,
    WorldMindMapDao,
    WorldSessionsDao,
    WorldMapDataDao,
    WorldSettingsDao,
    WorldPackagesDao,
    EntitySharesDao,
    CharacterClaimPoolDao,
    PersonalPackagesDao,
    PackagesDao,
    InstalledPackagesDao,
    SyncOutboxDao,
    TrashDao,
    CombatDao,
    MapPinsDao,
    TimelinePinsDao,
    TemplatesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Per-user database: userId verilirse user-scoped path kullanılır.
  AppDatabase.forUser(String? userId) : super(_openConnectionForUser(userId));

  /// Test ve custom path desteği.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // S1 hot-path indexes — load-bearing perf win from v10 ported to
          // v12 names. EXPLAIN QUERY PLAN gates in PR-D7 assert hits.
          for (final stmt in _v12Indexes) {
            await customStatement(stmt);
          }
          // v13 (PR-1.4) Template library index.
          await customStatement(_templatesIndex);
        },
        onUpgrade: (m, from, to) async {
          // v12 was the fresh-cut baseline (anything older is handled by the
          // legacy rename in _openConnectionForUser, which then routes through
          // onCreate). Real upgrade steps start at v12 → v13.
          //
          // v13 (PR-1.4): Template library table. Additive — only the new
          // `templates` table is created; every other table already exists on a
          // v12 DB, so a blind createAll() would throw "table already exists".
          if (from < 13) {
            await m.createTable(templates);
            await customStatement(_templatesIndex);
          }
        },
        beforeOpen: (details) async {
          // PRAGMA tuning — apply on every open. WAL + NORMAL trades a tiny
          // durability window for big write throughput gains; foreign_keys=OFF
          // lets CDC apply land out-of-order events without parent-first
          // ordering churn (app-level parent-exists check on apply — Risk #2).
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA temp_store = MEMORY');
          await customStatement('PRAGMA mmap_size = 67108864'); // 64 MB
          await customStatement('PRAGMA foreign_keys = OFF');
          // F2+: drift-codegen kaçınmak için side-tables raw SQL ile
          // idempotent kurulur (asset_refs, sync_telemetry, migration_progress,
          // bm_mark_ops). Schema bump yok — IF NOT EXISTS.
          for (final stmt in _sideTablesDDL) {
            await customStatement(stmt);
          }
          // One-time repair: promote legacy `species` rows that are actually
          // subspecies. Older packs (and built-in pre-migration installs) marked
          // a subrace only with a "*Subspecies of X.*" description prefix and
          // categorised it as `species`. New packs ship slug `subspecies` +
          // `parent_species_ref`, and the ingest path fixes re-installs — this
          // catches packs already on disk. Parent name is parsed from the marker
          // and injected as a runtime softRef. Gated via migration_progress so
          // package_entities is scanned at most once; best-effort.
          try {
            final done = await customSelect(
              "SELECT 1 FROM migration_progress WHERE "
              "migration_name = 'subspecies_reclassify_v1' AND completed = 1",
            ).get();
            if (done.isEmpty) {
              await customStatement(
                "UPDATE package_entities SET "
                "category_slug = 'subspecies', "
                "fields_json = json_set("
                "  CASE WHEN json_valid(fields_json) THEN fields_json ELSE '{}' END, "
                "  '\$.parent_species_ref', "
                "  json_object('slug', 'species', 'name', "
                "    trim(substr(description, 16, instr(description, '.*') - 16)))) "
                "WHERE category_slug = 'species' "
                "AND description LIKE '*Subspecies of %' "
                "AND instr(description, '.*') > 16 "
                "AND json_extract("
                "  CASE WHEN json_valid(fields_json) THEN fields_json ELSE '{}' END, "
                "  '\$.parent_species_ref') IS NULL",
              );
              await customStatement(
                "INSERT OR REPLACE INTO migration_progress "
                "(migration_name, world_id, completed, updated_at) "
                "VALUES ('subspecies_reclassify_v1', '', 1, ?)",
                [DateTime.now().millisecondsSinceEpoch],
              );
            }
          } catch (_) {}
          // PR-D8 cleanup: 30-day Drift trash retention (replaces v11 FS
          // _cleanupTrash). Best-effort — purge errors don't block open.
          try {
            final cutoff = DateTime.now().subtract(const Duration(days: 30));
            await trashDao.purgeOlderThan(cutoff);
          } catch (_) {}
        },
      );
}

/// S1 + v12 index block. Kept inline (not separate file) so it lives next to
/// the schema it indexes — easier to audit drift.
const List<String> _v12Indexes = <String>[
  // worlds
  'CREATE INDEX IF NOT EXISTS idx_worlds_owner '
      'ON worlds (owner_id)',

  // world_members
  'CREATE INDEX IF NOT EXISTS idx_world_members_user '
      'ON world_members (user_id)',

  // world_invites
  'CREATE INDEX IF NOT EXISTS idx_world_invites_world '
      'ON world_invites (world_id)',

  // world_entities — S1 hot path
  'CREATE INDEX IF NOT EXISTS idx_world_entities_world '
      'ON world_entities (world_id)',
  'CREATE INDEX IF NOT EXISTS idx_world_entities_category '
      'ON world_entities (world_id, category_slug)',
  'CREATE INDEX IF NOT EXISTS idx_world_entities_package '
      'ON world_entities (package_id) WHERE package_id IS NOT NULL',

  // world_characters — S1 hot path
  'CREATE INDEX IF NOT EXISTS idx_world_characters_world '
      'ON world_characters (world_id)',
  'CREATE INDEX IF NOT EXISTS idx_world_characters_owner '
      'ON world_characters (owner_id)',
  'CREATE INDEX IF NOT EXISTS idx_world_characters_updated '
      'ON world_characters (updated_at DESC)',

  // mind map
  'CREATE INDEX IF NOT EXISTS idx_world_mm_nodes_world_map '
      'ON world_mind_map_nodes (world_id, map_id)',
  'CREATE INDEX IF NOT EXISTS idx_world_mm_edges_world_map '
      'ON world_mind_map_edges (world_id, map_id)',

  // sessions
  'CREATE INDEX IF NOT EXISTS idx_world_sessions_world '
      'ON world_sessions (world_id, sort_order)',

  // world_packages
  'CREATE INDEX IF NOT EXISTS idx_world_packages_world '
      'ON world_packages (world_id)',

  // entity_shares
  'CREATE INDEX IF NOT EXISTS idx_entity_shares_world '
      'ON entity_shares (world_id)',
  'CREATE INDEX IF NOT EXISTS idx_entity_shares_target '
      'ON entity_shares (world_id, shared_with)',

  // character_claim_pool
  'CREATE INDEX IF NOT EXISTS idx_claim_pool_world_avail '
      'ON character_claim_pool (world_id, available)',

  // personal_packages
  'CREATE INDEX IF NOT EXISTS idx_personal_packages_owner '
      'ON personal_packages (owner_id)',

  // packages catalog
  'CREATE INDEX IF NOT EXISTS idx_package_entities_package '
      'ON package_entities (package_id)',

  // map / timeline (local)
  'CREATE INDEX IF NOT EXISTS idx_map_pins_world '
      'ON map_pins (world_id)',
  'CREATE INDEX IF NOT EXISTS idx_timeline_pins_world '
      'ON timeline_pins (world_id)',

  // encounters / combat
  'CREATE INDEX IF NOT EXISTS idx_encounters_session '
      'ON encounters (session_id)',
  'CREATE INDEX IF NOT EXISTS idx_combatants_encounter '
      'ON combatants (encounter_id)',

  // outbox — per-row coalescing
  'CREATE INDEX IF NOT EXISTS idx_outbox_next_attempt '
      'ON sync_outbox (next_attempt_at, created_at)',
  'CREATE INDEX IF NOT EXISTS idx_outbox_table_pk '
      'ON sync_outbox (target_table, target_pk, op_type)',

  // trash
  'CREATE INDEX IF NOT EXISTS idx_trash_kind_deleted '
      'ON trash_items (kind, deleted_at)',
];

/// v13 (PR-1.4) Template library index — the list query orders by
/// `updated_at DESC`. Kept separate from [_v12Indexes] so each schema
/// version's index block sits next to the migration step that adds it.
const String _templatesIndex =
    'CREATE INDEX IF NOT EXISTS idx_templates_updated '
    'ON templates (updated_at DESC)';

/// F2+ side-tables. Drift codegen kaçınmak için raw SQL ile yönetilir.
/// `beforeOpen` her açılışta idempotent çalıştırır.
///
/// - `asset_refs` (F2): AssetRef → owner satır grafı; eviction sweeper
///   orphan tespiti için.
/// - `sync_telemetry` (F12): latency histogram bucket'ları.
/// - `migration_progress` (F11): raw-path migrator resume state.
/// - `bm_mark_ops_local` (F8): server `world_battlemap_mark_ops` mirror'u.
const List<String> _sideTablesDDL = <String>[
  // asset_refs
  'CREATE TABLE IF NOT EXISTS asset_refs ('
      'uri TEXT NOT NULL, '
      'owner_table TEXT NOT NULL, '
      'owner_id TEXT NOT NULL, '
      'owner_field TEXT NOT NULL DEFAULT \'\', '
      'world_id TEXT, '
      'last_seen_at INTEGER NOT NULL, '
      'PRIMARY KEY (uri, owner_table, owner_id, owner_field)'
      ')',
  'CREATE INDEX IF NOT EXISTS idx_asset_refs_uri ON asset_refs (uri)',
  'CREATE INDEX IF NOT EXISTS idx_asset_refs_owner '
      'ON asset_refs (owner_table, owner_id)',
  'CREATE INDEX IF NOT EXISTS idx_asset_refs_world ON asset_refs (world_id)',

  // sync_telemetry — F12
  'CREATE TABLE IF NOT EXISTS sync_telemetry ('
      'metric TEXT NOT NULL, '
      'bucket TEXT NOT NULL, '
      'count INTEGER NOT NULL DEFAULT 0, '
      'sum_ms INTEGER NOT NULL DEFAULT 0, '
      'last_at INTEGER NOT NULL, '
      'PRIMARY KEY (metric, bucket)'
      ')',

  // migration_progress — F11
  'CREATE TABLE IF NOT EXISTS migration_progress ('
      'migration_name TEXT NOT NULL, '
      'world_id TEXT NOT NULL DEFAULT \'\', '
      'last_id TEXT, '
      'completed INTEGER NOT NULL DEFAULT 0, '
      'updated_at INTEGER NOT NULL, '
      'PRIMARY KEY (migration_name, world_id)'
      ')',

  // bm_mark_ops_local — F8 (server world_battlemap_mark_ops mirror)
  'CREATE TABLE IF NOT EXISTS bm_mark_ops_local ('
      'op_id TEXT NOT NULL PRIMARY KEY, '
      'world_id TEXT NOT NULL, '
      'encounter_id TEXT NOT NULL, '
      'author_id TEXT NOT NULL, '
      'kind TEXT NOT NULL, '
      'payload_json TEXT NOT NULL, '
      'seq INTEGER NOT NULL, '
      'created_at INTEGER NOT NULL'
      ')',
  'CREATE INDEX IF NOT EXISTS idx_bm_ops_enc_seq '
      'ON bm_mark_ops_local (world_id, encounter_id, seq)',
];

LazyDatabase _openConnection() => _openConnectionForUser(null);

/// Opens the SQLite DB under `AppPaths.dataRoot/db/dmt.sqlite` (per-user:
/// `AppPaths.dataRoot/users/{userId}/db/dmt.sqlite`).
///
/// **v12 fresh-cut**: if a pre-v12 `dmt.sqlite` is found at the new location,
/// it is one-shot renamed to `dmt.sqlite.legacy.<unix-ms>` and a fresh v12 DB
/// is created in its place. The legacy file is kept 30 days as a forensic
/// backup; older legacy files are purged on subsequent boots.
///
/// Legacy support for `{getApplicationSupportDirectory}/DungeonMasterTool/...`
/// is also handled — that file is copied (not renamed) once and marked with
/// `.moved_to_dataroot`, then v12 fresh-cut applies normally.
LazyDatabase _openConnectionForUser(String? userId) {
  return LazyDatabase(() async {
    final base = userId != null
        ? p.join(AppPaths.dataRoot, 'users', userId)
        : AppPaths.dataRoot;
    final dbDir = Directory(p.join(base, 'db'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final newFile = File(p.join(dbDir.path, 'dmt.sqlite'));

    // Legacy support directory copy (pre-Apr-2026 install layout).
    if (!newFile.existsSync()) {
      try {
        final support = await getApplicationSupportDirectory();
        final legacyBase = userId != null
            ? p.join(support.path, 'DungeonMasterTool', 'users', userId)
            : p.join(support.path, 'DungeonMasterTool');
        final legacyFile = File(p.join(legacyBase, 'dmt.sqlite'));
        if (legacyFile.existsSync()) {
          await legacyFile.copy(newFile.path);
          await File(p.join(legacyBase, '.moved_to_dataroot'))
              .writeAsString(newFile.path);
        }
      } catch (_) {
        // path_provider unavailable (e.g. tests) — create fresh DB.
      }
    }

    // v12 fresh-cut: any DB at the new location is pre-v12 (since v12 ships
    // for the first time in this PR). Rename to forensic backup, then v12
    // onCreate will populate a fresh file.
    if (newFile.existsSync()) {
      final marker = File(p.join(dbDir.path, '.v12_cut_applied'));
      if (!marker.existsSync()) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final legacyTarget = File(p.join(dbDir.path, 'dmt.sqlite.legacy.$ts'));
        await newFile.rename(legacyTarget.path);
        await marker.writeAsString(legacyTarget.path);
      }
    }

    // Purge legacy backups older than 30 days.
    try {
      final cutoffMs = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      for (final entity in dbDir.listSync()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('dmt.sqlite.legacy.')) continue;
        final tsStr = name.substring('dmt.sqlite.legacy.'.length);
        final ts = int.tryParse(tsStr);
        if (ts != null && ts < cutoffMs) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Non-fatal — purge is best-effort.
    }

    return NativeDatabase.createInBackground(newFile);
  });
}
