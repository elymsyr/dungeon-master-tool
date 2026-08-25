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
    Packages,
    PackageSchemas,
    PackageEntities,
    InstalledPackages,
    TrashItems,
    Encounters,
    Combatants,
    CombatConditions,
    MapPins,
    TimelinePins,
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
    PackagesDao,
    InstalledPackagesDao,
    TrashDao,
    CombatDao,
    MapPinsDao,
    TimelinePinsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Per-user database: userId verilirse user-scoped path kullanılır.
  AppDatabase.forUser(String? userId) : super(_openConnectionForUser(userId));

  /// Test ve custom path desteği.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // S1 hot-path indexes — load-bearing perf win from v10 ported to
          // v12 names. EXPLAIN QUERY PLAN gates in PR-D7 assert hits.
          for (final stmt in _v12Indexes) {
            await customStatement(stmt);
          }
        },
        onUpgrade: (m, from, to) async {
          // v12 is a fresh cut. Anything older was handled by the legacy
          // rename in _openConnectionForUser; this branch should not run.
          // Defensive: if it does, treat as fresh create.
          await m.createAll();
          for (final stmt in _v12Indexes) {
            await customStatement(stmt);
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
          // idempotent kurulur (asset_refs, migration_progress,
          // lan_paired_devices). Schema bump yok — IF NOT EXISTS.
          for (final stmt in _sideTablesDDL) {
            await customStatement(stmt);
          }
          // LAN sync: yeniden adlandırma zamanı — tablolara kolon ekle.
          // ALTER TABLE IF NOT EXISTS SQLite'da desteklenmiyor; hata yutulur.
          for (final stmt in _renamedAtColumnsDDL) {
            try {
              await customStatement(stmt);
            } catch (_) {}
          }
          // Bulut sync kaldırıldı: outbox/telemetry/personal-package tabloları
          // artık yok. Mevcut v12 DB'lerde artık satırlar duruyor; burada
          // düşürülür. schemaVersion 12'de KALIR — v13'e çıkmak her kullanıcının
          // DB'sini `.legacy` yapıp sıfırlardı, oysa kaybolan tek şey ölü tablo.
          for (final stmt in _retiredTablesDDL) {
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
          // Dedup: packages table has no UNIQUE on `name`, so duplicate rows
          // (same name, different id) can accumulate from interrupted re-seeds
          // or race conditions. Keep the row with the most entities; on tie,
          // keep the most recently updated. Gated via migration_progress.
          try {
            final dedupDone = await customSelect(
              "SELECT 1 FROM migration_progress WHERE "
              "migration_name = 'packages_dedup_v1' AND completed = 1",
            ).get();
            if (dedupDone.isEmpty) {
              // Delete the "loser" of each duplicate pair — fewer entities, or
              // same count but older updated_at. Uses a self-join.
              await customStatement(
                "DELETE FROM packages WHERE id IN ("
                "  SELECT p1.id FROM packages p1"
                "  JOIN packages p2 ON p1.name = p2.name AND p1.id > p2.id"
                "  WHERE ("
                "    (SELECT count(*) FROM package_entities WHERE package_id = p1.id)"
                "    < (SELECT count(*) FROM package_entities WHERE package_id = p2.id)"
                "  ) OR ("
                "    (SELECT count(*) FROM package_entities WHERE package_id = p1.id)"
                "    = (SELECT count(*) FROM package_entities WHERE package_id = p2.id)"
                "    AND p1.updated_at <= p2.updated_at"
                "  )"
                ")",
              );
              await customStatement(
                "INSERT OR REPLACE INTO migration_progress "
                "(migration_name, world_id, completed, updated_at) "
                "VALUES ('packages_dedup_v1', '', 1, ?)",
                [DateTime.now().millisecondsSinceEpoch],
              );
            }
          } catch (_) {}
          // Prevent future duplicate package names with a UNIQUE index.
          try {
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_packages_name '
              'ON packages (name)',
            );
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

  // packages catalog
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_packages_name '
      'ON packages (name)',
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

  // trash
  'CREATE INDEX IF NOT EXISTS idx_trash_kind_deleted '
      'ON trash_items (kind, deleted_at)',
];

/// F2+ side-tables. Drift codegen kaçınmak için raw SQL ile yönetilir.
/// `beforeOpen` her açılışta idempotent çalıştırır.
///
/// - `asset_refs` (F2): AssetRef → owner satır grafı; eviction sweeper
///   orphan tespiti için.
/// - `migration_progress` (F11): raw-path migrator resume state.
/// - `lan_paired_devices` (LAN sync v2): kalıcı cihaz eşleşmeleri. DB zaten
///   `users/{uid}/` altında olduğu için kayıtlar doğal olarak hesaba bağlı.
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

  // migration_progress — F11
  'CREATE TABLE IF NOT EXISTS migration_progress ('
      'migration_name TEXT NOT NULL, '
      'world_id TEXT NOT NULL DEFAULT \'\', '
      'last_id TEXT, '
      'completed INTEGER NOT NULL DEFAULT 0, '
      'updated_at INTEGER NOT NULL, '
      'PRIMARY KEY (migration_name, world_id)'
      ')',

  // lan_paired_devices — LAN sync v2 (bkz. [[LAN-Sync-Flow]])
  // `shared_secret` iki cihazda aynıdır; `/pair` el sıkışmasında iki tarafın
  // ürettiği yarımların sha256'sı. `last_address` presence beacon'ı ile tazelenir.
  'CREATE TABLE IF NOT EXISTS lan_paired_devices ('
      'device_id TEXT NOT NULL PRIMARY KEY, '
      'name TEXT NOT NULL DEFAULT \'\', '
      'last_address TEXT NOT NULL DEFAULT \'\', '
      'shared_secret TEXT NOT NULL, '
      'paired_at INTEGER NOT NULL, '
      'last_seen_at INTEGER NOT NULL DEFAULT 0'
      ')',
];

/// LAN sync: yeniden adlandırma zamanı damgası. Schema bump yok — her
/// `beforeOpen`'da `ALTER TABLE … ADD COLUMN` denenir, kolon zaten varsa
/// hata yutulur.
const List<String> _renamedAtColumnsDDL = <String>[
  'ALTER TABLE worlds ADD COLUMN renamed_at INTEGER',
  'ALTER TABLE packages ADD COLUMN renamed_at INTEGER',
  'ALTER TABLE world_characters ADD COLUMN renamed_at INTEGER',
];

/// Bulut sync ile birlikte emekliye ayrılan tablolar. `beforeOpen`'da
/// düşürülür ki eski v12 dosyaları ölü veri taşımasın. Silme listesine bir
/// şey eklemek serbest; buradan bir satır ÇIKARMAK ise eski kurulumlarda
/// tabloyu geri getirmez — sadece artık temizliği durdurur.
const List<String> _retiredTablesDDL = <String>[
  'DROP TABLE IF EXISTS sync_outbox',
  'DROP TABLE IF EXISTS sync_telemetry',
  'DROP TABLE IF EXISTS bm_mark_ops_local',
  'DROP TABLE IF EXISTS personal_packages',
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
/// The `user_version` of a SQLite file, straight out of its header — a 4-byte
/// big-endian integer at offset 60 of page 1, defined by the file format. Null
/// when the file is too short or unreadable to be a database at all.
///
/// Deliberately not a `PRAGMA`: [_openConnectionForUser] runs before any
/// connection exists and `package:sqlite3` is a dev-only dependency here.
Future<int?> _userVersionOf(File file) async {
  try {
    final handle = await file.open();
    try {
      await handle.setPosition(60);
      final bytes = await handle.read(4);
      if (bytes.length < 4) return null;
      return bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
    } finally {
      await handle.close();
    }
  } catch (_) {
    return null;
  }
}

LazyDatabase _openConnectionForUser(String? userId) {
  return LazyDatabase(() async {
    final base = userId != null
        ? p.join(AppPaths.dataRoot, 'users', userId)
        : AppPaths.dataRoot;
    final dbDir = Directory(p.join(base, 'db'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final newFile = File(p.join(dbDir.path, 'dmt.sqlite'));
    final marker = File(p.join(dbDir.path, '.v12_cut_applied'));

    // Legacy support directory copy (pre-Apr-2026 install layout).
    //
    // **O5 — this import is one-shot, and the marker is what makes it one.**
    // The only guard used to be "there is no database here", which is true
    // again every time the file legitimately goes away — and O4 made that a
    // routine event: retiring a spent guest tree *moves* `dmt.sqlite` into
    // `guest_archive/`. The next open then re-imported the pre-Apr-2026
    // support-directory database, and because `.v12_cut_applied` was already
    // sitting in this directory the v12 cut did not touch it. Measured on the
    // reporter's device: the signed-out workspace came back holding a
    // **schema v5** file (`map_pins.campaign_id`, no `world_id`), so Drift ran
    // `onUpgrade` → `createAll()` kept the ancient tables → the very first
    // index statement threw `no such column: world_id` and the hub showed a
    // SqliteException instead of a world list.
    //
    // The marker means "this directory has been past the v12 cut". Nothing
    // pre-v12 may enter after that, so the import is skipped — an *empty*
    // directory here is a deliberately empty workspace, not a fresh install.
    if (!newFile.existsSync() && !marker.existsSync()) {
      try {
        final support = await getApplicationSupportDirectory();
        final legacyBase = userId != null
            ? p.join(support.path, 'DungeonMasterTool', 'users', userId)
            : p.join(support.path, 'DungeonMasterTool');
        // Belt and braces: the import writes this receipt, so honour it too.
        final receipt = File(p.join(legacyBase, '.moved_to_dataroot'));
        final legacyFile = File(p.join(legacyBase, 'dmt.sqlite'));
        if (legacyFile.existsSync() && !receipt.existsSync()) {
          await legacyFile.copy(newFile.path);
          await receipt.writeAsString(newFile.path);
        }
      } catch (_) {
        // path_provider unavailable (e.g. tests) — create fresh DB.
      }
    }

    // v12 fresh-cut: any DB at the new location is pre-v12 (since v12 ships
    // for the first time in this PR). Rename to forensic backup, then v12
    // onCreate will populate a fresh file.
    //
    // **O5 — the marker is no longer the only evidence.** It records that this
    // directory has been past the cut, which says nothing about the file
    // sitting in it *now*: a pre-v12 database that arrives after the marker was
    // written (see the resurrection above) used to sail straight through and
    // blow up in `onUpgrade`. The file's own `user_version` is asked as well,
    // and it is the stronger answer — it is read from the SQLite header, which
    // needs no sqlite3 handle and therefore no dependency this layer lacks.
    if (newFile.existsSync()) {
      final onDisk = await _userVersionOf(newFile);
      final isPreV12 = onDisk != null && onDisk > 0 && onDisk < 12;
      if (!marker.existsSync() || isPreV12) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final legacyTarget = File(p.join(dbDir.path, 'dmt.sqlite.legacy.$ts'));
        await newFile.rename(legacyTarget.path);
        await marker.writeAsString(legacyTarget.path);
      }
    } else if (!marker.existsSync()) {
      // **O4.** Nothing on disk, so the file Drift is about to create is v12 by
      // definition and the cut has nothing to do here. The marker must still be
      // written *now*: it is the only record that this directory has been past
      // the cut, and without it the next open would find an unmarked `dmt.sqlite`
      // — the one this session is about to fill — and rename it away as if it
      // were pre-v12. Measured before the fix: a database created and written in
      // one session came back empty on the second open, every time.
      await marker.writeAsString('fresh v12');
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
