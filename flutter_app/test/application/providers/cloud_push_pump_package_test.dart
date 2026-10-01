// Faz 5e — online paketin arka plan uzlaştırması. Pompa sahte PostgREST'e
// karşı gerçekten koşuyor; medya yolu kapalı (`worldMediaSyncProvider` null),
// onun zinciri world_media_sync_test'te.
//
//   flutter test test/application/providers/cloud_push_pump_package_test.dart
//
// Kapsam (`reconcileAll`):
//   1. Çevrimdışı düzenlenip kapatılan online paket açılmadan çıkar: push,
//      sonra pull.
//   2. Açık paket yalnız push edilir — pull Drift'e yazar, ekran bellekteki
//      halini kaydedip inen satırları ezerdi.
//   3. Online olmayan pakete dokunulmaz.

import 'package:drift/drift.dart' show Value;
import 'package:dungeon_master_tool/application/providers/cloud_push_provider.dart';
import 'package:dungeon_master_tool/application/providers/connectivity_provider.dart';
import 'package:dungeon_master_tool/application/providers/package_provider.dart';
import 'package:dungeon_master_tool/application/services/cloud_pull_service.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/application/services/world_media_sync.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

/// Testin "açık paketi": yalnız adı tutar, blob yüklemez.
class _OpenPackage extends ActivePackageNotifier {
  _OpenPackage(super.repo, super.ref, String name) {
    state = name;
  }
}

void main() {
  const uid = '11111111-1111-1111-1111-111111111111';
  late AppDatabase db;
  late FakePostgrest cloud;
  late ProviderContainer container;

  setUp(() async {
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    cloud = await FakePostgrest.start(uid: uid);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      cloudPushServiceProvider
          .overrideWithValue(CloudPushService(db: db, client: cloud.client)),
      cloudPullServiceProvider
          .overrideWithValue(CloudPullService(db: db, client: cloud.client)),
      worldMediaSyncProvider.overrideWithValue(null),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
      activePackageProvider.overrideWith(
          (ref) => _OpenPackage(PackageRepositoryImpl(db), ref, 'Açık')),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await cloud.close();
    await db.close();
  });

  /// İlk yayını geçmişte kalmış paket: turu güncelleme turu.
  Future<void> package(String id, String name, {bool online = true}) async {
    await db.packagesDao.upsertPackage(PackagesCompanion.insert(
        id: id, name: name, isOnline: Value(online)));
    await db.packagesDao.setCloudPushAt(id, DateTime(2026, 6, 1));
  }

  test('reconcileAll: kapalı paket push → pull, açık paket yalnız push',
      () async {
    await package('p1', 'Kapalı');
    await package('p2', 'Açık');
    await package('p3', 'Yerel', online: false);
    // Çevrimdışıyken düzenlenmiş kart: damgadan yeni.
    await db.packagesDao.upsertEntity(PackageEntitiesCompanion.insert(
      id: 'k1',
      packageId: 'p1',
      categorySlug: 'npc',
      name: 'Ejder',
      updatedAt: Value(DateTime(2026, 7, 1)),
    ));
    cloud.routes['/rest/v1/user_packages'] = (call) => (200, [
          {'id': call.uri.queryParameters['id']!.substring('eq.'.length)},
        ]);
    cloud.routes['/rest/v1/user_package_entities'] = (_) => (201, [
          {'revision': 5},
        ]);
    cloud.routes['/rest/v1/rpc/get_package_delta'] = (_) => (200, {
          'revision': 0,
          'head': 0,
          'complete': true,
          'tables': <String, Object>{},
          'tombstones': <Object>[],
        });

    await container.read(cloudPushPumpProvider).reconcileAll();

    List<String> hits(String path, String Function(FakeCall c) scope) => [
          for (final c in cloud.calls)
            if (c.uri.path == path) scope(c),
        ];
    expect(hits('/rest/v1/user_packages', (c) => c.uri.queryParameters['id']!),
        unorderedEquals(['eq.p1', 'eq.p2']),
        reason: 'online olmayan paket gitmez');
    expect(
        hits('/rest/v1/rpc/get_package_delta',
            (c) => (c.json as Map)['p_package'] as String),
        ['p1'],
        reason: 'açık paket çekilmez');
    final sent = cloud.calls
        .singleWhere((c) => c.uri.path == '/rest/v1/user_package_entities');
    expect(sent.body, contains('"k1"'),
        reason: 'çevrimdışı düzenleme paket açılmadan gider');
  });
}
