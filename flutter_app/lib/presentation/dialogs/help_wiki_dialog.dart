import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/markdown_theme.dart';

/// One wiki page. Its text lives in `assets/help/<lang>/<id>.md`; the
/// first `# ` line of the file is the title shown in the contents list.
class HelpTopic {
  const HelpTopic(this.id, [this.children = const []]);
  final String id;
  final List<HelpTopic> children;
}

/// Contents tree of the help wiki. Pages link to each other with
/// `[text](help:<id>)`.
const helpTopics = <HelpTopic>[
  HelpTopic('start', [
    HelpTopic('concepts'),
    HelpTopic('quick-start'),
    HelpTopic('saving'),
    HelpTopic('accounts'),
  ]),
  HelpTopic('worlds', [
    HelpTopic('codex'),
    HelpTopic('session'),
    HelpTopic('battle-map'),
    HelpTopic('world-map'),
    HelpTopic('mind-map'),
    HelpTopic('pdf-soundpad'),
    HelpTopic('projection'),
    HelpTopic('online-play'),
  ]),
  HelpTopic('characters'),
  HelpTopic('templates', [
    HelpTopic('template-editor'),
    HelpTopic('free-sheet'),
  ]),
  HelpTopic('packages'),
  HelpTopic('social', [
    HelpTopic('feed'),
    HelpTopic('messages'),
    HelpTopic('game-listings'),
    HelpTopic('marketplace'),
  ]),
  HelpTopic('settings'),
];

final _flatTopics = <(HelpTopic, int)>[
  for (final t in helpTopics) ...[
    (t, 0),
    for (final c in t.children) (c, 1),
  ],
];

Future<String> _loadPage(String lang, String id) async {
  try {
    return await rootBundle.loadString('assets/help/$lang/$id.md');
  } catch (_) {
    // Only en and tr are written; other languages fall back to English.
    return rootBundle.loadString('assets/help/en/$id.md');
  }
}

String _titleOf(String markdown, String fallback) {
  for (final line in markdown.split('\n')) {
    if (line.startsWith('# ')) return line.substring(2).trim();
  }
  return fallback;
}

/// Help wiki: contents tree on the left, the selected page on the right
/// (on a narrow screen one at a time). Opens at [initialPage].
class HelpWikiDialog extends StatefulWidget {
  const HelpWikiDialog({super.key, required this.initialPage});

  final String initialPage;

  static Future<void> show(BuildContext context, String page) =>
      showDialog<void>(
        context: context,
        builder: (_) => HelpWikiDialog(initialPage: page),
      );

  @override
  State<HelpWikiDialog> createState() => _HelpWikiDialogState();
}

class _HelpWikiDialogState extends State<HelpWikiDialog> {
  Future<Map<String, String>>? _pages;
  late String _current = widget.initialPage;
  final _history = <String>[];
  bool _showContents = false; // narrow layout only

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    _pages ??= Future.wait([
      for (final (t, _) in _flatTopics) _loadPage(lang, t.id),
    ]).then((texts) => {
          for (var i = 0; i < texts.length; i++) _flatTopics[i].$1.id: texts[i],
        });
  }

  void _open(String id) {
    setState(() {
      if (id != _current) _history.add(_current);
      _current = id;
      _showContents = false;
    });
  }

  void _back() => setState(() {
        _current = _history.removeLast();
        _showContents = false;
      });

  Future<void> _onLink(String? href) async {
    if (href == null) return;
    if (href.startsWith('help:')) {
      final id = href.substring(5);
      if (_flatTopics.any((e) => e.$1.id == id)) _open(id);
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: SizedBox.expand(
          child: FutureBuilder<Map<String, String>>(
            future: _pages,
            builder: (context, snap) {
              final pages = snap.data;
              if (pages == null) {
                return Center(
                  child: snap.hasError
                      ? Text('${snap.error}')
                      : const CircularProgressIndicator(),
                );
              }
              return LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 640;
                final page = _page(pages[_current] ?? '');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(l10n, wide),
                    const Divider(height: 1),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 250, child: _contents(pages)),
                                const VerticalDivider(width: 1),
                                Expanded(child: page),
                              ],
                            )
                          : _showContents
                              ? _contents(pages)
                              : page,
                    ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _header(L10n l10n, bool wide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (!wide)
            IconButton(
              tooltip: l10n.helpWikiContents,
              isSelected: _showContents,
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () => setState(() => _showContents = !_showContents),
            ),
          IconButton(
            tooltip: l10n.btnBack,
            icon: const Icon(Icons.arrow_back),
            onPressed: _history.isEmpty ? null : _back,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.help_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.helpWikiTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l10n.btnClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _contents(Map<String, String> pages) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (t, depth) in _flatTopics)
          ListTile(
            dense: true,
            selected: t.id == _current,
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 8),
            title: Text(
              _titleOf(pages[t.id] ?? '', t.id),
              style: depth == 0
                  ? const TextStyle(fontWeight: FontWeight.w600)
                  : null,
            ),
            onTap: () => _open(t.id),
          ),
      ],
    );
  }

  Widget _page(String markdown) {
    return SingleChildScrollView(
      // New key per page so a link always lands at the top.
      key: ValueKey(_current),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: MarkdownBody(
        data: markdown,
        styleSheet: dmMarkdownStyle(context),
        onTapLink: (_, href, _) => _onLink(href),
      ),
    );
  }
}
