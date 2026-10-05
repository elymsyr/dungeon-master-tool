// Mindmap çizimleri cihazdan cihaza: A'nın notifier'ı → `world_settings`
// (repo.saveSettingsPatch) → push turunun gövdesi (`collect`) → B'nin pull'u
// (`apply`) → B'nin repo.load'u → B'nin notifier'ı. Ağ yok; iki ayrı Drift.
//
//   flutter test test/application/services/mind_map_strokes_sync_test.dart

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/services/cloud_pull_service.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/world_repository_impl.dart';
import 'package:dungeon_master_tool/presentation/screens/mind_map/mind_map_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  final client = SupabaseClient('http://localhost:1', 'test-key');

  setUp(() async {
    dbA = openTestDatabase();
    dbB = openTestDatabase();
    for (final db in [dbA, dbB]) {
      await db.customSelect('SELECT 1').get();
      await db.worldsDao.upsert(WorldsCompanion.insert(
        id: 'w1',
        worldName: 'Aegis',
        isOnline: const Value(true),
      ));
    }
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  test('strokes (width, zoom, color, points) reach the other device', () async {
    // Device A draws.
    final cA = ProviderContainer();
    addTearDown(cA.dispose);
    final nA = cA.read(mindMapProvider.notifier);
    nA.addStroke(const [Offset(10, 20), Offset(55.5, 80.25), Offset(90, 30)],
        const Color(0xFF42A5F5), 8,
        zoom: 0.25);
    nA.addStroke(const [Offset(-5, -5)], const Color(0xFFEF5350), 2, zoom: 3);
    // ignore: invalid_use_of_protected_member
    final drawn = nA.state.strokes;

    // Same shape MindMapNotifier.syncToCampaignData writes.
    await WorldRepositoryImpl(dbA).saveSettingsPatch('w1', {
      'mind_maps': {
        'default': {
          'nodes': const [],
          'edges': const [],
          'strokes': drawn.map((s) => s.toJson()).toList(),
        },
      },
    });

    final batches = await CloudPushService(db: dbA, client: client)
        .collect('w1', DateTime.fromMillisecondsSinceEpoch(0), const {});
    final row =
        batches.firstWhere((b) => b.table == 'world_settings').rows.single;

    // Device B pulls the row.
    await CloudPullService(db: dbB, client: client).apply(
        'w1',
        CloudDelta.fromJson({
          'revision': 1,
          'complete': true,
          'tables': {
            'world_settings': [
              {...row, 'revision': 1}
            ],
          },
          'tombstones': const [],
        }));

    final data = await WorldRepositoryImpl(dbB).load('w1');
    final scoped = Map<String, dynamic>.from(
        (data['mind_maps'] as Map)['default'] as Map);
    final cB = ProviderContainer();
    addTearDown(cB.dispose);
    final nB = cB.read(mindMapProvider.notifier)..init(scoped);
    // ignore: invalid_use_of_protected_member
    final got = nB.state.strokes;

    expect(got, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(got[i].id, drawn[i].id);
      expect(got[i].color, drawn[i].color);
      expect(got[i].width, drawn[i].width);
      expect(got[i].zoom, drawn[i].zoom);
      expect(got[i].points, [
        for (final p in drawn[i].points)
          Offset((p.dx * 10).round() / 10, (p.dy * 10).round() / 10)
      ]);
    }
  });
}
