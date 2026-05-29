import 'dart:convert';

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
