// Faz 5f — dünya açılışının bulut seed'i. Açılış bunu bekliyor: üç sorgu
// sırayla üç gidiş-dönüştü, şimdi eşzamanlı; DM paylaşım gövdelerini hiç
// istemiyor (applier onları DM'de atıyordu).
//
//   flutter test test/application/services/world_mirror_initial_state_test.dart

import 'package:dungeon_master_tool/application/services/world_mirror_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_postgrest.dart';

void main() {
  late FakePostgrest cloud;
  late WorldMirrorService mirror;
  var inFlight = 0;
  var peak = 0;

  setUp(() async {
    cloud = await FakePostgrest.start(
        uid: '11111111-1111-1111-1111-111111111111');
    mirror = WorldMirrorService(cloud.client);
    inFlight = 0;
    peak = 0;
    for (final (table, body) in [
      ('world_characters', <Object>[{'id': 'c1'}]),
      ('entity_shares', <Object>[{'entity_id': 'e1'}]),
      ('world_projection', <String, Object>{'world_id': 'w1'}),
    ]) {
      cloud.routes['/rest/v1/$table'] = (_) async {
        peak = ++inFlight > peak ? inFlight : peak;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        inFlight--;
        return (200, body);
      };
    }
  });

  tearDown(() => cloud.close());

  test('üç sorgu eşzamanlı', () async {
    final s = await mirror.fetchInitialState('w1');
    expect(peak, 3);
    expect(s.characters.single['id'], 'c1');
    expect(s.shares.single['entity_id'], 'e1');
    expect(s.projection?['world_id'], 'w1');
  });

  test('DM paylaşım gövdelerini istemez', () async {
    final s = await mirror.fetchInitialState('w1', withShares: false);
    expect(s.shares, isEmpty);
    expect(cloud.requests.where((r) => r.contains('entity_shares')), isEmpty);
    expect(s.characters, hasLength(1));
  });
}
