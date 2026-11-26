import 'dart:convert';

/// Per-file upload cap — matches the `notification-images` bucket (110).
const int kNotificationImageMaxBytes = 10 * 1024 * 1024;

/// Empty (no link) or an absolute http(s) URL with a host. Anything else —
/// `javascript:`, `ftp://`, a bare `example.com` — is rejected.
bool isValidNotificationLink(String s) {
  if (s.isEmpty) return true;
  final u = Uri.tryParse(s);
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}

/// MIME for an allowed image extension (case-insensitive), else null.
String? notificationImageMime(String ext) => switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };

/// A single content block inside an [AppNotification]. Either rendered markdown
/// text, or an interactive feedback widget (poll / free-text input).
sealed class NotificationBlock {
  /// Stable per-notification id. Markdown blocks also carry one for uniformity,
  /// but only poll/input ids appear as keys in a response's `answers` map.
  final String id;
  const NotificationBlock(this.id);

  Map<String, dynamic> toJson();

  static NotificationBlock fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    switch (json['type']) {
      case 'poll':
        return PollBlock(
          id: id,
          question: (json['question'] ?? '').toString(),
          options: ((json['options'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          multiple: json['multiple'] == true,
        );
      case 'input':
        return InputBlock(
          id: id,
          prompt: (json['prompt'] ?? '').toString(),
          multiline: json['multiline'] != false, // default true
        );
      case 'image':
        final link = (json['link'] ?? '').toString();
        return ImageBlock(
          id: id,
          url: (json['url'] ?? '').toString(),
          path: (json['path'] ?? '').toString(),
          link: link.isEmpty ? null : link,
          banner: json['banner'] == true,
        );
      case 'markdown':
      default:
        return MarkdownBlock(id: id, text: (json['text'] ?? '').toString());
    }
  }
}

class MarkdownBlock extends NotificationBlock {
  final String text;
  const MarkdownBlock({required String id, required this.text}) : super(id);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': 'markdown', 'text': text};
}

class PollBlock extends NotificationBlock {
  final String question;
  final List<String> options;
  final bool multiple;
  const PollBlock({
    required String id,
    required this.question,
    required this.options,
    this.multiple = false,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'poll',
        'question': question,
        'options': options,
        'multiple': multiple,
      };
}

class InputBlock extends NotificationBlock {
  final String prompt;
  final bool multiline;
  const InputBlock({
    required String id,
    required this.prompt,
    this.multiline = true,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'input',
        'prompt': prompt,
        'multiline': multiline,
      };
}

/// An uploaded image (`notification-images` bucket). `path` is the storage
/// object key, kept so deleting the notification can remove the file. The
/// block flagged [banner] sits first in the list and is drawn above the body.
class ImageBlock extends NotificationBlock {
  final String url;
  final String path;
  final String? link;
  final bool banner;
  const ImageBlock({
    required String id,
    required this.url,
    required this.path,
    this.link,
    this.banner = false,
  }) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'image',
        'url': url,
        'path': path,
        if (link != null) 'link': link,
        if (banner) 'banner': true,
      };
}

/// A broadcast notification as seen by an end user: title + ordered blocks,
/// plus the caller's own prior answers and read state (hydrated by the
/// `list_notifications` RPC).
class AppNotification {
  final String id;
  final String title;
  final List<NotificationBlock> blocks;
  final DateTime createdAt;

  /// block-id → answer map (`{"choice":[0]}` or `{"text":"..."}`), or null if
  /// the user has not responded yet.
  final Map<String, dynamic>? myAnswers;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.blocks,
    required this.createdAt,
    this.myAnswers,
    this.read = false,
  });

  /// True when any block is interactive (poll/input) — i.e. expects a response.
  bool get hasInteractive =>
      blocks.any((b) => b is PollBlock || b is InputBlock);

  /// The banner image, when the first block is one flagged `banner`.
  ImageBlock? get banner => switch (blocks.firstOrNull) {
        final ImageBlock b when b.banner => b,
        _ => null,
      };

  /// Blocks drawn in the body — everything except the banner.
  List<NotificationBlock> get bodyBlocks =>
      banner == null ? blocks : blocks.sublist(1);

  static List<NotificationBlock> parseBlocks(dynamic raw) {
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => NotificationBlock.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw == null) return null;
    final v = raw is String ? jsonDecode(raw) : raw;
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'].toString(),
      title: (row['title'] ?? '').toString(),
      blocks: parseBlocks(row['blocks']),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      myAnswers: _asMap(row['my_answers']),
      read: row['read'] == true,
    );
  }
}
