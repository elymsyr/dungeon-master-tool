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

  const CardShell({
    required this.title,
    required this.categoryColor,
    this.subtitle,
    this.tags = const [],
    this.children = const [],
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: palette.tabActiveBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            palette: palette,
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  palette.padLg, 0, palette.padLg, palette.padSm),
              child: Wrap(
                spacing: palette.gap6,
                runSpacing: palette.gap6,
                children: tags,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(palette.padLg, palette.padSm,
                  palette.padLg, palette.padLg),
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
  final DmToolColors palette;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          palette.padLg, palette.padMd, palette.padLg, palette.padSm),
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
                    padding: EdgeInsets.only(top: palette.gap2),
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
      padding: EdgeInsets.symmetric(
          horizontal: palette.padSm, vertical: palette.gap2 + 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(palette.radiusXl),
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
      padding: EdgeInsets.only(top: palette.gap12),
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
          SizedBox(height: palette.gap4),
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
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: palette.gap2),
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

/// Label + editable/read-only child pair, laid out as `LABEL` over the
/// field on narrow grids. Used by [CardFieldGrid] to build a stat-block
/// style grouping.
class CardField extends StatelessWidget {
  final String label;
  final Widget child;

  const CardField({required this.label, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: palette.sidebarLabelSecondary,
          ),
        ),
        SizedBox(height: palette.gap2),
        child,
      ],
    );
  }
}

/// Responsive N-column grid of [CardField]s. Flows to 1 column on narrow
/// surfaces, [columns] on wider ones. Rows wrap automatically.
class CardFieldGrid extends StatelessWidget {
  final List<CardField> fields;
  final int columns;
  final double? spacing;

  const CardFieldGrid({
    required this.fields,
    this.columns = 2,
    this.spacing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final gap = spacing ?? palette.gap12;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 420 ? 1 : columns;
      final cellWidth = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap * 0.6,
        children: [
          for (final f in fields)
            SizedBox(width: cellWidth, child: f),
        ],
      );
    });
  }
}

/// Titled group of fields — paper look + soft divider. Wrap one or more
/// [CardFieldGrid]s / plain widgets as [children] to build a stat block
/// section (e.g. "COMBAT", "ABILITIES").
class CardFieldGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CardFieldGroup(
      {required this.title, required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: EdgeInsets.only(top: palette.gap12 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              SizedBox(width: palette.gap8),
              Expanded(
                child: Container(
                  height: 1,
                  color: palette.sidebarDivider,
                ),
              ),
            ],
          ),
          SizedBox(height: palette.gap8),
          ...children,
        ],
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
      padding: EdgeInsets.all(palette.gap32),
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
