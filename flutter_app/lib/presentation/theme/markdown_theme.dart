import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'dm_tool_colors.dart';

/// flutter_markdown hardcodes a light `Colors.blue.shade100` blockquote
/// background, which glares in dark mode. Recolor it from the palette.
extension DmMarkdownBlockquote on MarkdownStyleSheet {
  MarkdownStyleSheet withDmBlockquote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<DmToolColors>();
    return copyWith(
      blockquoteDecoration: BoxDecoration(
        color: palette?.htmlCodeBg ?? scheme.surfaceContainerHighest,
        borderRadius: palette?.cbr ?? BorderRadius.circular(4),
      ),
    );
  }
}

/// Theme-derived markdown stylesheet with palette-aware blockquotes.
MarkdownStyleSheet dmMarkdownStyle(BuildContext context) =>
    MarkdownStyleSheet.fromTheme(Theme.of(context)).withDmBlockquote(context);
