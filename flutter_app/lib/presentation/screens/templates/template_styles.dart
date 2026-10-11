import 'package:flutter/material.dart';

import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/template_edit.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// What is being dragged onto the layout: an existing field or a palette
/// style (a new field).
class TemplateDrag {
  const TemplateDrag.field(String this.fieldId) : type = null;
  const TemplateDrag.style(FieldType this.type) : fieldId = null;

  final String? fieldId;
  final FieldType? type;
}

String styleLabel(L10n l10n, FieldType t) => switch (t) {
  FieldType.text => l10n.tplStyleText,
  FieldType.textarea => l10n.tplStyleTextarea,
  FieldType.markdown => l10n.tplStyleMarkdown,
  FieldType.integer => l10n.tplStyleInteger,
  FieldType.float_ => l10n.tplStyleFloat,
  FieldType.boolean_ => l10n.tplStyleBoolean,
  FieldType.enum_ => l10n.tplStyleEnum,
  FieldType.date => l10n.tplStyleDate,
  FieldType.tagList => l10n.tplStyleTags,
  FieldType.dice => l10n.tplStyleDice,
  FieldType.image => l10n.tplStyleImage,
  FieldType.imagePerEra => l10n.tplStyleImagePerEra,
  FieldType.file => l10n.tplStyleFile,
  FieldType.relation => l10n.tplStyleRelation,
  // Kept SRD types show their code name next to the "SRD type" badge.
  _ => t.name,
};

String styleHint(L10n l10n, FieldType t) => switch (t) {
  FieldType.text => l10n.tplStyleTextHint,
  FieldType.textarea => l10n.tplStyleTextareaHint,
  FieldType.markdown => l10n.tplStyleMarkdownHint,
  FieldType.integer => l10n.tplStyleIntegerHint,
  FieldType.float_ => l10n.tplStyleFloatHint,
  FieldType.boolean_ => l10n.tplStyleBooleanHint,
  FieldType.enum_ => l10n.tplStyleEnumHint,
  FieldType.date => l10n.tplStyleDateHint,
  FieldType.tagList => l10n.tplStyleTagsHint,
  FieldType.dice => l10n.tplStyleDiceHint,
  FieldType.image => l10n.tplStyleImageHint,
  FieldType.imagePerEra => l10n.tplStyleImagePerEraHint,
  FieldType.file => l10n.tplStyleFileHint,
  FieldType.relation => l10n.tplStyleRelationHint,
  _ => l10n.tplLegacyHint,
};

IconData styleIcon(FieldType t) => switch (t) {
  FieldType.text => Icons.short_text,
  FieldType.textarea => Icons.notes,
  FieldType.markdown => Icons.article_outlined,
  FieldType.integer => Icons.pin_outlined,
  FieldType.float_ => Icons.numbers,
  FieldType.boolean_ => Icons.check_box_outlined,
  FieldType.enum_ => Icons.arrow_drop_down_circle_outlined,
  FieldType.date => Icons.event_outlined,
  FieldType.tagList => Icons.sell_outlined,
  FieldType.dice => Icons.casino_outlined,
  FieldType.image => Icons.image_outlined,
  FieldType.imagePerEra => Icons.collections_outlined,
  FieldType.file => Icons.attach_file,
  FieldType.relation => Icons.link,
  _ => Icons.extension_outlined,
};

/// Desktop palette strip under the three panels (DESIGN §7.5): click adds to
/// the selected group, drag drops anywhere on the layout.
class TemplatePaletteStrip extends StatelessWidget {
  const TemplatePaletteStrip({super.key, required this.onAdd});

  final ValueChanged<FieldType> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(top: BorderSide(color: palette.featureCardBorder)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Tooltip(
              message: l10n.tplPaletteHint,
              child: Text(
                l10n.btnAdd.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: simpleFieldTypes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final t = simpleFieldTypes[i];
                Widget button({VoidCallback? onTap}) => _PaletteButton(
                  icon: styleIcon(t),
                  label: styleLabel(l10n, t),
                  palette: palette,
                  onTap: onTap,
                );
                return Center(
                  child: Tooltip(
                    message: styleHint(l10n, t),
                    // Vertical affinity: a sideways drag still scrolls the
                    // strip on touch screens.
                    child: Draggable<TemplateDrag>(
                      data: TemplateDrag.style(t),
                      affinity: Axis.vertical,
                      feedback: Material(
                        color: Colors.transparent,
                        child: button(),
                      ),
                      child: button(onTap: () => onAdd(t)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({
    required this.icon,
    required this.label,
    required this.palette,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final DmToolColors palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: palette.br,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.tabText),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: palette.tabText)),
        ],
      ),
    ),
  );
}

/// The app's pill selector (as in `PillTabBar`): one framed row, the chosen
/// segment filled with the accent.
class TemplatePills<T> extends StatelessWidget {
  const TemplatePills({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String, IconData?)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label, icon) in items)
            Semantics(
              button: true,
              selected: v == value,
              child: InkWell(
                borderRadius: palette.br,
                onTap: () => onChanged(v),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: v == value
                        ? palette.featureCardAccent
                        : Colors.transparent,
                    borderRadius: palette.br,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 15,
                          color: v == value
                              ? Colors.white
                              : palette.sidebarLabelSecondary,
                        ),
                        if (label.isNotEmpty) const SizedBox(width: 6),
                      ],
                      if (label.isNotEmpty)
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: v == value
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: v == value ? Colors.white : palette.tabText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A category's colour, as the codex sidebar draws it.
class TemplateColorDot extends StatelessWidget {
  const TemplateColorDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Small count / note pill ("2 col", "8").
class TemplatePill extends StatelessWidget {
  const TemplatePill(this.text, {super.key, this.tooltip});

  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.sidebarFilterBg,
        borderRadius: palette.br,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: palette.tabText),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}

/// Phone "+ Add" sheet (DESIGN §7.6): one tap picks a style.
Future<FieldType?> showStylePickerSheet(BuildContext context) {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  return showModalBottomSheet<FieldType>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.tplAddField,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
          ),
          for (final t in simpleFieldTypes)
            ListTile(
              leading: Icon(styleIcon(t), size: 20, color: palette.tabText),
              title: Text(
                styleLabel(l10n, t),
                style: TextStyle(fontSize: 13, color: palette.tabActiveText),
              ),
              subtitle: Text(
                styleHint(l10n, t),
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    ),
  );
}
