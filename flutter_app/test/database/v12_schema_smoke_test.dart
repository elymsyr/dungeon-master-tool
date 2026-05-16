// PR-D0 smoke test — verifies v12 schema creates all tables + S1 indexes.
//
// Run with:
//   cd flutter_app && flutter test test/database/v12_schema_smoke_test.dart
//
// Asserts:
//   1. AppDatabase opens against an in-memory NativeDatabase.
//   2. Every v12 table exists.
//   3. Every v12 S1 hot-path index is present.
//   4. EXPLAIN QUERY PLAN hits the expected index on a representative query.
//   5. PRAGMA tuning applied (foreign_keys OFF, journal_mode set).

import 'package:drift/native.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('v12 schema (PR-D0)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is 12', () {
      expect(db.schemaVersion, 12);
    });

    test('all expected tables exist', () async {
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
        "ORDER BY name",
      ).get();
      final tableNames = rows.map((r) => r.read<String>('name')).toSet();

      const expected = {
        'worlds',
        'world_members',
        'world_invites',
        'world_entities',
        'world_characters',
        'world_mind_map_nodes',
        'world_mind_map_edges',
        'world_sessions',
        'world_map_data',
        'world_settings',
        'world_packages',
        'entity_shares',
        'character_claim_pool',
        'personal_packages',
        'packages',
        'package_schemas',
        'package_entities',
        'installed_packages',
        'sync_outbox',
        'trash_items',
        'encounters',
        'combatants',
        'combat_conditions',
        'map_pins',
        'timeline_pins',
      };

      final missing = expected.difference(tableNames);
      expect(missing, isEmpty,
          reason: 'Missing tables: $missing\nGot: $tableNames');
    });

    test('S1 hot-path indexes present', () async {
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name LIKE 'idx_%' ORDER BY name",
      ).get();
      final indexes = rows.map((r) => r.read<String>('name')).toSet();

      const expected = {
        'idx_worlds_owner',
        'idx_world_members_user',
        'idx_world_invites_world',
        'idx_world_entities_world',
        'idx_world_entities_category',
        'idx_world_entities_package',
        'idx_world_characters_world',
        'idx_world_characters_owner',
        'idx_world_characters_updated',
        'idx_world_mm_nodes_world_map',
        'idx_world_mm_edges_world_map',
        'idx_world_sessions_world',
        'idx_world_packages_world',
        'idx_entity_shares_world',
        'idx_entity_shares_target',
        'idx_claim_pool_world_avail',
        'idx_personal_packages_owner',
        'idx_package_entities_package',
        'idx_map_pins_world',
        'idx_timeline_pins_world',
        'idx_encounters_session',
        'idx_combatants_encounter',
        'idx_outbox_next_attempt',
        'idx_outbox_table_pk',
        'idx_trash_kind_deleted',
      };

      final missing = expected.difference(indexes);
      expect(missing, isEmpty, reason: 'Missing indexes: $missing');
    });

    test('EXPLAIN QUERY PLAN — world_entities composite index hit', () async {
      final rows = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM world_entities "
        "WHERE world_id='w1' AND category_slug='npc'",
      ).get();
      final plan = rows.map((r) => r.data.toString()).join('\n');
      expect(plan, contains('idx_world_entities_category'),
          reason: 'Expected category index hit, got:\n$plan');
    });

    test('EXPLAIN QUERY PLAN — sync_outbox coalesce index hit', () async {
      final rows = await db.customSelect(
        "EXPLAIN QUERY PLAN SELECT * FROM sync_outbox "
        "WHERE target_table='world_entities' AND target_pk='e1' "
        "AND op_type='upsert'",
      ).get();
      final plan = rows.map((r) => r.data.toString()).join('\n');
      expect(plan, contains('idx_outbox_table_pk'),
          reason: 'Expected outbox coalesce index hit, got:\n$plan');
    });

    test('PRAGMA tuning applied', () async {
      // beforeOpen runs lazily — first query triggers it.
      await db.customSelect('SELECT 1').get();

      final journal = (await db
              .customSelect('PRAGMA journal_mode')
              .getSingle())
          .read<String>('journal_mode');
      // In-memory DBs report 'memory'; real on-disk DBs report 'wal'.
      expect(['wal', 'memory'], contains(journal));

      final fkRow = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fkRow.read<int>('foreign_keys'), 0,
          reason: 'foreign_keys must be OFF per Risk #2');
    });
  });
}
