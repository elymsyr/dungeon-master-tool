import 'package:flutter/material.dart';

import '../../../../core/utils/screen_type.dart';
import '../../../../domain/entities/schema/field_schema.dart';
import '../../../theme/dm_tool_colors.dart';
import 'field_type_meta.dart';

/// The field types a creator can *add* to a category, grouped into sections
/// (master-roadmap §2.1). Legacy v2 aliases (`statBlock`, `slot`, `spellSlotGrid`,
/// `proficiencyTable`, the bespoke effect lists, …) are intentionally excluded —
/// they exist only so existing content keeps parsing; new fields are authored
/// with the canonical v3 types.
const List<(String, List<FieldType>)> kCreatableFieldTypeSections = [
  (
    'Basic',
    [
      FieldType.text,
      FieldType.textarea,
      FieldType.markdown,
      FieldType.integer,
      FieldType.float_,
      FieldType.boolean_,
      FieldType.enum_,
      FieldType.date,
      FieldType.dice,
      FieldType.tagList,
    ],
  ),
  (
    'Media',
    [
      FieldType.image,
      FieldType.imagePerEra,
      FieldType.file,
      FieldType.pdf,
    ],
  ),
  (
    'Relations & records',
    [
      FieldType.relation,
      FieldType.recordList,
    ],
  ),
  (
    'Resources',
    [
      FieldType.intPouch,
      FieldType.checkboxPouch,
      FieldType.pouchMatrix,
    ],
  ),
  (
    'Tables',
    [
      FieldType.abilityScoreTable,
      FieldType.combatStatsTable,
      FieldType.skillTree,
      FieldType.levelMatrix,
      FieldType.levelTable,
      FieldType.levelTextTable,
      FieldType.levelUpTable,
    ],
  ),
  (
    'Actions & tools',
    [
      FieldType.actionButton,
      FieldType.crCalculator,
    ],
  ),
];

/// Opens the responsive field-type picker — a scrollable bottom sheet on touch
/// platforms, a centered dialog on desktop/pointer (roadmap §1.5). Resolves to
/// the chosen [FieldType], or `null` if cancelled.
Future<FieldType?> showFieldTypePicker(BuildContext context) {
  const picker = _FieldTypePicker();
  if (isTouchPlatform) {
    return showModalBottomSheet<FieldType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: picker,
      ),
    );
  }
  return showDialog<FieldType>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
        child: picker,
      ),
    ),
  );
}

class _FieldTypePicker extends StatelessWidget {
  const _FieldTypePicker();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Add field',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: palette.tabActiveText,
            ),
          ),
        ),
        Divider(height: 1, color: palette.featureCardBorder),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              for (final section in kCreatableFieldTypeSections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(
                    section.$1.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    // One column on narrow phones, two when there's room.
                    final twoUp = constraints.maxWidth >= 440;
                    final tileWidth = twoUp
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final type in section.$2)
                          SizedBox(
                            width: tileWidth,
                            child: _TypeCard(
                              type: type,
                              palette: palette,
                              onTap: () => Navigator.of(context).pop(type),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final FieldType type;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = FieldTypeMeta.of(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          border: Border.all(color: palette.featureCardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(meta.icon, size: 22, color: palette.featureCardAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText,
                          ),
                        ),
                      ),
                      if (meta.ruleCapable) ...[
                        const SizedBox(width: 6),
                        _RuleCapableBadge(palette: palette),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCapableBadge extends StatelessWidget {
  final DmToolColors palette;

  const _RuleCapableBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'rules',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: palette.featureCardAccent,
        ),
      ),
    );
  }
}
