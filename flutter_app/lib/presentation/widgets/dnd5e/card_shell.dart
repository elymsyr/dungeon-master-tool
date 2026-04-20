import 'package:flutter/material.dart';

import '../../theme/dm_tool_colors.dart';

/// Shared chrome for typed cards. Matches the legacy `EntityCard` visual:
/// category-colored left border, title + subtitle header, scrollable body.
/// Per-card widgets fill [children] and optionally [tags].
class CardShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color categoryColor;
  final List<Widget> tags;
  final List<Widget> children;
  final Widget? trailing;

  /// When set, renders a pencil icon button in the header that fires this
  /// callback. Typed cards hook it up to open an entity-specific editor
  /// dialog; leave null to suppress the affordance.
  final VoidCallback? onEdit;

  const CardShell({
    required this.title,
    required this.categoryColor,
    this.subtitle,
    this.tags = const [],
    this.children = const [],
    this.trailing,
    this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: palette.tabActiveBg,
        border: Border(
          left: BorderSide(color: categoryColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onEdit: onEdit,
            palette: palette,
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: tags),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onEdit;
  final DmToolColors palette;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onEdit,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.sidebarLabelSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small pill-shaped chip used in a card's tag row.
class CardTag extends StatelessWidget {
  final String label;
  final Color? color;

  const CardTag(this.label, {this.color, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final bg = color ?? palette.tabBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.sidebarDivider),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Section header rendered inside a card body.
class CardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const CardSection({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Simple label/value row — e.g. `Casting Time: 1 action`.
class CardKeyValue extends StatelessWidget {
  final String label;
  final String value;

  const CardKeyValue(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Shown while a typed row streams in / when the row is missing. Keeps the
/// card region filled so pane layout doesn't jump.
class CardPlaceholder extends StatelessWidget {
  final String message;

  const CardPlaceholder(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      color: palette.tabActiveBg,
      child: Text(
        message,
        style: TextStyle(
          color: palette.sidebarLabelSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
