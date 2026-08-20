// LAN sync v2 uçtan uca — gerçek HttpServer + gerçek soket üzerinden.
//
// İki ayrı in-memory Drift veritabanı iki cihazı temsil eder. Host sunucu
// açar; peer önce `/pair` ile eşleşir, sonra kalıcı `shared_secret` ile
// içerik çeker/gönderir. Böylece tek testte doğrulanır:
//   - eşleşmemiş cihaz hiçbir şey göremez,
//   - `/pair` yalnız panel açıkken ve doğru sır ile çalışır,
//   - farklı hesap reddedilir,
//   - iki taraf **aynı** ortak sırrı türetir (simetrik eşleşme),
//   - eşleşme sonrası pull/push ve `/unpair` çalışır.
//
//   cd flutter_app && flutter test test/application/services/lan_sync/

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/package_provider.dart';
import 'package:dungeon_master_tool/application/services/lan_sync/lan_device_store.dart';
import 'package:dungeon_master_tool/application/services/lan_sync/lan_sync_client.dart';
import 'package:dungeon_master_tool/application/services/lan_sync/lan_sync_protocol.dart';
import 'package:dungeon_master_tool/application/services/lan_sync/lan_sync_server.dart';
import 'package:dungeon_master_tool/application/services/lan_sync/lan_sync_session.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

/// `create()` şablon zorunlu kılıyor; LAN sync şablondan bağımsız çalıştığı
/// için testte doğrudan blob yazılıyor.
Map<String, dynamic> _worldBlob() =>
    <String, dynamic>{'entities': <String, dynamic>{}};

const _hostUid = 'user-aaa';
const _peerDeviceId = 'peer-device-1';

void main() {
  // SharedPreferences mock'u binding istiyor; ama binding `HttpClient`'i de
  // stub'layıp her isteğe 400 döndürüyor. Bu test gerçek soket üzerinden
  // konuşuyor, o yüzden override kaldırılır.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  late Directory tmp;
  late AppDatabase dbHost;
  late AppDatabase dbPeer;
  late ProviderContainer host;
  late ProviderContainer peer;
  late LanDeviceStore hostStore;
  late LanDeviceStore peerStore;
  late LanSyncServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('lan_sync_v2_test');
    AppPaths.dataRoot = tmp.path;
    await AppPaths.setUser(null);

    dbHost = openTestDatabase();
    dbPeer = openTestDatabase();
    host = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(dbHost)],
    );
    peer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(dbPeer)],
    );
    hostStore = host.read(lanDeviceStoreProvider);
    peerStore = peer.read(lanDeviceStoreProvider);

    server = LanSyncServer(
      session: host.read(lanSyncSessionProvider),
      store: hostStore,
      currentUid: () async => _hostUid,
    );
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    host.dispose();
    peer.dispose();
    await dbHost.close();
    await dbPeer.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Peer tarafını host'a eşleştirir ve peer'ın kaydını da yazar —
  /// `LanSyncController._pair`'in yaptığının testteki karşılığı.
  Future<LanPairOutcome> pairPeer({String uid = _hostUid}) async {
    server.openForPairing();
    final outcome = await LanPairing.viaPin(
      host: '127.0.0.1',
      port: server.port,
      pin: server.pairPin!,
      myDeviceId: _peerDeviceId,
      myDeviceName: 'Peer',
      myUid: uid,
      myPort: 45999,
    );
    await peerStore.upsert(
      deviceId: outcome.deviceId,
      name: outcome.deviceName,
      lastAddress: outcome.address,
      sharedSecret: outcome.sharedSecret,
    );
    return outcome;
  }

  Future<LanSyncClient> pairedClient() async {
    await pairPeer();
    final device = (await peerStore.list()).single;
    final client = LanSyncClient.forDevice(
      device,
      myDeviceId: _peerDeviceId,
      myPort: 45999,
    )!;
    addTearDown(client.close);
    return client;
  }

  group('eşleşme kapısı', () {
    test('eşleşmemiş cihaz /manifest göremez', () async {
      final client = LanSyncClient(
        host: '127.0.0.1',
        port: server.port,
        auth: LanAuth.fromSharedSecret(LanDeviceStore.newSecretHalf()),
        myDeviceId: 'stranger',
        myPort: 1,
      );
      addTearDown(client.close);
      await expectLater(
        client.fetchManifest(),
        throwsA(isA<LanSyncException>()
            .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)),
      );
    });

    test('panel kapalıyken /pair reddedilir', () async {
      expect(server.isOpenForPairing, isFalse);
      await expectLater(
        LanPairing.viaPin(
          host: '127.0.0.1',
          port: server.port,
          pin: '000000',
          myDeviceId: _peerDeviceId,
          myDeviceName: 'Peer',
          myUid: _hostUid,
          myPort: 45999,
        ),
        throwsA(isA<LanSyncException>()
            .having((e) => e.isPairingClosed, 'isPairingClosed', isTrue)),
      );
    });

    test('yanlış PIN ile eşleşilemez', () async {
      server.openForPairing();
      final wrong = server.pairPin == '000000' ? '111111' : '000000';
      await expectLater(
        LanPairing.viaPin(
          host: '127.0.0.1',
          port: server.port,
          pin: wrong,
          myDeviceId: _peerDeviceId,
          myDeviceName: 'Peer',
          myUid: _hostUid,
          myPort: 45999,
        ),
        throwsA(isA<LanSyncException>()
            .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)),
      );
      expect(await hostStore.count(), 0);
    });

    test('başka hesabın cihazı reddedilir', () async {
      await expectLater(
        pairPeer(uid: 'user-bbb'),
        throwsA(isA<LanSyncException>()
            .having((e) => e.isAccountMismatch, 'isAccountMismatch', isTrue)),
      );
      expect(await hostStore.count(), 0);
    });
  });

  group('el sıkışma', () {
    test('iki taraf da aynı ortak sırrı türetir', () async {
      final outcome = await pairPeer();
      final stored = await hostStore.byId(_peerDeviceId);
      expect(stored, isNotNull);
      expect(stored!.sharedSecret, outcome.sharedSecret,
          reason: 'simetrik olmayan sır = imza hiç tutmaz');
      expect(stored.name, 'Peer');
    });

    test('eşleşme iki tarafın listesine de yazılır', () async {
      await pairPeer();
      expect(await hostStore.count(), 1);
      expect(await peerStore.count(), 1);
      expect((await peerStore.list()).single.deviceId,
          isNot(_peerDeviceId)); // host'un kimliği
    });

    test('QR daveti round-trip ediyor ve eşleşme açıyor', () async {
      server.openForPairing();
      final invite = await server.pairInvite();
      expect(invite, isNotNull);

      final decoded = LanPairInvite.fromQrText(invite!.toQrText());
      expect(decoded, isNotNull);
      expect(decoded!.deviceId, invite.deviceId);
      expect(decoded.pairToken, invite.pairToken);
      expect(decoded.uid, _hostUid);
      expect(decoded.port, server.port);

      final outcome = await LanPairing.viaInvite(
        decoded,
        myDeviceId: _peerDeviceId,
        myDeviceName: 'Peer',
        myUid: _hostUid,
        myPort: 45999,
      );
      expect((await hostStore.byId(_peerDeviceId))!.sharedSecret,
          outcome.sharedSecret);
    });

    test('alakasız QR metni reddedilir', () {
      expect(LanPairInvite.fromQrText(null), isNull);
      expect(LanPairInvite.fromQrText('https://example.com'), isNull);
      expect(LanPairInvite.fromQrText('dmt2:not-base64!!'), isNull);
    });

    test('QR PIN taşımaz', () async {
      server.openForPairing();
      final invite = await server.pairInvite();
      expect(invite!.toQrText(), isNot(contains(server.pairPin!)));
    });
  });

  group('eşleşme sonrası', () {
    /// Regresyon: world payload'ının **tamamı** taşınıyor mu?
    ///
    /// `map_data` ve `sessions` granular tablolardan okunuyor ama uzun süre
    /// yalnız `settings_json`'a yazılıyordu; hedefte o satırlar zaten varsa
    /// (yani gerçek, kullanılmış bir dünyada) gelen harita ve oturumlar
    /// görünmez kalıyordu — "eşledim ama gelmedi".
    test('alıcıda dünya zaten varken içeriğin tamamı üzerine yazılır',
        () async {
      const worldId = 'w-shared-1';
      final repoPeer = peer.read(campaignRepositoryProvider);
      await repoPeer.save('Barovia', {
        'world_id': worldId,
        'entities': <String, dynamic>{},
      });
      // Gerçek kullanımdaki yazım yolları: harita ve oturumlar granular
      // tablolara, notlar settings patch'ine gider.
      await repoPeer.saveMapData('Barovia', {'image_path': 'ESKI/peer.png'});
      await repoPeer.saveSessions('Barovia', [
        {'id': 'peer-s', 'name': 'PEER OTURUMU', 'is_active': true,
          'sort_order': 0},
      ]);
      await repoPeer.saveSettingsPatch('Barovia', {
        'combat_state': {'session_notes': 'ESKİ NOT'},
      });

      // `worlds.updatedAt` saniye çözünürlüklü — LWW'nin host'u yeni
      // görmesi için aynı saniyeye düşmemeleri gerekiyor.
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      await host.read(campaignRepositoryProvider).save('Barovia', {
        'world_id': worldId,
        'entities': <String, dynamic>{},
        'combat_state': {
          'session_notes': 'YENİ NOT',
          'encounters': [
            {'id': 'enc1', 'name': 'Kapı Önü'},
          ],
        },
        'mind_maps': {
          'm1': {
            'nodes': [
              {'id': 'n1', 'label': 'Strahd'},
            ],
          },
        },
        'map_data': {'image_path': 'YENİ/host.png'},
        'sessions': [
          {'id': 'host-s', 'name': 'HOST OTURUMU', 'is_active': true,
            'sort_order': 0},
        ],
        'pdf_library': [
          {'name': 'kitap.pdf'},
        ],
      });

      final client = await pairedClient();
      final peerSession = peer.read(lanSyncSessionProvider);
      final plan = diffManifests(
        local: await peerSession.buildManifest(),
        peer: await client.fetchManifest(),
      );
      expect(plan.pull.map((r) => r.id), contains(worldId));
      for (final ref in plan.pull) {
        await peerSession.applyItem(await client.fetchItem(ref));
      }

      final got = await repoPeer.load('Barovia');
      // Granular tablolardan okunanlar — asıl regresyon.
      expect((got['map_data'] as Map)['image_path'], 'YENİ/host.png');
      expect(
        (got['sessions'] as List).map((s) => (s as Map)['name']),
        ['HOST OTURUMU'],
      );
      // settings_json'dan okunanlar.
      expect((got['combat_state'] as Map)['session_notes'], 'YENİ NOT');
      expect((got['combat_state'] as Map)['encounters'], hasLength(1));
      expect(got['mind_maps'], isNotNull);
      expect(got['pdf_library'], hasLength(1));
    });

    test('host\'taki world peer\'a pull edilir', () async {
      await host.read(campaignRepositoryProvider).save('Barovia', _worldBlob());
      final client = await pairedClient();
      final peerSession = peer.read(lanSyncSessionProvider);

      final plan = diffManifests(
        local: await peerSession.buildManifest(),
        peer: await client.fetchManifest(),
      );
      expect(plan.pull.map((r) => r.name), contains('Barovia'));

      for (final ref in plan.pull) {
        await peerSession.applyItem(await client.fetchItem(ref));
      }
      expect(
        await peer.read(campaignRepositoryProvider).getAvailable(),
        contains('Barovia'),
      );
    });

    test('peer\'daki paket host\'a push edilir', () async {
      await peer
          .read(packageRepositoryProvider)
          .save('Ev Kuralları', <String, dynamic>{});
      final client = await pairedClient();
      final peerSession = peer.read(lanSyncSessionProvider);

      final plan = diffManifests(
        local: await peerSession.buildManifest(),
        peer: await client.fetchManifest(),
      );
      expect(plan.push.map((r) => r.name), contains('Ev Kuralları'));

      for (final ref in plan.push) {
        await client.pushItem((await peerSession.loadItem(ref))!);
      }
      expect(
        await host.read(packageRepositoryProvider).getAvailable(),
        contains('Ev Kuralları'),
      );
    });

    test('ikinci tur hiçbir şey taşımaz — LWW restamp tutuyor', () async {
      await host.read(campaignRepositoryProvider).save('Barovia', _worldBlob());
      final client = await pairedClient();
      final peerSession = peer.read(lanSyncSessionProvider);

      Future<LanSyncPlan> currentPlan() async => diffManifests(
            local: await peerSession.buildManifest(),
            peer: await client.fetchManifest(),
          );

      for (final ref in (await currentPlan()).pull) {
        await peerSession.applyItem(await client.fetchItem(ref));
      }
      final second = await currentPlan();
      expect(second.isEmpty, isTrue,
          reason: 'pull=${second.pull} push=${second.push}');
      expect(second.skipped, greaterThan(0));
    });

    /// Regresyon: online dünyada resimler `dmt-asset://` ref'ine dönüşüyor ve
    /// baytlar dünya klasöründe değil, içerik-adresli önbellekte duruyor.
    /// Manifest yalnız `worlds/{ad}/` altını tararken bu baytlar hiç
    /// taşınmıyordu — karşı cihazda resim ancak internete çıkınca geliyordu.
    test('bulut ref baytları da medya listesine girer', () async {
      final bytes = utf8.encode('sahte-png-baytlari');
      final sha = sha256.convert(bytes).toString();
      final blob = File(p.join(AppPaths.cacheDir, 'content', '$sha.bin'));
      await blob.parent.create(recursive: true);
      await blob.writeAsBytes(bytes, flush: true);

      await host.read(campaignRepositoryProvider).save('Barovia', {
        'entities': {
          'e1': {
            'id': 'e1',
            'name': 'Strahd',
            'type': 'npc',
            'images': ['dmt-asset://u1/c1/$sha.png'],
          },
        },
      });

      final client = await pairedClient();
      final ref = (await client.fetchManifest())
          .firstWhere((r) => r.type == LanItemType.world);
      final item = await client.fetchItem(ref);

      final entry = item.media.where((m) => m.sha256 == sha);
      expect(entry, hasLength(1),
          reason: 'cache/content blob medya listesinde yok: ${item.media}');
      expect(entry.single.size, bytes.length);
      // Baytlar gerçekten tel üzerinden gelebiliyor mu?
      expect(await client.fetchMedia(entry.single.path), bytes);
    });

    test('ping çalışır ve /unpair kaydı siler', () async {
      final client = await pairedClient();
      expect(await client.ping(), isTrue);

      await client.unpair();
      expect(await hostStore.count(), 0);
      // Eşleşme gittiğine göre aynı istemci artık hiçbir şey göremez.
      await expectLater(client.fetchManifest(), throwsA(isA<LanSyncException>()));
    });
  });

  group('yol güvenliği', () {
    test('medya yolu veri kökünün dışına kaçamaz', () {
      expect(LanSyncSession.resolveMedia('../../etc/passwd'), isNull);
      expect(LanSyncSession.resolveMedia('worlds/x/media/a.png'), isNotNull);
    });

    test('rewriteRoots yalnız gönderenin kökü altındaki yolları çevirir', () {
      final out = LanSyncSession.rewriteRoots(
        {
          'image_path': '/home/a/data/worlds/W/media/x.png',
          'cloud': 'dmt-asset://abc',
          'unrelated': '/tmp/other.png',
          'nested': [
            {'p': '/home/a/data/packages/P/cover.png'}
          ],
        },
        '/home/a/data',
        '/mobile/data',
      ) as Map<String, dynamic>;

      // Yeniden yazım **alıcıda** çalışıyor, dolayısıyla sonuç alıcının
      // ayırıcısıyla birleşir — beklenti de öyle kurulmalı, yoksa test
      // yalnız POSIX makinede geçer.
      expect(out['image_path'],
          p.joinAll(['/mobile/data', 'worlds', 'W', 'media', 'x.png']));
      expect(out['cloud'], 'dmt-asset://abc');
      expect(out['unrelated'], '/tmp/other.png');
      expect((out['nested'] as List).first,
          {'p': p.joinAll(['/mobile/data', 'packages', 'P', 'cover.png'])});
    });

    test('Windows kökünden POSIX köküne yol çevrilir', () {
      final out = LanSyncSession.rewriteRoots(
        {'image_path': r'C:\Users\eren\DMT\worlds\W\media\x.png'},
        r'C:\Users\eren\DMT',
        '/home/eren/DMT',
      ) as Map<String, dynamic>;
      expect(out['image_path'],
          p.joinAll(['/home/eren/DMT', 'worlds', 'W', 'media', 'x.png']));
    });
  });
}
