import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A description block that collapses to a short plain-text preview and, on
/// "Show more", expands into a **fixed-height scrollable box at the same font
/// size** — markdown headings are flattened to body size so the text never
/// jumps larger, it just becomes scrollable.
///
/// Collapsed renders a plain-text preview (markdown stripped) so a long
/// packaged description shrinks to [collapsedMaxLines] and a raw `### Heading`
/// never leaks through as literal `#` characters. The toggle only appears when
/// the content is actually long.
class ExpandableMarkdown extends StatefulWidget {
  final String data;
  final int collapsedMaxLines;
  final double expandedMaxHeight;
  final MarkdownStyleSheet? styleSheet;

  /// Style for the collapsed plain-text preview *and* the baseline font size
  /// the expanded view is normalized to. Falls back to the [styleSheet]'s
  /// paragraph style, then the ambient body style.
  final TextStyle? collapsedTextStyle;

  const ExpandableMarkdown({
    super.key,
    required this.data,
    this.collapsedMaxLines = 2,
    this.expandedMaxHeight = 160,
    this.styleSheet,
    this.collapsedTextStyle,
  });

  @override
  State<ExpandableMarkdown> createState() => _ExpandableMarkdownState();
}

class _ExpandableMarkdownState extends State<ExpandableMarkdown> {
  bool _expanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Worth a toggle only when the content spans multiple lines or is long
  /// enough that a 2-line preview would clip.
  bool get _isLong =>
      widget.data.contains('\n') || widget.data.trim().length > 120;

  @override
  Widget build(BuildContext context) {
    final data = widget.data.trim();
    if (data.isEmpty) return const SizedBox.shrink();

    final base = widget.collapsedTextStyle ??
        widget.styleSheet?.p ??
        Theme.of(context).textTheme.bodyMedium;

    if (!_isLong) {
      // Short: plain text at the base size, no toggle, no markdown blow-up.
      return Text(_stripMarkdown(data), style: base);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_expanded)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.expandedMaxHeight),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                child: MarkdownBody(
                  data: data,
                  styleSheet: _flattenedSheet(context, base),
                ),
              ),
            ),
          )
        else
          Text(
            _stripMarkdown(data),
            maxLines: widget.collapsedMaxLines,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Markdown stylesheet whose paragraph **and every heading** share [base]'s
  /// font size, so expanding never enlarges the text — headings only keep
  /// their bold weight. Tight block spacing keeps the scroll box compact.
  MarkdownStyleSheet _flattenedSheet(BuildContext context, TextStyle? base) {
    final heading = (base ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
    );
    final sheet =
        widget.styleSheet ?? MarkdownStyleSheet.fromTheme(Theme.of(context));
    return sheet.copyWith(
      p: base,
      h1: heading,
      h2: heading,
      h3: heading,
      h4: heading,
      h5: heading,
      h6: heading,
      blockSpacing: 6,
    );
  }

  /// Collapse markdown to a readable single-flow preview: drop heading hashes,
  /// emphasis/code markers and blockquote/list bullets, unwrap links to their
  /// text, and squash blank lines so the ellipsis cuts on prose, not on `###`.
  static String _stripMarkdown(String md) {
    var s = md;
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ''); // images
    s = s.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? ''); // links
    s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'[*_`~]'), '');
    s = s.replaceAll(RegExp(r'\s*\n\s*'), ' ');
    return s.trim();
  }
}
