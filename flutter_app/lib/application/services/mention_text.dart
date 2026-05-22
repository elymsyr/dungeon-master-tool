/// Entity-mention helpers for plain-text surfaces.
///
/// Mentions are stored in description / text / markdown fields as
/// `@[Name](entity:id)` markdown links (see `markdown_text_area.dart`). A
/// markdown renderer strips the leading `@` and shows the link; but plain
/// `Text` surfaces (the projection entity-card view, the projection
/// `EntitySnapshot`) have no renderer — they would show the raw markdown.
///
/// [stripMentions] collapses every mention (with or without the `@` prefix)
/// down to just its display name so plain-text views stay readable.
final RegExp _mentionRe = RegExp(r'@?\[([^\]]+)\]\(entity:[^)]+\)');

/// Replaces `@[Name](entity:id)` / `[Name](entity:id)` with `Name`.
String stripMentions(String text) {
  if (text.isEmpty || !text.contains('](entity:')) return text;
  return text.replaceAllMapped(_mentionRe, (m) => m[1]!);
}
