import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../theme/markdown_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../../domain/entities/app_notification.dart';

/// Shared markdown styling for notification bodies, derived from the palette.
MarkdownStyleSheet notificationMarkdownStyle(DmToolColors palette) {
  return MarkdownStyleSheet(
    p: TextStyle(fontSize: 13, height: 1.45, color: palette.htmlText),
    h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.htmlHeader),
    h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.htmlHeader),
    h3: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.htmlHeader),
    code: TextStyle(fontSize: 12, backgroundColor: palette.htmlCodeBg),
    a: TextStyle(color: palette.htmlLink),
    listBullet: TextStyle(fontSize: 13, color: palette.htmlText),
  );
}

/// Read-only markdown block.
class MarkdownBlockView extends StatelessWidget {
  final MarkdownBlock block;
  const MarkdownBlockView({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    if (block.text.trim().isEmpty) return const SizedBox.shrink();
    return MarkdownBody(
      data: block.text,
      selectable: false,
      styleSheet: notificationMarkdownStyle(palette).withDmBlockquote(context),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

/// Image block (also the banner), full width at its natural aspect ratio (or a
/// fixed cropped [height]). An uncapped banner is capped to a square: landscape
/// shows whole, portrait is cropped.
/// [onTap], when set, wins over the link (inbox card opens the notification);
/// otherwise a linked image opens its link externally, an unlinked one is inert.
class ImageBlockView extends StatelessWidget {
  final ImageBlock block;
  final BorderRadius? radius;
  final VoidCallback? onTap;

  /// Fixed height, cropped to fill (inbox list strip). Null = natural size.
  final double? height;

  const ImageBlockView({
    super.key,
    required this.block,
    this.radius,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    Widget image = Image.network(
      block.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: height,
      errorBuilder: (context, _, _) => Container(
        height: height ?? 72,
        color: palette.htmlCodeBg,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 18, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 6),
            Text(
              L10n.of(context)!.notifImageLoadFailed,
              style: TextStyle(
                  fontSize: 12, color: palette.sidebarLabelSecondary),
            ),
          ],
        ),
      ),
    );
    if (block.banner && height == null) {
      final inner = image;
      image = LayoutBuilder(
        builder: (context, c) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: c.maxWidth),
          child: inner,
        ),
      );
    }
    if (radius != null) {
      image = ClipRRect(borderRadius: radius!, child: image);
    }
    final link = block.link;
    final tap = onTap ??
        (link == null
            ? null
            : () => launchUrl(Uri.parse(link),
                mode: LaunchMode.externalApplication));
    if (tap == null) return image;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: tap, child: image),
    );
  }
}

/// Poll block — single (radio) or multiple (checkbox) choice + submit.
/// A null [onSubmit] (guest) shows the poll locked with a sign-in hint.
class PollBlockView extends StatefulWidget {
  final PollBlock block;
  final List<int> initial;
  final Future<void> Function(List<int> choice)? onSubmit;

  const PollBlockView({
    super.key,
    required this.block,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<PollBlockView> createState() => _PollBlockViewState();
}

class _PollBlockViewState extends State<PollBlockView> {
  late Set<int> _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.toSet();
  }

  @override
  void didUpdateWidget(PollBlockView old) {
    super.didUpdateWidget(old);
    if (!_busy && old.initial != widget.initial) {
      _selected = widget.initial.toSet();
    }
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final choice = _selected.toList()..sort();
      await widget.onSubmit!(choice);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final answered = widget.initial.isNotEmpty;
    final locked = widget.onSubmit == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.block.question.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(widget.block.question,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText)),
          ),
        if (widget.block.multiple)
          for (int i = 0; i < widget.block.options.length; i++)
            CheckboxListTile(
              value: _selected.contains(i),
              onChanged: _busy || locked
                  ? null
                  : (v) => setState(() =>
                      v == true ? _selected.add(i) : _selected.remove(i)),
              title: Text(widget.block.options[i],
                  style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            )
        else
          RadioGroup<int>(
            groupValue: _selected.isEmpty ? null : _selected.first,
            onChanged: (v) {
              if (_busy || locked) return;
              setState(() => _selected = v == null ? {} : {v});
            },
            child: Column(
              children: [
                for (int i = 0; i < widget.block.options.length; i++)
                  RadioListTile<int>(
                    value: i,
                    enabled: !locked,
                    title: Text(widget.block.options[i],
                        style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: locked
              ? _SignInHint(l10n.notifSignInToAnswer)
              : TextButton(
            onPressed: (_busy || _selected.isEmpty) ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(answered ? l10n.notifUpdate : l10n.notifSubmit),
          ),
        ),
      ],
    );
  }
}

/// Free-text input block + submit. A null [onSubmit] (guest) locks it.
class InputBlockView extends StatefulWidget {
  final InputBlock block;
  final String initial;
  final Future<void> Function(String text)? onSubmit;

  const InputBlockView({
    super.key,
    required this.block,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<InputBlockView> createState() => _InputBlockViewState();
}

class _InputBlockViewState extends State<InputBlockView> {
  late final TextEditingController _ctrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit!(text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final answered = widget.initial.isNotEmpty;
    final locked = widget.onSubmit == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.block.prompt.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(widget.block.prompt,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText)),
          ),
        TextField(
          controller: _ctrl,
          enabled: !_busy && !locked,
          minLines: widget.block.multiline ? 2 : 1,
          maxLines: widget.block.multiline ? 5 : 1,
          style: TextStyle(fontSize: 13, color: palette.tabActiveText),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.notifInputHint,
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: locked
              ? _SignInHint(l10n.notifSignInToAnswer)
              : TextButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(answered ? l10n.notifUpdate : l10n.notifSubmit),
          ),
        ),
      ],
    );
  }
}

/// Stands in for the submit button when a guest can see but not answer.
class _SignInHint extends StatelessWidget {
  final String text;
  const _SignInHint(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
        ],
      ),
    );
  }
}
