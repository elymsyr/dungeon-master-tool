import 'package:dungeon_master_tool/data/datasources/local/guest_notification_store.dart';
import 'package:dungeon_master_tool/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppNotification _n(String id) => AppNotification(
    id: id, title: id, blocks: const [], createdAt: DateTime(2026));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('read state is local and dismiss drops only read ones', () async {
    final store = GuestNotificationStore();
    final list = [_n('a'), _n('b')];

    var out = await store.apply(list);
    expect(out.map((n) => n.read), [false, false]);

    await store.markRead('a');
    out = await store.apply(list);
    expect(out.map((n) => (n.id, n.read)), [('a', true), ('b', false)]);

    await store.dismissRead();
    out = await store.apply(list);
    expect(out.map((n) => n.id), ['b']);
    expect(out.single.read, isFalse);
  });
}
