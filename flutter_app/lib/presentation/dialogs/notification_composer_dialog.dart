import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_notifications_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Mutable draft of one notification block while composing.
class _DraftBlock {
  final String id;
  final String type; // 'markdown' | 'poll' | 'input'
  final TextEditingController main = TextEditingController();
  final List<TextEditingController> options = [];
  bool multiple = false;
  bool multiline = true;

  _DraftBlock(this.id, this.type) {
    if (type == 'poll') {
      options.add(TextEditingController());
      options.add(TextEditingController());
    }
  }

  void dispose() {
    main.dispose();
    for (final c in options) {
      c.dispose();
    }
  }

  /// Serialize to the JSONB block shape, or null if incomplete.
  Map<String, dynamic>? toJson() {
    final m = main.text.trim();
    switch (type) {
      case 'poll':
        final opts =
            options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (m.isEmpty || opts.length < 2) return null;
        return {
          'id': id,
          'type': 'poll',
          'question': m,
          'options': opts,
          'multiple': multiple,
        };
      case 'input':
        if (m.isEmpty) return null;
        return {'id': id, 'type': 'input', 'prompt': m, 'multiline': multiline};
      case 'markdown':
      default:
        if (main.text.trim().isEmpty) return null;
        return {'id': id, 'type': 'markdown', 'text': main.text};
    }
  }
}

/// Admin composer: title + ordered blocks (markdown / poll / input) → publish.
class NotificationComposerDialog extends ConsumerStatefulWidget {
  const NotificationComposerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const NotificationComposerDialog(),
    );
  }

  @override
  ConsumerState<NotificationComposerDialog> createState() =>
      _NotificationComposerDialogState();
}

class _NotificationComposerDialogState
    extends ConsumerState<NotificationComposerDialog> {
  final _titleCtrl = TextEditingController();
  final List<_DraftBlock> _blocks = [];
  int _counter = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  void _add(String type) {
    setState(() {
      _counter++;
      _blocks.add(_DraftBlock('b$_counter', type));
    });
  }

  void _remove(int i) {
    setState(() => _blocks.removeAt(i).dispose());
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _blocks.length) return;
    setState(() {
      final b = _blocks.removeAt(i);
      _blocks.insert(j, b);
    });
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    final blocks = _blocks
        .map((b) => b.toJson())
        .where((m) => m != null)
        .cast<Map<String, dynamic>>()
        .toList();
    final l10n = L10n.of(context)!;
    if (title.isEmpty || blocks.isEmpty) {
      setState(() => _error = l10n.notifComposerEmpty);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ds = ref.read(adminNotificationsDataSourceProvider);
      await ds.create(title, blocks);
      ref.invalidate(adminNotificationsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.notifPublished)));
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.notifComposerTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.tabActiveText)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                enabled: !_busy,
                maxLength: 200,
                style: TextStyle(color: palette.tabActiveText),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.notifTitleLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _blocks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) => _BlockEditor(
                    key: ValueKey(_blocks[i].id),
                    draft: _blocks[i],
                    busy: _busy,
                    onRemove: () => _remove(i),
                    onUp: i > 0 ? () => _move(i, -1) : null,
                    onDown: i < _blocks.length - 1 ? () => _move(i, 1) : null,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _add('markdown'),
                    icon: const Icon(Icons.notes, size: 16),
                    label: Text(l10n.notifAddMarkdown),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _add('poll'),
                    icon: const Icon(Icons.poll_outlined, size: 16),
                    label: Text(l10n.notifAddPoll),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _add('input'),
                    icon: const Icon(Icons.short_text, size: 16),
                    label: Text(l10n.notifAddInput),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: palette.dangerBtnBg, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(l10n.btnClose),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _publish,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.notifPublish),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockEditor extends StatelessWidget {
  final _DraftBlock draft;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onChanged;

  const _BlockEditor({
    super.key,
    required this.draft,
    required this.busy,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
    required this.onChanged,
  });

  String _typeLabel(L10n l10n) => switch (draft.type) {
        'poll' => l10n.notifBlockPoll,
        'input' => l10n.notifBlockInput,
        _ => l10n.notifBlockMarkdown,
      };

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_typeLabel(l10n),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: palette.featureCardAccent)),
              const Spacer(),
              IconButton(
                tooltip: l10n.notifMoveUp,
                icon: const Icon(Icons.arrow_upward, size: 16),
                onPressed: busy ? null : onUp,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: l10n.notifMoveDown,
                icon: const Icon(Icons.arrow_downward, size: 16),
                onPressed: busy ? null : onDown,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: l10n.notifDelete,
                icon: Icon(Icons.delete_outline, size: 16, color: palette.dangerBtnBg),
                onPressed: busy ? null : onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // Main field: markdown text / poll question / input prompt
          TextField(
            controller: draft.main,
            enabled: !busy,
            minLines: draft.type == 'markdown' ? 3 : 1,
            maxLines: draft.type == 'markdown' ? 8 : 2,
            style: TextStyle(fontSize: 13, color: palette.tabActiveText),
            decoration: InputDecoration(
              isDense: true,
              hintText: switch (draft.type) {
                'poll' => l10n.notifPollQuestion,
                'input' => l10n.notifInputPrompt,
                _ => l10n.notifMarkdownHint,
              },
              border: const OutlineInputBorder(),
            ),
          ),
          if (draft.type == 'poll') ...[
            const SizedBox(height: 6),
            for (int i = 0; i < draft.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: draft.options[i],
                        enabled: !busy,
                        style: TextStyle(fontSize: 13, color: palette.tabActiveText),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '${l10n.notifPollOption} ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (draft.options.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: busy
                            ? null
                            : () {
                                draft.options.removeAt(i).dispose();
                                onChanged();
                              },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          draft.options.add(TextEditingController());
                          onChanged();
                        },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.notifAddOption),
                ),
                const Spacer(),
                Text(l10n.notifPollMultiple,
                    style: TextStyle(fontSize: 12, color: palette.tabText)),
                Switch(
                  value: draft.multiple,
                  onChanged: busy
                      ? null
                      : (v) {
                          draft.multiple = v;
                          onChanged();
                        },
                ),
              ],
            ),
          ],
          if (draft.type == 'input')
            Row(
              children: [
                const Spacer(),
                Text(l10n.notifInputMultiline,
                    style: TextStyle(fontSize: 12, color: palette.tabText)),
                Switch(
                  value: draft.multiline,
                  onChanged: busy
                      ? null
                      : (v) {
                          draft.multiline = v;
                          onChanged();
                        },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
