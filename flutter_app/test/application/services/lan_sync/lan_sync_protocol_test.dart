import 'dart:convert';

import 'package:dungeon_master_tool/application/services/lan_sync/lan_sync_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

LanItemRef _ref(String id, DateTime ts, {LanItemType type = LanItemType.world}) =>
    LanItemRef(type: type, id: id, name: id, updatedAt: ts);

void main() {
  final t0 = DateTime.utc(2026, 8, 20, 10);
  final t1 = DateTime.utc(2026, 8, 20, 11);

  group('diffManifests', () {
    test('yalnız peer\'da olan item pull edilir', () {
      final plan = diffManifests(local: [], peer: [_ref('a', t0)]);
      expect(plan.pull.map((r) => r.id), ['a']);
      expect(plan.push, isEmpty);
      expect(plan.skipped, 0);
    });

    test('yalnız bizde olan item push edilir', () {
      final plan = diffManifests(local: [_ref('a', t0)], peer: []);
      expect(plan.push.map((r) => r.id), ['a']);
      expect(plan.pull, isEmpty);
    });

    test('peer daha yeniyse pull, biz daha yeniysek push', () {
      final plan = diffManifests(
        local: [_ref('a', t0), _ref('b', t1)],
        peer: [_ref('a', t1), _ref('b', t0)],
      );
      expect(plan.pull.map((r) => r.id), ['a']);
      expect(plan.push.map((r) => r.id), ['b']);
      expect(plan.skipped, 0);
    });

    test('aynı zaman damgası hiçbir şey taşımaz', () {
      final plan = diffManifests(local: [_ref('a', t0)], peer: [_ref('a', t0)]);
      expect(plan.isEmpty, isTrue);
      expect(plan.skipped, 1);
    });

    test('aynı id farklı türde ayrı item sayılır', () {
      final plan = diffManifests(
        local: [_ref('a', t0)],
        peer: [_ref('a', t0, type: LanItemType.package)],
      );
      expect(plan.pull.single.type, LanItemType.package);
      expect(plan.push.single.type, LanItemType.world);
    });

    test('JSON round-trip ref kimliğini korur', () {
      final ref = _ref('a', t0);
      final back = LanItemRef.fromJson(
        jsonDecode(jsonEncode(ref.toJson())) as Map<String, dynamic>,
      )!;
      expect(back.key, ref.key);
      expect(back.updatedAt, ref.updatedAt);
      expect(diffManifests(local: [ref], peer: [back]).skipped, 1);
    });

    test('içerik aynıyken yalnız görünüm değiştiyse de taşınır', () {
      final mine = _ref('a', t0);
      final theirs = LanItemRef(
        type: LanItemType.world,
        id: 'a',
        name: 'a',
        updatedAt: t0,
        viewUpdatedAt: t1,
      );
      final plan = diffManifests(local: [mine], peer: [theirs]);
      expect(plan.pull.single.id, 'a');
      expect(plan.skipped, 0);
    });

    test('görünüm zaman damgası içerikten eskiyse LWW\'yi değiştirmez', () {
      final mine = LanItemRef(
        type: LanItemType.world,
        id: 'a',
        name: 'a',
        updatedAt: t1,
        viewUpdatedAt: t0,
      );
      final plan = diffManifests(local: [mine], peer: [_ref('a', t0)]);
      expect(plan.push.single.id, 'a');
      expect(plan.pull, isEmpty);
    });

    test('view_updated_at JSON round-trip\'te korunur', () {
      final ref = LanItemRef(
        type: LanItemType.world,
        id: 'a',
        name: 'a',
        updatedAt: t0,
        viewUpdatedAt: t1,
      );
      final back = LanItemRef.fromJson(
        jsonDecode(jsonEncode(ref.toJson())) as Map<String, dynamic>,
      )!;
      expect(back.viewUpdatedAt, t1);
      expect(back.effectiveUpdatedAt, t1);
      expect(diffManifests(local: [ref], peer: [back]).skipped, 1);
    });
  });

  group('LanItemPayload extras', () {
    test('extras JSON round-trip\'te korunur', () {
      final item = LanItemPayload(
        ref: _ref('w1', t0),
        payload: const {'world_name': 'Test'},
        dataRoot: '/home/dm/DMT',
        extras: const {
          'installed_packages': [
            {'id': 'p1', 'name': 'Pack', 'version': '1'},
          ],
          'ui_view': {
            'view': {'rightSidebar': 'pdf'},
            'db_open_left': ['e1', 'e2'],
          },
        },
      );
      final back = LanItemPayload.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      )!;
      expect(
        (back.extras['installed_packages'] as List).single,
        {'id': 'p1', 'name': 'Pack', 'version': '1'},
      );
      expect(
        ((back.extras['ui_view'] as Map)['db_open_left'] as List),
        ['e1', 'e2'],
      );
    });

    test('extras yoksa boş map olur (eski sürümle uyum)', () {
      final back = LanItemPayload.fromJson({
        'ref': _ref('w1', t0).toJson(),
        'payload': const <String, dynamic>{},
        'data_root': '/x',
      })!;
      expect(back.extras, isEmpty);
    });
  });

  group('LanAuth', () {
    late LanAuth host;
    late LanAuth client;
    const pin = '004271';
    final nonce = LanAuth.generateHostNonce();
    final body = utf8.encode('{"hello":"world"}');

    setUp(() {
      final key = LanAuth.deriveSessionKey(pin, nonce);
      host = LanAuth(sessionKey: key);
      client = LanAuth(sessionKey: key);
    });

    test('doğru imza kabul edilir', () {
      final header =
          client.buildHeader(method: 'GET', path: '/manifest', body: body);
      expect(
        host.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isTrue,
      );
    });

    test('yanlış PIN reddedilir', () {
      final wrong = LanAuth(
        sessionKey: LanAuth.deriveSessionKey('999999', nonce),
      );
      final header =
          wrong.buildHeader(method: 'GET', path: '/manifest', body: body);
      expect(
        host.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isFalse,
      );
    });

    test('gövde değişirse imza tutmaz', () {
      final header =
          client.buildHeader(method: 'POST', path: '/item/world/x', body: body);
      expect(
        host.verify(
          header: header,
          method: 'POST',
          path: '/item/world/x',
          body: utf8.encode('{"hello":"tampered"}'),
        ),
        isFalse,
      );
    });

    test('başka path\'e yeniden kullanılamaz', () {
      final header =
          client.buildHeader(method: 'GET', path: '/manifest', body: body);
      expect(
        host.verify(
            header: header, method: 'GET', path: '/item/world/x', body: body),
        isFalse,
      );
    });

    test('eski zaman damgası reddedilir', () {
      final header = client.buildHeader(
        method: 'GET',
        path: '/manifest',
        body: body,
        now: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(
        host.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isFalse,
      );
    });

    test('aynı nonce ikinci kez reddedilir (replay)', () {
      final header =
          client.buildHeader(method: 'GET', path: '/manifest', body: body);
      expect(
        host.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isTrue,
      );
      expect(
        host.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isFalse,
      );
    });

    test('bozuk başlık reddedilir', () {
      for (final h in [null, '', 'Bearer xyz', 'DMT-LAN abc', 'DMT-LAN a.b.c']) {
        expect(
          host.verify(
              header: h, method: 'GET', path: '/manifest', body: body),
          isFalse,
          reason: 'header=$h',
        );
      }
    });

    test('PIN 6 hane, baştaki sıfır korunur', () {
      for (var i = 0; i < 200; i++) {
        expect(LanAuth.generatePin(), matches(RegExp(r'^\d{6}$')));
      }
    });
  });

  group('LanAnnounce (presence)', () {
    test('encode/decode round-trip', () {
      const a = LanAnnounce(
        deviceId: 'dev-1',
        port: 45456,
        uidFingerprint: 'deadbeef',
      );
      final back = LanAnnounce.decode(utf8.encode(a.encode()))!;
      expect(back.deviceId, 'dev-1');
      expect(back.port, 45456);
      expect(back.uidFingerprint, 'deadbeef');
    });

    test('alakasız ya da eski sürüm paket null döner', () {
      expect(LanAnnounce.decode(utf8.encode('not json')), isNull);
      expect(LanAnnounce.decode(utf8.encode('{"dmt":1,"id":"x","p":1}')), isNull);
      expect(LanAnnounce.decode(utf8.encode('{"dmt":2}')), isNull);
    });

    test('duyuru ham uid taşımaz', () {
      const uid = 'user-aaa';
      final a = LanAnnounce(
        deviceId: 'dev-1',
        port: 1,
        uidFingerprint: uidFingerprint(uid),
      );
      expect(a.encode(), isNot(contains(uid)));
      expect(uidFingerprint(uid), hasLength(8));
      expect(uidFingerprint(uid), uidFingerprint(uid));
      expect(uidFingerprint(uid), isNot(uidFingerprint('user-bbb')));
    });
  });

  group('LanPairInvite (QR)', () {
    LanPairInvite invite() => const LanPairInvite(
          deviceId: 'dev-1',
          deviceName: 'Eren-PC',
          addresses: ['192.168.1.5'],
          port: 45456,
          pairToken: 'dG9rZW4tMzItYnl0ZXM=',
          uid: 'user-aaa',
        );

    test('QR metni round-trip ediyor', () {
      final back = LanPairInvite.fromQrText(invite().toQrText())!;
      expect(back.deviceId, 'dev-1');
      expect(back.deviceName, 'Eren-PC');
      expect(back.addresses, ['192.168.1.5']);
      expect(back.port, 45456);
      expect(back.pairToken, 'dG9rZW4tMzItYnl0ZXM=');
      expect(back.uid, 'user-aaa');
    });

    test('yabancı QR reddedilir', () {
      expect(LanPairInvite.fromQrText(null), isNull);
      expect(LanPairInvite.fromQrText(''), isNull);
      expect(LanPairInvite.fromQrText('https://example.com'), isNull);
      expect(LanPairInvite.fromQrText('dmt2:not-base64!!!'), isNull);
      // Doğru ön ek, eksik alan.
      expect(
        LanPairInvite.fromQrText(
          'dmt2:${base64Url.encode(utf8.encode('{"i":"x"}'))}',
        ),
        isNull,
      );
    });
  });

  group('deriveSharedSecret', () {
    test('iki taraf aynı sırrı üretir, sıra değişince farklı', () {
      const a = 'aGFsZi1B';
      const b = 'aGFsZi1C';
      expect(
        deriveSharedSecret(clientHalf: a, hostHalf: b),
        deriveSharedSecret(clientHalf: a, hostHalf: b),
      );
      expect(
        deriveSharedSecret(clientHalf: a, hostHalf: b),
        isNot(deriveSharedSecret(clientHalf: b, hostHalf: a)),
      );
    });

    test('üretilen sır LanAuth anahtarı olarak kullanılabilir', () {
      final shared = deriveSharedSecret(
        clientHalf: LanAuthTestHalves.a,
        hostHalf: LanAuthTestHalves.b,
      );
      final one = LanAuth.fromSharedSecret(shared);
      final two = LanAuth.fromSharedSecret(shared);
      final body = utf8.encode('{}');
      final header =
          one.buildHeader(method: 'GET', path: '/manifest', body: body);
      expect(
        two.verify(
            header: header, method: 'GET', path: '/manifest', body: body),
        isTrue,
      );
    });
  });
}

/// Sabit yarımlar — rastgelelik testin belirleyiciliğini bozmasın.
class LanAuthTestHalves {
  static const a = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';
  static const b = 'ZmVkY2JhOTg3NjU0MzIxMGZlZGNiYTk4NzY1NDMyMTA=';
}
