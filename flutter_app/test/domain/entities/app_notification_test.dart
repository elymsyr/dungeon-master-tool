import 'package:dungeon_master_tool/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(List<Map<String, dynamic>> blocks) => AppNotification(
      id: 'n',
      title: 't',
      blocks: AppNotification.parseBlocks(blocks),
      createdAt: DateTime(2026),
    );

void main() {
  test('image block round-trips with link and banner', () {
    final j = {
      'id': 'b1',
      'type': 'image',
      'url': 'https://x/a.png',
      'path': 'u/1_b1.png',
      'link': 'https://dmt.app',
      'banner': true,
    };
    final b = NotificationBlock.fromJson(j) as ImageBlock;
    expect(b.url, 'https://x/a.png');
    expect(b.path, 'u/1_b1.png');
    expect(b.link, 'https://dmt.app');
    expect(b.banner, isTrue);
    expect(b.toJson(), j);
  });

  test('image block without link omits link and banner keys', () {
    final b = NotificationBlock.fromJson(
        {'id': 'b2', 'type': 'image', 'url': 'u', 'path': 'p', 'link': ''})
        as ImageBlock;
    expect(b.link, isNull);
    expect(b.banner, isFalse);
    expect(b.toJson().containsKey('link'), isFalse);
    expect(b.toJson().containsKey('banner'), isFalse);
  });

  test('banner is first image block flagged banner; bodyBlocks excludes it',
      () {
    final n = _n([
      {'id': 'a', 'type': 'image', 'url': 'u', 'path': 'p', 'banner': true},
      {'id': 'b', 'type': 'markdown', 'text': 'hi'},
      {'id': 'c', 'type': 'image', 'url': 'u2', 'path': 'p2'},
    ]);
    expect(n.banner?.id, 'a');
    expect(n.bodyBlocks.map((b) => b.id), ['b', 'c']);
  });

  test('image block not flagged banner is not the banner', () {
    final n = _n([
      {'id': 'c', 'type': 'image', 'url': 'u2', 'path': 'p2'},
    ]);
    expect(n.banner, isNull);
    expect(n.bodyBlocks.length, 1);
  });

  test('legacy notification has no banner and bodyBlocks == blocks', () {
    final n = _n([
      {'id': 'b', 'type': 'markdown', 'text': 'hi'},
      {'id': 'p', 'type': 'poll', 'question': 'q', 'options': ['x']},
    ]);
    expect(n.banner, isNull);
    expect(n.bodyBlocks, n.blocks);
  });

  test('isValidNotificationLink', () {
    expect(isValidNotificationLink(''), isTrue);
    expect(isValidNotificationLink('https://a.b/c'), isTrue);
    expect(isValidNotificationLink('http://a.b'), isTrue);
    expect(isValidNotificationLink('javascript:alert(1)'), isFalse);
    expect(isValidNotificationLink('ftp://a.b'), isFalse);
    expect(isValidNotificationLink('example.com'), isFalse);
    expect(isValidNotificationLink('https://'), isFalse);
  });

  test('notificationImageMime', () {
    expect(notificationImageMime('PNG'), 'image/png');
    expect(notificationImageMime('jpg'), 'image/jpeg');
    expect(notificationImageMime('jpeg'), 'image/jpeg');
    expect(notificationImageMime('webp'), 'image/webp');
    expect(notificationImageMime('gif'), isNull);
    expect(kNotificationImageMaxBytes, 10485760);
  });
}
