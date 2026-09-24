// Faz 9 — bulut göstergesinin beslendiği durum. Göstergenin "hata kalıcı,
// çevrimdışı bekliyor" kuralı buradaki geçişlere dayanıyor.
//
//   cd flutter_app && flutter test test/application/providers/cloud_sync_status_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/application/providers/cloud_sync_status_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CloudSyncStatusNotifier n;
  setUp(() => n = CloudSyncStatusNotifier());
  CloudSyncStatus? s() => n.state['w'];

  test('başarılı push damgayı atar, reddedilen satır sorun olur', () {
    n.report('w', CloudSyncIssue.push);
    expect(s()!.syncedAt, isNotNull);
    expect(s()!.problemCount, 0);

    n.report('w', CloudSyncIssue.push, failed: 3);
    expect(s()!.problems[CloudSyncIssue.push]!.count, 3);
    expect(s()!.problems[CloudSyncIssue.push]!.error, isNull);
  });

  test('ağ hatası sorunu silmez, yalnız bekliyor der; sonraki başarı ikisini de temizler', () {
    n.report('w', CloudSyncIssue.push, error: StateError('rls'));
    n.report('w', CloudSyncIssue.push,
        error: const SocketException('Failed host lookup'));
    expect(s()!.offline, isTrue);
    expect(s()!.problemCount, 1);

    n.report('w', CloudSyncIssue.push);
    expect(s()!.offline, isFalse);
    expect(s()!.problemCount, 0);
  });

  test('türler birbirini temizlemez', () {
    n.report('w', CloudSyncIssue.push, failed: 2);
    n.report('w', CloudSyncIssue.pull);
    expect(s()!.problems.keys, [CloudSyncIssue.push]);
  });

  test('sayaç eşleşir; online olmayan öğenin kaydı kalkar', () {
    n.started('w');
    n.started('w');
    n.ended('w');
    expect(s()!.syncing, isTrue);
    n.ended('w');
    expect(s()!.syncing, isFalse);

    n.remove('w');
    n.ended('w'); // kaydı geri açmaz
    expect(s(), isNull);
  });
}
