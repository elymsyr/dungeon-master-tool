import 'package:flutter/material.dart';

import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/template_edit.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// What is being dragged onto the layout (or picked to add): an existing
/// field, a palette style (a new field) or a preset (a new bound field).
class TemplateDrag {
  const TemplateDrag.field(String this.fieldId) : type = null, presetId = null;
  const TemplateDrag.style(FieldType this.type)
    : fieldId = null,
      presetId = null;
  const TemplateDrag.preset(String this.presetId)
    : fieldId = null,
      type = null;

  final String? fieldId;
  final FieldType? type;
  final String? presetId;
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
  FieldType.table => l10n.tplStyleTable,
  FieldType.statTable => l10n.tplStyleStatTable,
  FieldType.skillTable => l10n.tplStyleSkillTable,
  FieldType.resource => l10n.tplStyleResource,
  FieldType.combatStats => l10n.tplStyleCombatStats,
  FieldType.characterLevel => l10n.tplStyleLevel,
  FieldType.autoResources => l10n.tplStylePool,
  FieldType.grantHolder => l10n.tplStyleGrants,
  FieldType.progressionTable => l10n.tplStyleLevelTable,
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
  FieldType.table => l10n.tplStyleTableHint,
  FieldType.statTable => l10n.tplStyleStatTableHint,
  FieldType.skillTable => l10n.tplStyleSkillTableHint,
  FieldType.resource => l10n.tplStyleResourceHint,
  FieldType.combatStats => l10n.tplStyleCombatStatsHint,
  FieldType.characterLevel => l10n.tplStyleLevelHint,
  FieldType.autoResources => l10n.tplStylePoolHint,
  FieldType.grantHolder => l10n.tplStyleGrantsHint,
  FieldType.progressionTable => l10n.tplStyleLevelTableHint,
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
  FieldType.table => Icons.table_chart_outlined,
  FieldType.statTable => Icons.leaderboard_outlined,
  FieldType.skillTable => Icons.checklist,
  FieldType.resource => Icons.battery_5_bar_outlined,
  FieldType.combatStats => Icons.shield_outlined,
  FieldType.characterLevel => Icons.trending_up,
  FieldType.autoResources => Icons.auto_awesome_outlined,
  FieldType.grantHolder => Icons.card_giftcard_outlined,
  FieldType.progressionTable => Icons.stairs_outlined,
  _ => Icons.extension_outlined,
};

/// Desktop palette strip under the three panels (DESIGN §7.5): styles, then
/// the template's presets. Click adds to the selected group, drag drops
/// anywhere on the layout.
class TemplatePaletteStrip extends StatelessWidget {
  const TemplatePaletteStrip({
    super.key,
    required this.onAdd,
    this.presets = const [],
  });

  final ValueChanged<TemplateDrag> onAdd;
  final List<FieldSchema> presets;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    Widget item(TemplateDrag d, IconData icon, String label, String tip) {
      Widget button({VoidCallback? onTap}) => _PaletteButton(
        icon: icon,
        label: label,
        palette: palette,
        onTap: onTap,
      );
      return Center(
        child: Tooltip(
          message: tip,
          // Vertical affinity: a sideways drag still scrolls the strip on
          // touch screens.
          child: Draggable<TemplateDrag>(
            data: d,
            affinity: Axis.vertical,
            feedback: Material(color: Colors.transparent, child: button()),
            child: button(onTap: () => onAdd(d)),
          ),
        ),
      );
    }

    Widget section(String title) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: palette.sidebarLabelSecondary,
          ),
        ),
      ),
    );

    final items = [
      for (final t in paletteFieldTypes)
        item(
          TemplateDrag.style(t),
          styleIcon(t),
          styleLabel(l10n, t),
          styleHint(l10n, t),
        ),
      if (presets.isNotEmpty) section(l10n.tplPresets),
      for (final p in presets)
        item(
          TemplateDrag.preset(p.fieldId),
          Icons.bookmark_outline,
          p.label,
          '${styleLabel(l10n, p.fieldType)} · ${l10n.tplPresetHint}',
        ),
    ];
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
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => items[i],
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

/// The "+ Add" sheet (DESIGN §7.6): one tap picks a style or one of
/// [presets], each under its own heading.
Future<TemplateDrag?> showStylePickerSheet(
  BuildContext context, {
  List<FieldSchema> presets = const [],
}) {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: palette.tabActiveText,
      ),
    ),
  );
  Widget tile(TemplateDrag d, IconData icon, String title, String hint) =>
      Builder(
        builder: (context) => ListTile(
          leading: Icon(icon, size: 20, color: palette.tabText),
          title: Text(
            title,
            style: TextStyle(fontSize: 13, color: palette.tabActiveText),
          ),
          subtitle: Text(
            hint,
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          onTap: () => Navigator.pop(context, d),
        ),
      );
  return showModalBottomSheet<TemplateDrag>(
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
          if (presets.isNotEmpty) ...[
            heading(l10n.tplPresets),
            for (final p in presets)
              tile(
                TemplateDrag.preset(p.fieldId),
                Icons.bookmark_outline,
                p.label,
                '${styleLabel(l10n, p.fieldType)} · ${l10n.tplPresetHint}',
              ),
          ],
          heading(l10n.tplAddField),
          for (final t in paletteFieldTypes)
            tile(
              TemplateDrag.style(t),
              styleIcon(t),
              styleLabel(l10n, t),
              styleHint(l10n, t),
            ),
        ],
      ),
    ),
  );
}
