// Faz 5d — dünya medyasının yüklenmesi. Ağ yerine sahte PostgREST; worker'ın
// imza ucu ve R2'nin imzalı URL'i de aynı sahte sunucuya yönleniyor, yani
// RPC → imza → PUT → onay zinciri gerçekten koşuyor.
//
//   flutter test test/application/services/world_media_sync_test.dart
//
// Kapsam:
//   1. Bulutta olan atlanır; kalan rezerve → imza → PUT (boyut ve tür imzaya
//      bağlı olanla aynı) → onay. Limiti aşan rezerve bile edilmez, raporda.
//   2. Kota reddi tipli hata.
//   3. PUT yarıda koparsa (denemeler bitti) yalnız bitenler onaylanır;
//      sonraki tur kalanı dener.
//   4. Yanıt vermeyen PUT zaman aşımına düşer — şerit kilitlenmez, biten
//      onaylanır.
//   5. Dosyaya özgü ret (4xx) o dosyayı atlar, tur sürer; 403 önce imzayı
//      tazeler.
//   6. Onay onar dosyada bir gider — kopan turda kayıp bununla sınırlı.
//   6b. PUT'lar eşzamanlı ama en çok altı (Faz 5f).
//   7. Yetim temizliği pencereden genç satıra ve hâlâ anılana dokunmaz.
//   8. Projeksiyonun tek dosyası: yüklenince ref döner, ikinci kez ağa çıkmaz.

import 'dart:async';
import 'dart:io';

import 'package:dungeon_master_tool/application/services/content_ref_index.dart';
import 'package:dungeon_master_tool/application/services/content_store.dart';
import 'package:dungeon_master_tool/application/services/world_media_sync.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/network/asset_service.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:dungeon_master_tool/domain/value_objects/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_postgrest.dart';
import '../../support/test_database.dart';

void main() {
  const uid = '11111111-1111-1111-1111-111111111111';
  const image = MediaKind.worldEntityImage;

  late AppDatabase db;
  late FakePostgrest cloud;
  late HttpClient http;
  late Directory tmp;
  late ContentRefIndex index;
  late WorldMediaSync sync;

  setUp(() async {
    db = openTestDatabase();
    cloud = await FakePostgrest.start(uid: uid);
    http = HttpClient();
    tmp = await Directory.systemTemp.createTemp('world_media_sync_');
    index = ContentRefIndex(() => db);
    final store = ContentStore(Directory(p.join(tmp.path, 'content')));
    sync = WorldMediaSync(
      client: cloud.client,
      assets: AssetService(
        supabase: cloud.client,
        workerBaseUrl: cloud.baseUrl,
        contentStore: store,
        httpClient: http,
        stall: const Duration(milliseconds: 300),
      ),
      index: index,
      store: store,
      backoff: (_) => Duration.zero,
    );
  });

  tearDown(() async {
    http.close(force: true);
    await cloud.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// Diske bir dosya yazar, sha'sını indekse kaydeder.
  Future<String> file(String name, List<int> bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(bytes);
    return (await index.shaFor(f.path))!;
  }

  void reply(Object body, [int status = 200]) =>
      cloud.replies.add(() => (status, body));

  List<FakeCall> callsTo(String path) =>
      [for (final c in cloud.calls) if (c.uri.path == path) c];

  test('bulutta olan atlanır; kalan rezerve → imza → PUT → onay', () async {
    final inCloud = await file('a.png', 'aaaa'.codeUnits);
    final fresh = await file('b.jpg', 'bbbbbb'.codeUnits);
    final big = await file('big.png', List.filled(image.maxBytes + 1, 1));
    final nowhere = 'c' * 64; // bu cihazda baytı yok — başka cihazın işi

    reply([
      {'sha256': inCloud}
    ]); // world_media (uploaded)
    reply({
      'upload': [fresh],
      'too_large': [],
    });
    reply({
      'urls': {fresh: '${cloud.baseUrl}/r2/b'}
    });
    reply({}); // R2 PUT
    reply(1); // onay

    final rep = await sync.upload('w1', {
      inCloud: const WorldMediaRef('.png', image),
      fresh: const WorldMediaRef('.jpg', image),
      big: const WorldMediaRef('.png', image),
      nowhere: const WorldMediaRef('.png', image),
    });

    expect(rep.uploaded, 1);
    expect(rep.tooLarge, ['big.png']);

    final items = (callsTo('/rest/v1/rpc/world_media_reserve').single.json
        as Map)['_items'] as List;
    expect(items, [
      {
        'sha': fresh,
        'ext': '.jpg',
        'bytes': 6,
        'kind': 'world_entity_image',
        'mime': 'image/jpeg',
      }
    ], reason: 'bulutta olan, limit aşan ve baytı olmayan rezerve edilmez');

    final sign = callsTo('/world-media/sign').single.json as Map;
    expect(sign, {
      'op': 'put',
      'shas': [fresh],
      'world_id': 'w1',
    });

    final put = callsTo('/r2/b').single;
    expect(put.method, 'PUT');
    expect(put.contentLength, 6, reason: 'imzaya bağlı boyut');
    expect(put.contentType, 'image/jpeg', reason: 'imzaya bağlı tür');
    expect(put.body, 'bbbbbb');

    expect((callsTo('/rest/v1/rpc/world_media_confirm').single.json as Map),
        {'_world': 'w1', '_shas': [fresh]});
    expect(cloud.replies, isEmpty);
  });

  test('kota reddi WorldMediaQuotaException olur, hiçbir şey yüklenmez',
      () async {
    final sha = await file('a.png', 'aaaa'.codeUnits);
    reply(<Object>[]);
    reply({
      'code': 'P0001',
      'message': 'media_user_full',
      'hint': 'used=1 new=4 cap=2',
      'details': null,
    }, 400);

    await expectLater(
      sync.upload('w1', {sha: const WorldMediaRef('.png', image)}),
      throwsA(isA<WorldMediaQuotaException>()
          .having((e) => e.pool, 'pool', false)),
    );
    expect(callsTo('/world-media/sign'), isEmpty);
  });

  test('PUT yarıda koparsa yalnız biten onaylanır, sonraki tur kalanı dener',
      () async {
    final b = await file('b.png', 'bb'.codeUnits);
    final c = await file('c.png', 'ccc'.codeUnits);
    final refs = {
      b: const WorldMediaRef('.png', image),
      c: const WorldMediaRef('.png', image),
    };
    reply(<Object>[]);
    reply({
      'upload': [b, c],
      'too_large': [],
    });
    reply({
      'urls': {b: '${cloud.baseUrl}/r2/1', c: '${cloud.baseUrl}/r2/2'}
    });
    // PUT'lar eşzamanlı: yanıt sıraya değil yola bağlı.
    cloud.routes['/r2/1'] = (_) => (200, {});
    cloud.routes['/r2/2'] = (_) => (500, {'error': 'boom'});
    reply(1); // onay

    await expectLater(
        sync.upload('w1', refs), throwsA(isA<AssetServiceException>()));
    expect(callsTo('/r2/2'), hasLength(3), reason: 'geçici hata yeniden denenir');
    final done =
        (callsTo('/rest/v1/rpc/world_media_confirm').single.json as Map)['_shas'];
    expect(done, [b]);
    final left = c;

    // Sonraki tur: onaylanan önbellekte, yalnız kalan rezerve edilir.
    reply({
      'upload': [left],
      'too_large': [],
    });
    reply({
      'urls': {left: '${cloud.baseUrl}/r2/3'}
    });
    cloud.routes['/r2/3'] = (_) => (200, {});
    reply(1);
    final rep = await sync.upload('w1', refs);
    expect(rep.uploaded, 1);
    final second = callsTo('/rest/v1/rpc/world_media_reserve').last.json as Map;
    expect([for (final i in second['_items'] as List) i['sha']], [left]);
  });

  test('yanıt vermeyen PUT zaman aşımına düşer, biten onaylanır', () async {
    final b = await file('b.png', 'bb'.codeUnits);
    final c = await file('c.png', 'ccc'.codeUnits);
    reply(<Object>[]);
    reply({
      'upload': [b, c],
      'too_large': [],
    });
    reply({
      'urls': {b: '${cloud.baseUrl}/r2/1', c: '${cloud.baseUrl}/r2/2'}
    });
    final hang = Completer<(int, Object)>();
    cloud.routes['/r2/1'] = (_) => (200, {});
    cloud.routes['/r2/2'] = (_) => hang.future;
    reply(1);

    await expectLater(
      sync.upload('w1', {
        b: const WorldMediaRef('.png', image),
        c: const WorldMediaRef('.png', image),
      }),
      throwsA(isA<TimeoutException>()),
    );
    expect(
        (callsTo('/rest/v1/rpc/world_media_confirm').single.json
            as Map)['_shas'],
        [b]);
  });

  test('4xx o dosyayı atlar, tur sürer; 403 imzayı bir kez tazeler',
      () async {
    final a = await file('a.png', 'a'.codeUnits);
    final b = await file('b.png', 'bb'.codeUnits);
    final c = await file('c.png', 'ccc'.codeUnits);
    reply(<Object>[]);
    reply({
      'upload': [a, b, c],
      'too_large': [],
    });
    reply({
      'urls': {
        a: '${cloud.baseUrl}/r2/a',
        b: '${cloud.baseUrl}/r2/b',
        c: '${cloud.baseUrl}/r2/c',
      }
    });
    cloud.routes['/r2/a'] = (_) => (400, {'error': 'bad'}); // dosyaya özgü ret
    cloud.routes['/r2/b2'] = (_) => (200, {}); // b yeniden
    cloud.routes['/r2/b'] = (_) => (403, {'error': 'expired'}); // imza dolmuş
    cloud.routes['/r2/c'] = (_) => (200, {});
    reply({
      'urls': {b: '${cloud.baseUrl}/r2/b2'}
    });
    reply(2);

    final rep = await sync.upload('w1', {
      a: const WorldMediaRef('.png', image),
      b: const WorldMediaRef('.png', image),
      c: const WorldMediaRef('.png', image),
    });
    expect(rep.uploaded, 2);
    expect(rep.failed, ['a.png']);
    expect(callsTo('/r2/a'), hasLength(1), reason: '4xx yeniden denenmez');
    expect(callsTo('/r2/b2'), hasLength(1));
    expect(
        (callsTo('/world-media/sign').last.json as Map)['shas'], [b]);
    expect(
        (callsTo('/rest/v1/rpc/world_media_confirm').single.json
            as Map)['_shas'],
        unorderedEquals([b, c]));
    expect(cloud.replies, isEmpty);
  });

  test('onay onar dosyada bir gider', () async {
    final shas = [
      for (var i = 0; i < 12; i++) await file('f$i.png', [i, i, i]),
    ];
    reply(<Object>[]);
    reply({'upload': shas, 'too_large': []});
    reply({
      'urls': {for (final s in shas) s: '${cloud.baseUrl}/r2/$s'}
    });
    cloud.routes['/r2/'] = (_) => (200, {});
    reply(10);
    reply(2);

    final rep = await sync.upload('w1', {
      for (final s in shas) s: const WorldMediaRef('.png', image),
    });
    expect(rep.uploaded, 12);
    final confirms = [
      for (final c in callsTo('/rest/v1/rpc/world_media_confirm'))
        ((c.json as Map)['_shas'] as List).length,
    ];
    expect(confirms, [10, 2]);
  });

  test('PUT\'lar eşzamanlı, en çok altı', () async {
    final shas = [
      for (var i = 0; i < 14; i++) await file('p$i.png', [i, i]),
    ];
    reply(<Object>[]);
    reply({'upload': shas, 'too_large': []});
    reply({
      'urls': {for (final s in shas) s: '${cloud.baseUrl}/r2/$s'}
    });
    var inFlight = 0;
    var peak = 0;
    cloud.routes['/r2/'] = (_) async {
      peak = ++inFlight > peak ? inFlight : peak;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      return (200, {});
    };
    reply(10);
    reply(4);

    final progress = <int>[];
    final rep = await sync.upload('w1', {
      for (final s in shas) s: const WorldMediaRef('.png', image),
    }, onProgress: (done, _) => progress.add(done));
    expect(rep.uploaded, 14);
    expect(rep.bytes, 28);
    expect(peak, 6);
    expect(progress.last, 14);
  });

  test('yetim temizliği: yalnız eski ve artık anılmayan silinir', () async {
    final old = 'a' * 64;
    final young = 'b' * 64;
    final kept = 'c' * 64;
    reply([
      {'sha256': old, 'created_at': '2026-01-01T00:00:00Z'},
      {
        'sha256': young,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      {'sha256': kept, 'created_at': '2026-01-01T00:00:00Z'},
    ]);
    reply(<Object>[]); // DELETE

    expect(await sync.prune('w1', {kept}), 1);
    final del = cloud.calls.last;
    expect(del.method, 'DELETE');
    final q = Uri.decodeComponent(del.uri.query);
    expect(q, contains(old));
    expect(q, isNot(contains(young)),
        reason: 'öbür cihazın yeni görseli, anan satır henüz inmemiş olabilir');
    expect(q, isNot(contains(kept)));
  });

  test('projeksiyonun tek dosyası: ref döner, ikinci kez ağa çıkmaz', () async {
    final path = p.join(tmp.path, 'token.png');
    await File(path).writeAsBytes('tok'.codeUnits);
    final sha = (await index.shaFor(path))!;

    reply(<Object>[]);
    reply({
      'upload': [sha],
      'too_large': [],
    });
    reply({
      'urls': {sha: '${cloud.baseUrl}/r2/t'}
    });
    reply({});
    reply(1);

    final ref = await sync.publish('w1', path);
    expect(ref, AssetRef.formatContentUri(sha, '.png'));

    final before = cloud.calls.length;
    expect(await sync.publish('w1', path), ref);
    expect(cloud.calls.length, before);
  });
}
