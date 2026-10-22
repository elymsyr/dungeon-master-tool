import 'package:flutter/material.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/free_encounter.dart';
import '../../../domain/services/free_field_styles.dart';
import '../../../domain/services/template_edit.dart';
import '../../../domain/services/free_template.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/character_stat_chips.dart'
    show chipIconFromName, kChipIconChoices;
import '../../widgets/pen_color_picker.dart' show showCustomColorDialog;
import '../database/database_screen.dart' show parseHexColor;
import '../map/widgets/pin_edit_dialog.dart'
    show kPinColorChoices, kPinIconChoices;
import '../map/world_map_screen.dart' show mapIconFromName;
import 'template_edit_controller.dart';
import 'template_styles.dart';

/// '#rrggbb', the form category colours are stored in.
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Settings for whatever is selected (desktop right panel).
class TemplateSettingsPanel extends StatelessWidget {
  const TemplateSettingsPanel({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return switch (c.panel) {
      TemplatePanel.info => TemplateInfoForm(controller: c),
      TemplatePanel.guide => TemplateGuideForm(controller: c),
      TemplatePanel.encounter => TemplateEncounterForm(controller: c),
      TemplatePanel.field when c.field != null => TemplateFieldForm(
        controller: c,
      ),
      TemplatePanel.group when c.group != null => TemplateGroupForm(
        controller: c,
      ),
      TemplatePanel.preset when c.preset != null => TemplatePresetForm(
        controller: c,
      ),
      _ when c.category != null => TemplateCategoryForm(controller: c),
      _ => TemplateInfoForm(controller: c),
    };
  }
}

// ------------------------------------------------------------------ dialogs

/// Asks for a name; null when cancelled. The confirm button stays off while
/// the name is blank.
Future<String?> askTemplateName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, label: label, initial: initial),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _text.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _text.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.btnAdd),
        ),
      ],
    );
  }
}

Future<bool> confirmTemplateAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool danger = true,
}) async {
  final palette = Theme.of(context).extension<DmToolColors>()!;
  final l10n = L10n.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: palette.dangerBtnBg,
                  foregroundColor: palette.dangerBtnText,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Palette pick → label → new field. The key is made from this label (V3),
/// so it is asked before the field exists.
Future<void> addFieldWithLabel(
  BuildContext context,
  TemplateEditController c,
  FieldType type, {
  String? groupId,
  int? index,
}) async {
  final l10n = L10n.of(context)!;
  final label = await askTemplateName(
    context,
    title: l10n.tplAddField,
    label: l10n.tplFieldLabel,
    initial: styleLabel(l10n, type),
  );
  if (label != null) c.addField(label, type, groupId: groupId, index: index);
}

/// What the palette, a drop or the "+ Add" sheet gave: a style asks for a
/// label first; a preset goes in bound, once per category (V8).
Future<void> addFromPalette(
  BuildContext context,
  TemplateEditController c,
  TemplateDrag d, {
  String? groupId,
  int? index,
}) async {
  final presetId = d.presetId;
  final type = d.type;
  if (presetId == null && type != null) {
    final l10n = L10n.of(context)!;
    final cat = c.category;
    // One Combat stats block, Level table and Pool per category; the
    // Level once, on the player card (D34, DESIGN §8.4, §8.6, §8.7).
    if (cat != null && !canAddFieldType(cat, type)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.tplStyleOnce(styleLabel(l10n, type)))),
      );
      return;
    }
    // Their keys are fixed; no label to ask.
    if (hasFixedKey(type)) {
      c.addField(
        styleLabel(l10n, type),
        type,
        key: playerCardFieldKey(type),
        groupId: groupId,
        index: index,
      );
      return;
    }
    return addFieldWithLabel(context, c, type, groupId: groupId, index: index);
  }
  if (presetId == null) return;
  if (!c.addPresetField(presetId, groupId: groupId, index: index)) {
    final l10n = L10n.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          l10n.tplPresetAlreadyIn(c.presetById(presetId)?.label ?? ''),
        ),
      ),
    );
  }
}

/// A style, then a label → a new preset (DESIGN §9). True when one was made
/// (it is then the open one).
Future<bool> addPresetWithLabel(
  BuildContext context,
  TemplateEditController c,
) async {
  final l10n = L10n.of(context)!;
  final type = (await showStylePickerSheet(context))?.type;
  if (type == null || !context.mounted) return false;
  final label = await askTemplateName(
    context,
    title: l10n.tplAddPreset,
    label: l10n.tplFieldLabel,
    initial: styleLabel(l10n, type),
  );
  if (label == null) return false;
  c.addPreset(label, type);
  return true;
}

Future<void> addGroupWithName(
  BuildContext context,
  TemplateEditController c,
) async {
  final l10n = L10n.of(context)!;
  final name = await askTemplateName(
    context,
    title: l10n.tplAddGroup,
    label: l10n.tplGroupName,
    initial: l10n.tplNewGroupName,
  );
  if (name != null) c.addGroup(name);
}

/// True when a category was added (it is then the open one).
Future<bool> addCategoryWithName(
  BuildContext context,
  TemplateEditController c,
) async {
  final l10n = L10n.of(context)!;
  final name = await askTemplateName(
    context,
    title: l10n.tplAddCategory,
    label: l10n.tplCategoryName,
    initial: l10n.tplNewCategoryName,
  );
  if (name == null) return false;
  c.addCategory(name);
  return true;
}

// -------------------------------------------------------------------- forms

class TemplateInfoForm extends StatelessWidget {
  const TemplateInfoForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final s = controller.schema;
    return ListView(
      key: const ValueKey('info'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(l10n.tplInfo),
        _TextSetting(
          label: l10n.tplName,
          value: s.name,
          onChanged: (v) =>
              controller.updateInfo(name: v.trim().isEmpty ? null : v),
        ),
        _TextSetting(
          label: l10n.tplDescription,
          value: s.description,
          maxLines: 4,
          onChanged: (v) => controller.updateInfo(description: v),
        ),
        _TextSetting(
          label: l10n.tplVersion,
          value: s.version,
          onChanged: (v) => controller.updateInfo(version: v),
        ),
      ],
    );
  }
}

/// The player card's character creation guide (DESIGN §13.2): steps, each
/// an optional field (V16) and a markdown text; drag to reorder.
class TemplateGuideForm extends StatelessWidget {
  const TemplateGuideForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = controller;
    final card = freePlayerCard(c.schema);
    if (card == null) return const SizedBox.shrink();
    final steps = guideOf(card);
    void set(int i, GuideStep s) =>
        c.updateGuide([for (final (j, x) in steps.indexed) j == i ? s : x]);

    return ReorderableListView.builder(
      key: const ValueKey('guide'),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(16),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(l10n.tplGuide),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.tplGuideHint,
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        ],
      ),
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('guide_add'),
          onPressed: () => c.updateGuide([
            ...steps,
            (id: c.newGuideStepId(), field: null, text: ''),
          ]),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.tplGuideAddStep),
        ),
      ),
      itemCount: steps.length,
      onReorderItem: (from, to) {
        final next = [...steps];
        next.insert(to, next.removeAt(from));
        c.updateGuide(next);
      },
      itemBuilder: (context, i) => _GuideStepTile(
        key: ValueKey('guide-${steps[i].id}'),
        index: i,
        step: steps[i],
        schema: c.schema,
        card: card,
        onChanged: (s) => set(i, s),
        onDelete: () => c.updateGuide([...steps]..removeAt(i)),
      ),
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({
    super.key,
    required this.index,
    required this.step,
    required this.schema,
    required this.card,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final GuideStep step;
  final WorldSchema schema;
  final EntityCategorySchema card;
  final ValueChanged<GuideStep> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final gone =
        step.field != null && !card.fields.any((f) => f.fieldKey == step.field);
    // The player card's fields by group (DESIGN §13.2), level links tagged.
    DropdownMenuItem<String?> field(FieldSchema f) => DropdownMenuItem(
      value: f.fieldKey,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          linksLevelCards(schema, f)
              ? '${f.label}  [${l10n.tplLevelListBadge}]'
              : f.label,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    DropdownMenuItem<String?> heading(String id, String text) =>
        DropdownMenuItem(
          value: '#$id',
          enabled: false,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        );
    final ungrouped = fieldsIn(card, null);
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(l10n.tplGuideNoField)),
      if (gone)
        DropdownMenuItem(value: step.field, child: Text(l10n.tplGuideFieldGone)),
      if (ungrouped.isNotEmpty) heading('', l10n.propertiesTitle),
      for (final f in ungrouped) field(f),
      for (final g in sortedGroups(card))
        if (fieldsIn(card, g.groupId).isNotEmpty) ...[
          heading(g.groupId, g.name),
          for (final f in fieldsIn(card, g.groupId)) field(f),
        ],
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      decoration: BoxDecoration(
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: l10n.tplDragHandle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '${index + 1}.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    key: ValueKey('guide_field_$index'),
                    value: step.field,
                    isExpanded: true,
                    style: TextStyle(fontSize: 13, color: palette.tabActiveText),
                    items: items,
                    onChanged: (v) =>
                        onChanged((id: step.id, field: v, text: step.text)),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.btnDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _TextSetting(
              label: l10n.tplGuideText,
              value: step.text,
              maxLines: 6,
              onChanged: (v) =>
                  onChanged((id: step.id, field: step.field, text: v)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encounter and map (DESIGN §14): which categories join, what the table
/// sorts and rolls by, where battle maps come from. The columns are the
/// Combat stats blocks' own settings.
class TemplateEncounterForm extends StatelessWidget {
  const TemplateEncounterForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final c = controller;
    final s = c.schema;
    final cfg = s.encounterConfig;
    final joined = encounterCategories(s).map((x) => x.categoryId).toSet();
    final sortable = [
      for (final v in encounterValues(s))
        if (v.type != CombatValueType.cards) v,
    ];
    final sort = encounterSortValue(s);
    final preset = encounterPreset(s);
    final presets = [
      for (final p in presetsOf(s))
        if (p.fieldType == FieldType.combatStats) p,
    ];
    final maps = cfg.battlemapFields ?? const <String, List<String>>{};
    final withImages = [
      for (final cat in s.categories)
        if (cat.fields.any((f) => isBattlemapFieldType(f.fieldType))) cat,
    ];

    return ListView(
      key: const ValueKey('encounter'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(l10n.tplEncounter),
        _Hint(l10n.tplEncounterHint),
        // Required: the encounter reads one Combat stats preset (§14.2).
        if (presets.isEmpty)
          _EncounterWarning(l10n.tplEncounterNoPresets)
        else ...[
          _Dropdown<String>(
            label: l10n.tplEncounterPreset,
            value: preset?.fieldId ?? '',
            items: {
              if (preset == null) '': l10n.tplEncounterSortNone,
              for (final p in presets) p.fieldId: p.label,
            },
            onChanged: (id) {
              if (id != null && id.isNotEmpty) {
                c.updateEncounter(cfg.copyWith(combatPresetId: id));
              }
            },
          ),
          if (preset == null) _EncounterWarning(l10n.tplEncounterPickPreset),
        ],
        _Label(l10n.tplEncounterCategories),
        for (final cat in s.categories) ...[
          _Check(
            key: ValueKey('enc_cat_${cat.slug}'),
            label: cat.name,
            hint: cat.isPlayerCard == true ? l10n.tplEncounterPlayerAlways : null,
            value: joined.contains(cat.categoryId),
            onChanged: (on) {
              if (cat.isPlayerCard != true) c.setInEncounter(cat.categoryId, on);
            },
          ),
          if (joined.contains(cat.categoryId) && combatBlockOf(cat) == null)
            _EncounterWarning(
              l10n.tplEncounterNeedsBlock,
              indent: true,
              action: preset == null
                  ? null
                  : TextButton(
                      key: ValueKey('enc_add_block_${cat.slug}'),
                      onPressed: () => c.addCombatBlock(cat.categoryId),
                      child: Text(l10n.btnAdd),
                    ),
            ),
        ],
        const SizedBox(height: 12),
        _Dropdown<String>(
          label: l10n.tplEncounterSort,
          helper: l10n.tplEncounterSortHint,
          value: sort?.key ?? '',
          items: {
            '': l10n.tplEncounterSortNone,
            for (final v in sortable) v.key: v.label,
          },
          onChanged: (k) => c.updateEncounter(
            cfg.copyWith(sortBySubField: k ?? '', initiativeSubField: k ?? ''),
          ),
        ),
        if (sort != null)
          _Dropdown<String>(
            key: const ValueKey('enc_sort_direction'),
            label: l10n.tplEncounterSortDirection,
            value: cfg.sortDirection == 'asc' ? 'asc' : 'desc',
            items: {
              'desc': l10n.tplEncounterSortDesc,
              'asc': l10n.tplEncounterSortAsc,
            },
            onChanged: (d) =>
                c.updateEncounter(cfg.copyWith(sortDirection: d ?? 'desc')),
          ),
        if (sort?.type == CombatValueType.number)
          _TextSetting(
            label: l10n.tplEncounterSortDice,
            value: cfg.sortDice ?? '',
            hint: '1d20',
            helper: l10n.tplEncounterSortDiceHint,
            onChanged: (v) => c.updateEncounter(
              cfg.copyWith(sortDice: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
        _Label(l10n.tplBattlemapFields, hint: l10n.tplBattlemapFieldsHint),
        if (withImages.isEmpty) _Hint(l10n.tplBattlemapNone),
        for (final cat in withImages) ...[
          Text(cat.name, style: const TextStyle(fontSize: 12)),
          Wrap(
            spacing: 16,
            children: [
              for (final f in cat.fields)
                if (isBattlemapFieldType(f.fieldType))
                  _Check(
                    key: ValueKey('enc_map_${cat.slug}_${f.fieldKey}'),
                    label: f.label,
                    dense: true,
                    value: maps[cat.slug]?.contains(f.fieldKey) ?? false,
                    onChanged: (on) {
                      final keys = [
                        for (final k in maps[cat.slug] ?? const <String>[])
                          if (k != f.fieldKey) k,
                        if (on) f.fieldKey,
                      ];
                      c.updateEncounter(
                        cfg.copyWith(
                          battlemapFields: {
                            for (final e in maps.entries)
                              if (e.key != cat.slug) e.key: e.value,
                            if (keys.isNotEmpty) cat.slug: keys,
                          },
                        ),
                      );
                    },
                  ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        _Hint(l10n.tplTrailColorHint),
      ],
    );
  }
}

/// An info line of the encounter settings, with an optional fix.
class _EncounterWarning extends StatelessWidget {
  const _EncounterWarning(this.text, {this.indent = false, this.action});

  final String text;
  final bool indent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: EdgeInsets.only(left: indent ? 26 : 0, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ?action,
        ],
      ),
    );
  }
}

class TemplateCategoryForm extends StatelessWidget {
  const TemplateCategoryForm({super.key, required this.controller});

  final TemplateEditController controller;

  static const _sections = ['worldmap', 'mindmap', 'projection'];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final cat = controller.category!;
    void set(EntityCategorySchema n) => controller.updateCategory(n);
    List<String> toggled(List<String> list, String v) =>
        list.contains(v) ? [...list.where((x) => x != v)] : [...list, v];
    final filterable = [
      for (final f in fieldsIn(cat, null)) f,
      for (final g in sortedGroups(cat)) ...fieldsIn(cat, g.groupId),
    ].where((f) => isSimpleFieldType(f.fieldType));

    return ListView(
      key: ValueKey('cat-${cat.categoryId}'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(l10n.tplCategorySettings),
        _TextSetting(
          label: l10n.tplName,
          value: cat.name,
          onChanged: (v) {
            if (v.trim().isNotEmpty) set(cat.copyWith(name: v));
          },
        ),
        _Label(l10n.tplColor),
        _ColorChoice(
          value: cat.color,
          onChanged: (hex) => set(cat.copyWith(color: hex)),
        ),
        const SizedBox(height: 16),
        _Dropdown<int>(
          label: l10n.tplTier,
          helper: l10n.tplTierHint,
          value: cat.tier ?? builtinTier(cat.slug),
          items: {0: l10n.tplTier0, 1: l10n.tplTier1, 2: l10n.tplTier2},
          onChanged: (t) => set(cat.copyWith(tier: t)),
        ),
        _Label(l10n.tplSections),
        for (final s in _sections)
          _Check(
            label: switch (s) {
              'worldmap' => l10n.tplSectionWorldmap,
              'mindmap' => l10n.tplSectionMindmap,
              _ => l10n.tplSectionProjection,
            },
            value: cat.allowedInSections.contains(s),
            onChanged: (_) => set(
              cat.copyWith(
                allowedInSections: toggled(cat.allowedInSections, s),
              ),
            ),
            // The icon only matters on the world map (its pins).
            trailing: s == 'worldmap' && cat.allowedInSections.contains(s)
                ? _MapIconButton(
                    value: cat.icon,
                    onChanged: (name) => set(cat.copyWith(icon: name)),
                  )
                : null,
          ),
        const SizedBox(height: 8),
        _Label(l10n.tplFilters, hint: l10n.tplFiltersHint),
        if (filterable.isEmpty)
          _Hint(l10n.tplGroupEmpty)
        else
          Wrap(
            spacing: 16,
            children: [
              for (final f in filterable)
                _Check(
                  label: f.label,
                  dense: true,
                  value: cat.filterFieldKeys.contains(f.fieldKey),
                  onChanged: (_) => set(
                    cat.copyWith(
                      filterFieldKeys: toggled(cat.filterFieldKeys, f.fieldKey),
                    ),
                  ),
                ),
            ],
          ),
        // Only a category with a Level table levels up (DESIGN §11.2).
        if (cat.fields.any(
          (f) => f.fieldType == FieldType.progressionTable,
        )) ...[
          _Label(l10n.tplLevelMode, hint: l10n.tplLevelModeHint),
          Align(
            alignment: Alignment.centerLeft,
            child: TemplatePills<String>(
              items: [
                ('together', l10n.tplLevelTogether, null),
                ('separate', l10n.tplLevelSeparate, null),
              ],
              value: cat.levelMode == 'separate' ? 'separate' : 'together',
              onChanged: (m) => set(
                cat.copyWith(levelMode: m == 'separate' ? m : null),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // What character cards and the sheet's header show.
        if (cat.isPlayerCard == true) ...[
          _Label(l10n.tplSummaryChips, hint: l10n.tplSummaryChipsHint),
          _SummaryChips(
            card: cat,
            onChanged: (chips) => set(
              cat.copyWith(
                summaryChips: [for (final c in chips) sheetChipJson(c)],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        if (canRemoveCategory(cat)) _categoryOrder(cat),
        const SizedBox(height: 16),
        if (canRemoveCategory(cat))
          _DeleteButton(
            label: l10n.tplDeleteCategory,
            onPressed: () async {
              if (await confirmTemplateAction(
                context,
                title: l10n.tplDeleteCategory,
                body: l10n.tplDeleteCategoryBody(cat.name),
                confirm: l10n.btnDelete,
              )) {
                controller.removeCategory(cat.categoryId);
              }
            },
          )
        else
          _Hint(l10n.tplPlayerCardLocked),
      ],
    );
  }
}

extension on TemplateCategoryForm {
  /// Up / down among the non-player categories: the no-drag way to reorder.
  Widget _categoryOrder(EntityCategorySchema cat) {
    final all = controller.schema.categories;
    final others = [
      for (final c in all)
        if (canRemoveCategory(c)) c.categoryId,
    ];
    final i = others.indexOf(cat.categoryId);
    void move(int to) {
      others.insert(to, others.removeAt(i));
      controller.reorderCategories([
        for (final c in all)
          if (!canRemoveCategory(c)) c.categoryId,
        ...others,
      ]);
    }

    return _OrderRow(
      onUp: i > 0 ? () => move(i - 1) : null,
      onDown: i < others.length - 1 ? () => move(i + 1) : null,
    );
  }
}

class TemplateGroupForm extends StatelessWidget {
  const TemplateGroupForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final g = controller.group!;
    final cat = controller.category!;
    void set(FieldGroup n) => controller.updateGroup(n);
    return ListView(
      key: ValueKey('group-${g.groupId}'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(l10n.tplGroupSettings),
        _TextSetting(
          label: l10n.tplGroupName,
          value: g.name,
          onChanged: (v) => set(g.copyWith(name: v)),
        ),
        _Label(l10n.tplColumnCount),
        _NumberPills(
          count: 4,
          value: g.gridColumns,
          onChanged: (n) => set(g.copyWith(gridColumns: n)),
        ),
        const SizedBox(height: 8),
        _Check(
          label: l10n.tplCollapsed,
          value: g.isCollapsed,
          onChanged: (v) => set(g.copyWith(isCollapsed: v)),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final groups = sortedGroups(cat);
            final i = groups.indexWhere((x) => x.groupId == g.groupId);
            return _OrderRow(
              onUp: i > 0 ? () => controller.reorderGroups(i, i - 1) : null,
              onDown: i < groups.length - 1
                  ? () => controller.reorderGroups(i, i + 1)
                  : null,
            );
          },
        ),
        if (fieldsIn(cat, g.groupId).isNotEmpty)
          _MoveFieldsRow(controller: controller, from: g.groupId),
        const SizedBox(height: 16),
        _DeleteButton(
          label: l10n.tplDeleteGroup,
          onPressed: () async {
            if (await confirmTemplateAction(
              context,
              title: l10n.tplDeleteGroup,
              body: l10n.tplDeleteGroupBody(g.name),
              confirm: l10n.btnDelete,
            )) {
              controller.removeGroup(g.groupId);
            }
          },
        ),
      ],
    );
  }
}

class _MoveFieldsRow extends StatefulWidget {
  const _MoveFieldsRow({required this.controller, required this.from});

  final TemplateEditController controller;
  final String from;

  @override
  State<_MoveFieldsRow> createState() => _MoveFieldsRowState();
}

class _MoveFieldsRowState extends State<_MoveFieldsRow> {
  String? _to;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final cat = widget.controller.category!;
    final targets = sortedGroups(cat).where((g) => g.groupId != widget.from);
    return Row(
      children: [
        Expanded(
          child: _Dropdown<String?>(
            label: l10n.tplMoveFields,
            value: _to,
            items: {
              null: l10n.propertiesTitle,
              for (final g in targets) g.groupId: g.name,
            },
            onChanged: (v) => setState(() => _to = v),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton(
            onPressed: () =>
                widget.controller.moveGroupFields(widget.from, _to),
            child: Text(l10n.tplMove),
          ),
        ),
      ],
    );
  }
}

class TemplateFieldForm extends StatelessWidget {
  const TemplateFieldForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final c = controller;
    final f = c.field!;
    final cat = c.category!;
    final preset = c.presetById(f.presetId);
    final legacy = isLegacyFieldType(f.fieldType);
    final groups = sortedGroups(cat);
    final cols =
        groups.where((g) => g.groupId == f.groupId).firstOrNull?.gridColumns ??
        1;
    void set(FieldSchema n) => c.updateField(n);

    return ListView(
      key: ValueKey('field-${f.fieldId}'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(
          styleLabel(l10n, f.fieldType),
          icon: styleIcon(f.fieldType),
          trailing: legacy
              ? TemplatePill(l10n.tplLegacyBadge, tooltip: l10n.tplLegacyHint)
              : null,
        ),
        // A bound field's structure is its preset's (DESIGN §9).
        if (preset != null) ...[
          _PresetLink(
            preset: preset,
            onUnlink: () => c.unlinkField(f.fieldId),
          ),
          _KeyRow(f.fieldKey),
        ] else
          ..._structureHead(
            context,
            f,
            set,
            legacy: legacy,
            onType: (t, list) => _changeType(context, f, t, list),
          ),
        _Dropdown<FieldVisibility>(
          label: l10n.tplVisibility,
          value: f.visibility,
          items: {
            FieldVisibility.shared: l10n.tplVisShared,
            FieldVisibility.dmOnly: l10n.tplVisDm,
            FieldVisibility.private_: l10n.tplVisPrivate,
          },
          onChanged: (v) => set(f.copyWith(visibility: v!)),
        ),
        if (cols > 1) ...[
          _Label(l10n.tplWidth),
          _NumberPills(
            count: cols,
            value: f.gridColumnSpan,
            onChanged: (n) => set(f.copyWith(gridColumnSpan: n)),
          ),
          const SizedBox(height: 12),
        ],
        _Dropdown<String?>(
          label: l10n.tplGroup,
          value: f.groupId,
          items: {
            null: l10n.propertiesTitle,
            for (final g in groups) g.groupId: g.name,
          },
          onChanged: (g) => c.moveField(f.fieldId, groupId: g),
        ),
        Builder(
          builder: (context) {
            final siblings = fieldsIn(cat, f.groupId);
            final i = siblings.indexWhere((x) => x.fieldId == f.fieldId);
            return _OrderRow(
              onUp: i > 0
                  ? () =>
                        c.moveField(f.fieldId, groupId: f.groupId, index: i - 1)
                  : null,
              onDown: i < siblings.length - 1
                  ? () =>
                        c.moveField(f.fieldId, groupId: f.groupId, index: i + 1)
                  : null,
            );
          },
        ),
        if (preset == null && !legacy && !hasFixedKey(f.fieldType)) ...[
          ..._styleSettings(
            context,
            f,
            set,
            categories: c.schema.categories,
            fields: cat.fields,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: l10n.tplSaveAsPresetHint,
              child: TextButton.icon(
                onPressed: () => c.saveAsPreset(f.fieldId),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(l10n.tplSaveAsPreset),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _DeleteButton(
          label: l10n.tplDeleteField,
          onPressed: () async {
            // The player card's Level and Pool come back from the palette;
            // what uses them is listed first (D34, DESIGN §10.1).
            final own =
                cat.isPlayerCard == true && hasFixedKey(f.fieldType);
            final users = own
                ? ownFieldUsers(c.schema, f.fieldType)
                : const <String>[];
            if (await confirmTemplateAction(
              context,
              title: l10n.tplDeleteField,
              body: !own
                  ? l10n.tplDeleteFieldBody(f.label)
                  : users.isEmpty
                  ? l10n.tplDeleteOwnFieldBody(f.label)
                  : l10n.tplDeleteOwnFieldUsers(f.label, users.join(', ')),
              confirm: l10n.btnDelete,
            )) {
              c.removeField(f.fieldId);
            }
          },
        ),
      ],
    );
  }

  Future<void> _changeType(
    BuildContext context,
    FieldSchema f,
    FieldType to,
    bool toList,
  ) async {
    final l10n = L10n.of(context)!;
    final change = typeChangeOf(f.fieldType, f.isList, to, toList);
    if (change == TypeChange.same) return;
    if (change == TypeChange.lossy || change == TypeChange.incompatible) {
      final ok = await confirmTemplateAction(
        context,
        title: l10n.tplTypeChangeTitle,
        body: change == TypeChange.lossy
            ? l10n.tplTypeChangeLossy
            : l10n.tplTypeChangeIncompatible(styleLabel(l10n, to)),
        confirm: l10n.tplChange,
        danger: false,
      );
      if (!ok) return;
    }
    controller.changeFieldType(f.fieldId, to, toList);
  }
}

/// A preset's settings (DESIGN §9): the structure every bound field takes,
/// where it is used, copy and delete. Its style is picked when it is made.
class TemplatePresetForm extends StatelessWidget {
  const TemplatePresetForm({super.key, required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final c = controller;
    final p = c.preset!;
    final uses = presetUses(c.schema, p.fieldId);
    void set(FieldSchema n) => c.updatePreset(n);
    // What a skill table can read: the fields of the categories the preset
    // is in (all categories while it is in none).
    final fields = {
      for (final cat in uses.isEmpty ? c.schema.categories : uses)
        for (final f in cat.fields) f.fieldKey: f,
    }.values.toList();

    return ListView(
      key: ValueKey('preset-${p.fieldId}'),
      padding: const EdgeInsets.all(16),
      children: [
        _Heading(
          l10n.tplPreset,
          icon: Icons.bookmark_outline,
          trailing: TemplatePill(styleLabel(l10n, p.fieldType)),
        ),
        _Hint(l10n.tplPresetFormHint),
        ..._structureHead(
          context,
          p,
          set,
          legacy: isLegacyFieldType(p.fieldType),
        ),
        ..._styleSettings(
          context,
          p,
          set,
          categories: c.schema.categories,
          fields: fields,
        ),
        const SizedBox(height: 8),
        _Label(l10n.tplPresetUsedIn),
        if (uses.isEmpty)
          _Hint(l10n.tplPresetUnused)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final cat in uses) TemplatePill(cat.name)],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final name = await askTemplateName(
                context,
                title: l10n.tplCopyPreset,
                label: l10n.tplFieldLabel,
                initial: l10n.templateCopyName(p.label),
              );
              if (name != null) c.copyPreset(p.fieldId, name);
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(l10n.tplCopyPreset),
          ),
        ),
        _DeleteButton(
          label: l10n.tplDeletePreset,
          onPressed: () async {
            if (await confirmTemplateAction(
              context,
              title: l10n.tplDeletePreset,
              body: l10n.tplDeletePresetBody(p.label, uses.length),
              confirm: l10n.btnDelete,
            )) {
              c.removePreset(p.fieldId);
            }
          },
        ),
      ],
    );
  }
}

/// "Preset: Skills" and its Break link button, on a bound field.
class _PresetLink extends StatelessWidget {
  const _PresetLink({required this.preset, required this.onUnlink});

  final FieldSchema preset;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark, size: 16, color: palette.featureCardAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tplBoundTo(preset.label),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tplBoundHint,
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onUnlink,
              icon: const Icon(Icons.link_off, size: 18),
              label: Text(l10n.tplUnlink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The field key: made once, shown read-only (V3).
class _KeyRow extends StatelessWidget {
  const _KeyRow(this.fieldKey);

  final String fieldKey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '${l10n.tplFieldKey}  ',
            style: TextStyle(fontSize: 12, color: palette.tabText),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: palette.sidebarFilterBg,
                borderRadius: palette.br,
              ),
              child: SelectableText(
                fieldKey,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: palette.tabActiveText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: l10n.tplFieldKeyHint,
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label, key and — unless [legacy] — the style ([onType] null: fixed, as
/// on a preset), list, required, help text and default value.
List<Widget> _structureHead(
  BuildContext context,
  FieldSchema f,
  void Function(FieldSchema) set, {
  required bool legacy,
  void Function(FieldType to, bool toList)? onType,
}) {
  final l10n = L10n.of(context)!;
  final simple = isSimpleFieldType(f.fieldType);
  return [
    _TextSetting(
      label: l10n.tplFieldLabel,
      value: f.label,
      onChanged: (v) => set(f.copyWith(label: v)),
    ),
    _KeyRow(f.fieldKey),
    if (!legacy) ...[
      if (onType != null && !hasFixedStyle(f.fieldType)) ...[
        _Dropdown<FieldType>(
          label: l10n.tplStyle,
          value: f.fieldType,
          items: {for (final t in switchableFieldTypes) t: styleLabel(l10n, t)},
          onChanged: (t) => onType(t!, f.isList && canBeList(t)),
        ),
        if (canBeList(f.fieldType))
          _Check(
            label: l10n.tplList,
            value: f.isList,
            onChanged: (v) => onType(f.fieldType, v),
          ),
      ],
      if (simple)
        _Check(
          label: l10n.tplRequired,
          hint: l10n.tplRequiredHint,
          value: f.isRequired,
          onChanged: (v) => set(f.copyWith(isRequired: v)),
        ),
      const SizedBox(height: 8),
      _TextSetting(
        label: l10n.tplHelpText,
        value: f.helpText,
        onChanged: (v) => set(f.copyWith(helpText: v)),
      ),
      if (simple && !f.isList) ..._defaultValue(l10n, f, set),
    ],
  ];
}

List<Widget> _defaultValue(
  L10n l10n,
  FieldSchema f,
  void Function(FieldSchema) set,
) {
  final v = f.defaultValue;
  return switch (f.fieldType) {
    FieldType.text ||
    FieldType.textarea ||
    FieldType.markdown ||
    FieldType.dice => [
      _TextSetting(
        label: l10n.tplDefault,
        value: v is String ? v : '',
        maxLines: f.fieldType == FieldType.text ? 1 : 3,
        onChanged: (s) => set(f.copyWith(defaultValue: s.isEmpty ? null : s)),
      ),
    ],
    FieldType.integer || FieldType.float_ => [
      _TextSetting(
        label: l10n.tplDefault,
        value: v is num ? '$v' : '',
        number: true,
        onChanged: (s) => set(
          f.copyWith(
            defaultValue: f.fieldType == FieldType.integer
                ? int.tryParse(s.trim())
                : _parseDouble(s),
          ),
        ),
      ),
    ],
    FieldType.boolean_ => [
      _Check(
        label: l10n.tplDefault,
        value: v == true,
        onChanged: (b) => set(f.copyWith(defaultValue: b ? true : null)),
      ),
      const SizedBox(height: 8),
    ],
    FieldType.enum_ => [
      _Dropdown<String?>(
        label: l10n.tplDefault,
        value: (f.validation.allowedValues ?? const []).contains(v)
            ? v as String
            : null,
        items: {
          null: '—',
          for (final o in f.validation.allowedValues ?? const <String>[])
            o: o,
        },
        onChanged: (s) => set(f.copyWith(defaultValue: s)),
      ),
    ],
    _ => const [],
  };
}

/// The style's own settings. [categories]: link targets; [fields]: what a
/// skill table can read (its stat table and bonus).
List<Widget> _styleSettings(
  BuildContext context,
  FieldSchema f,
  void Function(FieldSchema) set, {
  required List<EntityCategorySchema> categories,
  required List<FieldSchema> fields,
}) {
  final l10n = L10n.of(context)!;
  final rule = f.validation;
  void setRule(FieldValidation v) => set(f.copyWith(validation: v));
  String num(double? d) =>
      d == null ? '' : (d == d.roundToDouble() ? '${d.toInt()}' : '$d');
  switch (f.fieldType) {
    case FieldType.text:
      return [
        _TextSetting(
          label: l10n.tplPlaceholder,
          value: f.placeholder,
          onChanged: (v) => set(f.copyWith(placeholder: v)),
        ),
        _TextSetting(
          label: l10n.tplMaxLength,
          value: rule.maxLength?.toString() ?? '',
          number: true,
          onChanged: (v) =>
              setRule(rule.copyWith(maxLength: int.tryParse(v.trim()))),
        ),
      ];
    case FieldType.integer:
    case FieldType.float_:
      return [
        Row(
          children: [
            Expanded(
              child: _TextSetting(
                label: l10n.tplMin,
                value: num(rule.minValue),
                number: true,
                onChanged: (v) =>
                    setRule(rule.copyWith(minValue: _parseDouble(v))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TextSetting(
                label: l10n.tplMax,
                value: num(rule.maxValue),
                number: true,
                onChanged: (v) =>
                    setRule(rule.copyWith(maxValue: _parseDouble(v))),
              ),
            ),
          ],
        ),
      ];
    case FieldType.enum_:
      return [
        _Label(l10n.tplOptions),
        _OptionsEditor(
          options: rule.allowedValues ?? const [],
          onChanged: (list) => setRule(rule.copyWith(allowedValues: list)),
        ),
      ];
    case FieldType.relation:
      final targets = rule.allowedTypes ?? const <String>[];
      return [
        _Label(l10n.tplTargets, hint: l10n.tplTargetsAny),
        Wrap(
          spacing: 16,
          children: [
            for (final cat in categories)
              _Check(
                label: cat.name,
                dense: true,
                leading: TemplateColorDot(color: parseHexColor(cat.color)),
                value: targets.contains(cat.slug),
                onChanged: (on) {
                  final next = on
                      ? [...targets, cat.slug]
                      : [...targets.where((s) => s != cat.slug)];
                  setRule(
                    rule.copyWith(allowedTypes: next.isEmpty ? null : next),
                  );
                },
              ),
          ],
        ),
      ];
    case FieldType.file:
      return [
        _TextSetting(
          label: l10n.tplExtensions,
          hint: l10n.tplExtensionsHint,
          value: (rule.allowedExtensions ?? const []).join(', '),
          onChanged: (v) {
            final list = [
              for (final e in v.split(RegExp(r'[,\s]+')))
                if (e.trim().isNotEmpty)
                  e.trim().replaceFirst('.', '').toLowerCase(),
            ];
            setRule(
              rule.copyWith(allowedExtensions: list.isEmpty ? null : list),
            );
          },
        ),
      ];
    case FieldType.statTable:
      return [_StatTableSettings(field: f, onChanged: set)];
    case FieldType.table:
      return [_TableSettings(field: f, onChanged: set, categories: categories)];
    case FieldType.skillTable:
      return [_SkillTableSettings(field: f, onChanged: set, fields: fields)];
    case FieldType.resource:
      return [_ResourceSettings(field: f, onChanged: set)];
    case FieldType.combatStats:
      return [
        _CombatStatsSettings(field: f, onChanged: set, categories: categories),
      ];
    // Each card fills these in on its own screen (DESIGN §8.4, §8.5).
    case FieldType.grantHolder:
      return [_Hint(l10n.tplGrantsCardHint)];
    case FieldType.progressionTable:
      return [_Hint(l10n.tplLevelTableCardHint)];
    default:
      return const [];
  }
}

/// A style's own settings outside the template: a card sets up a grant item
/// of that style (DESIGN §8.5) with the editor's forms.
List<Widget> styleSettingsFor(
  BuildContext context,
  FieldSchema f,
  void Function(FieldSchema) set, {
  required List<EntityCategorySchema> categories,
}) => _styleSettings(context, f, set, categories: categories, fields: const []);

// ------------------------------------------------- combined style settings

/// [list] with the item at [i] moved to [to].
List<T> _moved<T>(List<T> list, int i, int to) =>
    [...list]..insert(to, list[i])..removeAt(to < i ? i + 1 : i);

/// Stat table (DESIGN §8.2): labels, base value, step, modifier on / off.
class _StatTableSettings extends StatelessWidget {
  const _StatTableSettings({required this.field, required this.onChanged});

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final spec = StatTableSpec.of(field);
    final stats = spec.stats;
    void set(StatTableSpec s) =>
        onChanged(field.copyWith(styleConfig: s.toConfig()));
    void setStats(List<StatEntry> l) => set(spec.copyWith(stats: l));
    String mod(int v) {
      final m = spec.modifier(v);
      return m >= 0 ? '+$m' : '−${-m}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.tplStats),
        for (final (i, s) in stats.indexed)
          _ListItem(
            key: ValueKey('stat-${s.key}'),
            onUp: i > 0 ? () => setStats(_moved(stats, i, i - 1)) : null,
            onDown: i < stats.length - 1
                ? () => setStats(_moved(stats, i, i + 2))
                : null,
            onDelete: () => setStats([...stats]..removeAt(i)),
            deleteLabel: l10n.btnDelete,
            child: _TextSetting(
              label: l10n.tplStatLabel,
              value: s.label,
              onChanged: (v) {
                if (v.trim().isEmpty) return;
                setStats([...stats]..[i] = (key: s.key, label: v.trim()));
              },
            ),
          ),
        _AddLine(
          label: l10n.tplAddStat,
          // The key is made once, from the first label (V3).
          onAdd: (label) => setStats([
            ...stats,
            (key: keyFromLabel(label, stats.map((s) => s.key)), label: label),
          ]),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TextSetting(
                label: l10n.tplStatBase,
                helper: l10n.tplStatBaseHint,
                value: '${spec.base}',
                number: true,
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null) set(spec.copyWith(base: n));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TextSetting(
                label: l10n.tplStatStep,
                helper: l10n.tplStatStepHint,
                value: '${spec.step}',
                number: true,
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n >= 1) set(spec.copyWith(step: n));
                },
              ),
            ),
          ],
        ),
        _Check(
          label: l10n.tplShowModifier,
          hint: l10n.tplShowModifierHint,
          value: spec.showModifier,
          onChanged: (v) => set(spec.copyWith(showModifier: v)),
        ),
        if (spec.showModifier)
          _Hint(
            [
              for (final v in [spec.base - 1, spec.base, spec.base + spec.step])
                '$v → ${mod(v)}',
            ].join('   ·   '),
          ),
      ],
    );
  }
}

String _columnTypeLabel(L10n l10n, TableColumnType t) => switch (t) {
  TableColumnType.text => l10n.tplStyleText,
  TableColumnType.number => l10n.tplColNumber,
  TableColumnType.check => l10n.tplStyleBoolean,
  TableColumnType.choice => l10n.tplStyleEnum,
  TableColumnType.dice => l10n.tplStyleDice,
  TableColumnType.relation => l10n.tplStyleRelation,
};

/// Table (DESIGN §8.1): row mode, columns, and the template's fixed rows.
class _TableSettings extends StatelessWidget {
  const _TableSettings({
    required this.field,
    required this.onChanged,
    required this.categories,
  });

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  /// A link column's possible targets.
  final List<EntityCategorySchema> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final spec = TableSpec.of(field);
    final cols = spec.columns;
    void set(TableSpec s) =>
        onChanged(field.copyWith(styleConfig: s.toConfig()));
    void setCols(List<TableColumn> l) => set(spec.copyWith(columns: l));

    Widget column(int i, TableColumn c) {
      void put(TableColumn n) => setCols([...cols]..[i] = n);
      return _ListItem(
        key: ValueKey('col-${c.key}'),
        boxed: true,
        onUp: i > 0 ? () => setCols(_moved(cols, i, i - 1)) : null,
        onDown: i < cols.length - 1
            ? () => setCols(_moved(cols, i, i + 2))
            : null,
        onDelete: () => setCols([...cols]..removeAt(i)),
        deleteLabel: l10n.tplDeleteColumn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextSetting(
              label: l10n.tplColumnLabel,
              value: c.label,
              onChanged: (v) {
                if (v.trim().isNotEmpty) put(c.copyWith(label: v.trim()));
              },
            ),
            _Dropdown<TableColumnType>(
              label: l10n.tplColumnType,
              value: c.type,
              items: {
                for (final t in TableColumnType.values)
                  t: _columnTypeLabel(l10n, t),
              },
              onChanged: (t) => put(c.copyWith(type: t)),
            ),
            ...switch (c.type) {
              TableColumnType.choice => [
                _OptionsEditor(
                  options: c.options,
                  onChanged: (l) => put(c.copyWith(options: l)),
                ),
              ],
              TableColumnType.relation => [
                _Label(l10n.tplTargets, hint: l10n.tplTargetsAny),
                Wrap(
                  spacing: 16,
                  children: [
                    for (final t in categories)
                      _Check(
                        label: t.name,
                        dense: true,
                        leading: TemplateColorDot(
                          color: parseHexColor(t.color),
                        ),
                        value: c.targets.contains(t.slug),
                        onChanged: (on) => put(
                          c.copyWith(
                            targets: on
                                ? [...c.targets, t.slug]
                                : [...c.targets.where((s) => s != t.slug)],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              _ => const <Widget>[],
            },
            if (spec.fixedRows)
              _Check(
                label: l10n.tplColLocked,
                hint: l10n.tplColLockedHint,
                value: c.locked,
                onChanged: (v) => put(c.copyWith(locked: v)),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.tplRows, hint: l10n.tplRowsHint),
        Align(
          alignment: Alignment.centerLeft,
          child: TemplatePills<bool>(
            items: [
              (false, l10n.tplRowsFree, null),
              (true, l10n.tplRowsFixed, null),
            ],
            value: spec.fixedRows,
            onChanged: (v) => set(spec.copyWith(fixedRows: v)),
          ),
        ),
        const SizedBox(height: 12),
        _Label(l10n.tplTableColumns),
        for (final (i, c) in cols.indexed) column(i, c),
        _AddLine(
          label: l10n.tplAddColumn,
          // The key is made once, from the first label (V3).
          onAdd: (label) => setCols([
            ...cols,
            TableColumn(
              key: keyFromLabel(label, cols.map((c) => c.key)),
              label: label,
            ),
          ]),
        ),
        if (spec.fixedRows) ...[
          _Label(l10n.tplTemplateRows),
          _TemplateRows(
            spec: spec,
            onChanged: (rows) => set(spec.copyWith(rows: rows)),
          ),
        ],
      ],
    );
  }
}

/// Skill table (D32): the stat table it reads, the number a mark adds, and
/// the template's rows (name and default stat).
class _SkillTableSettings extends StatelessWidget {
  const _SkillTableSettings({
    required this.field,
    required this.onChanged,
    required this.fields,
  });

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  /// The fields its stat table and bonus are picked from.
  final List<FieldSchema> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final spec = SkillTableSpec.of(field);
    final rows = spec.rows;
    void set(SkillTableSpec s) =>
        onChanged(field.copyWith(styleConfig: s.toConfig()));
    void setRows(List<Map<String, dynamic>> l) => set(spec.copyWith(rows: l));
    final statTables = {
      for (final x in fields)
        if (x.fieldType == FieldType.statTable) x.fieldKey: x.label,
    };
    final numbers = {
      for (final x in fields)
        if (x.fieldType == FieldType.integer || x.fieldType == FieldType.float_)
          x.fieldKey: x.label,
    };
    final stats = switch (skillStatField(spec, fields)) {
      final st? => StatTableSpec.of(st).stats,
      null => const <StatEntry>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Dropdown<String?>(
          label: l10n.tplSkillStats,
          value: statTables.containsKey(spec.stat) ? spec.stat : null,
          items: {null: l10n.tplSkillStatsFirst, ...statTables},
          onChanged: (k) => set(spec.copyWith(stat: () => k)),
        ),
        _Dropdown<String?>(
          label: l10n.tplSkillBonus,
          helper: l10n.tplSkillBonusHint,
          value: numbers.containsKey(spec.bonus) ? spec.bonus : null,
          items: {null: l10n.tplSkillBonusNone, ...numbers},
          onChanged: (k) => set(spec.copyWith(bonus: () => k)),
        ),
        _Check(
          label: l10n.tplSkillNameEditable,
          value: spec.nameEditable,
          onChanged: (v) => set(spec.copyWith(nameEditable: v)),
        ),
        _Check(
          label: l10n.tplSkillStatEditable,
          value: spec.statEditable,
          onChanged: (v) => set(spec.copyWith(statEditable: v)),
        ),
        _Label(l10n.tplTemplateRows),
        for (final (i, r) in rows.indexed)
          _ListItem(
            key: ValueKey('skill-${r[tableRowId]}'),
            onUp: i > 0 ? () => setRows(_moved(rows, i, i - 1)) : null,
            onDown: i < rows.length - 1
                ? () => setRows(_moved(rows, i, i + 2))
                : null,
            onDelete: () => setRows([...rows]..removeAt(i)),
            deleteLabel: l10n.btnDelete,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TextSetting(
                    label: l10n.tplStatLabel,
                    value: '${r['name'] ?? ''}',
                    onChanged: (v) {
                      if (v.trim().isEmpty) return;
                      setRows([...rows]..[i] = {...r, 'name': v.trim()});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: _Dropdown<String?>(
                    label: l10n.tplSkillRowStat,
                    value: stats.any((s) => s.key == r['ability'])
                        ? r['ability'] as String
                        : null,
                    items: {null: '—', for (final s in stats) s.key: s.label},
                    onChanged: (k) =>
                        setRows([...rows]..[i] = {...r, 'ability': k}),
                  ),
                ),
              ],
            ),
          ),
        _AddLine(
          label: l10n.tplAddRow,
          onAdd: (name) => setRows([
            ...rows,
            {tableRowId: nextTableRowId(rows), 'name': name},
          ]),
        ),
      ],
    );
  }
}

/// What each rest does (DESIGN §8.3, §12.3): fill, empty or leave as is.
List<Widget> _restSettings(
  L10n l10n,
  RestEffect short,
  RestEffect long,
  void Function(RestEffect short, RestEffect long) onChanged,
) {
  final items = {
    RestEffect.fill: l10n.tplRestFill,
    RestEffect.empty: l10n.tplRestEmpty,
    RestEffect.keep: l10n.tplRestKeep,
  };
  return [
    _Dropdown<RestEffect>(
      label: l10n.tplRestShort,
      value: short,
      items: items,
      onChanged: (e) => onChanged(e!, long),
    ),
    _Dropdown<RestEffect>(
      label: l10n.tplRestLong,
      value: long,
      items: items,
      onChanged: (e) => onChanged(short, e!),
    ),
  ];
}

/// Resource (DESIGN §8.3): number or boxes, and each rest's effect. The
/// max is the card's.
class _ResourceSettings extends StatelessWidget {
  const _ResourceSettings({required this.field, required this.onChanged});

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final spec = ResourceSpec.of(field);
    void set(ResourceSpec s) =>
        onChanged(field.copyWith(styleConfig: s.toConfig()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.tplResourceDisplay),
        Align(
          alignment: Alignment.centerLeft,
          child: TemplatePills<bool>(
            items: [
              (false, l10n.tplDisplayNumber, null),
              (true, l10n.tplDisplayBoxes, null),
            ],
            value: spec.boxes,
            onChanged: (v) => set(spec.copyWith(boxes: v)),
          ),
        ),
        const SizedBox(height: 12),
        ..._restSettings(
          l10n,
          spec.short,
          spec.long,
          (sh, lo) => set(spec.copyWith(short: sh, long: lo)),
        ),
        _Hint(l10n.tplResourceMaxHint),
      ],
    );
  }
}

/// Combat stats (DESIGN §8.6, D36): HP / Max HP — its label and rests;
/// it cannot be removed — then the values: number, dice or one card list,
/// each with its encounter settings.
class _CombatStatsSettings extends StatelessWidget {
  const _CombatStatsSettings({
    required this.field,
    required this.onChanged,
    required this.categories,
  });

  final FieldSchema field;
  final ValueChanged<FieldSchema> onChanged;

  /// A card list's possible targets.
  final List<EntityCategorySchema> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final spec = CombatStatsSpec.of(field);
    final values = spec.values;
    void set(CombatStatsSpec s) => onChanged(s.applyTo(field));
    void setValues(List<CombatValue> l) => set(spec.copyWith(values: l));

    Widget value(int i, CombatValue v) {
      void put(CombatValue n) => setValues([...values]..[i] = n);
      return _ListItem(
        key: ValueKey('combat-${v.key}'),
        boxed: true,
        onUp: i > 0 ? () => setValues(_moved(values, i, i - 1)) : null,
        onDown: i < values.length - 1
            ? () => setValues(_moved(values, i, i + 2))
            : null,
        onDelete: () => setValues([...values]..removeAt(i)),
        deleteLabel: l10n.btnDelete,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextSetting(
              label: l10n.tplFieldLabel,
              value: v.label,
              onChanged: (t) {
                if (t.trim().isNotEmpty) put(v.copyWith(label: t.trim()));
              },
            ),
            _KeyRow(v.key),
            _Dropdown<CombatValueType>(
              label: l10n.tplColumnType,
              value: v.type,
              items: {
                CombatValueType.number: l10n.tplStyleInteger,
                CombatValueType.dice: l10n.tplStyleDice,
                // One card list per block: it feeds Conditions.
                if (v.type == CombatValueType.cards || !spec.hasCards)
                  CombatValueType.cards: l10n.tplCombatCards,
              },
              onChanged: (t) => put(v.copyWith(type: t)),
            ),
            _Check(
              label: l10n.tplCombatEncounter,
              value: v.encounter,
              onChanged: (b) => put(v.copyWith(encounter: b)),
            ),
            if (v.encounter)
              _TextSetting(
                label: l10n.tplCombatWidth,
                hint: l10n.tplCombatWidthHint,
                value: v.width?.toString() ?? '',
                number: true,
                onChanged: (t) =>
                    put(v.copyWith(width: () => int.tryParse(t.trim()))),
              ),
            if (v.type == CombatValueType.number) ...[
              _Check(
                label: l10n.tplCombatEditable,
                value: v.editable,
                onChanged: (b) => put(v.copyWith(editable: b)),
              ),
            ],
            if (v.type == CombatValueType.cards) ...[
              _Label(l10n.tplTargets, hint: l10n.tplTargetsAny),
              Wrap(
                spacing: 16,
                children: [
                  for (final t in categories)
                    _Check(
                      label: t.name,
                      dense: true,
                      leading: TemplateColorDot(color: parseHexColor(t.color)),
                      value: v.targets.contains(t.slug),
                      onChanged: (on) => put(
                        v.copyWith(
                          targets: on
                              ? [...v.targets, t.slug]
                              : [...v.targets.where((x) => x != t.slug)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.tplCombatHp, hint: l10n.tplCombatHpHint),
        _TextSetting(
          label: l10n.tplFieldLabel,
          value: spec.hpLabel,
          onChanged: (t) {
            if (t.trim().isNotEmpty) set(spec.copyWith(hpLabel: t.trim()));
          },
        ),
        ..._restSettings(
          l10n,
          spec.short,
          spec.long,
          (sh, lo) => set(spec.copyWith(short: sh, long: lo)),
        ),
        _Label(l10n.tplCombatValues),
        for (final (i, v) in values.indexed) value(i, v),
        _AddLine(
          label: l10n.tplCombatAddValue,
          // The key is made once, from the first label (V3).
          onAdd: (label) => setValues([
            ...values,
            CombatValue(key: spec.keyFor(label), label: label),
          ]),
        ),
      ],
    );
  }
}

/// The template's fixed rows: one line of cells per row (card links belong
/// to the card), scrolling sideways when wide.
class _TemplateRows extends StatelessWidget {
  const _TemplateRows({required this.spec, required this.onChanged});

  final TableSpec spec;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  static double _width(TableColumnType t) => switch (t) {
    TableColumnType.text => 130,
    TableColumnType.choice => 110,
    TableColumnType.dice => 72,
    TableColumnType.number => 64,
    _ => 44,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final rows = spec.rows;
    final cols = [
      for (final c in spec.columns)
        if (c.type != TableColumnType.relation) c,
    ];
    void setCell(int i, String key, Object? v) {
      final r = {...rows[i]};
      if (v == null || v == '' || v == false) {
        r.remove(key);
      } else {
        r[key] = v;
      }
      onChanged([...rows]..[i] = r);
    }

    Widget cell(int i, TableColumn c) {
      final v = rows[i][c.key];
      final key = ValueKey('trow-${rows[i][tableRowId]}-${c.key}');
      return switch (c.type) {
        TableColumnType.check => Checkbox(
          key: key,
          value: v == true,
          visualDensity: VisualDensity.compact,
          onChanged: (b) => setCell(i, c.key, b == true),
        ),
        TableColumnType.choice => DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: key,
            value: c.options.contains(v) ? v as String : null,
            isExpanded: true,
            isDense: true,
            dropdownColor: palette.uiPopupBg,
            style: TextStyle(fontSize: 12, color: palette.tabActiveText),
            items: [
              for (final o in c.options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (s) => setCell(i, c.key, s),
          ),
        ),
        _ => TextFormField(
          key: key,
          initialValue: v == null ? '' : '$v',
          style: const TextStyle(fontSize: 12),
          keyboardType: c.type == TableColumnType.number
              ? const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                )
              : null,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          ),
          onChanged: (s) {
            final t = s.trim();
            setCell(
              i,
              c.key,
              c.type == TableColumnType.number
                  ? int.tryParse(t) ?? _parseDouble(t)
                  : t,
            );
          },
        ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cols.isNotEmpty && rows.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final c in cols)
                      SizedBox(
                        width: _width(c.type),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            c.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.sidebarLabelSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  SizedBox(
                    key: ValueKey('trow-${rows[i][tableRowId]}'),
                    width: cols.fold<double>(0, (s, c) => s + _width(c.type)) +
                        3 * 40,
                    child: _ListItem(
                      onUp: i > 0
                          ? () => onChanged(_moved(rows, i, i - 1))
                          : null,
                      onDown: i < rows.length - 1
                          ? () => onChanged(_moved(rows, i, i + 2))
                          : null,
                      onDelete: () => onChanged([...rows]..removeAt(i)),
                      deleteLabel: l10n.btnDelete,
                      child: Row(
                        children: [
                          for (final c in cols)
                            SizedBox(
                              width: _width(c.type),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: cell(i, c),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                onChanged([...rows, {tableRowId: nextTableRowId(rows)}]),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.tplAddRow),
          ),
        ),
      ],
    );
  }
}

/// A list entry with up / down / delete beside it ([boxed]: framed, for an
/// entry with several settings).
class _ListItem extends StatelessWidget {
  const _ListItem({
    super.key,
    required this.child,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
    required this.deleteLabel,
    this.boxed = false,
  });

  final Widget child;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onDelete;
  final String deleteLabel;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    Widget button(String tip, IconData icon, VoidCallback? onTap, [Color? c]) =>
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: tip,
            visualDensity: VisualDensity.compact,
            icon: Icon(icon, size: 18, color: c),
            color: palette.tabText,
            disabledColor: palette.featureCardBorder,
            onPressed: onTap,
          ),
        );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        button(l10n.tplMoveUp, Icons.keyboard_arrow_up, onUp),
        button(l10n.tplMoveDown, Icons.keyboard_arrow_down, onDown),
        button(
          deleteLabel,
          Icons.delete_outline,
          onDelete,
          palette.dangerBtnBg,
        ),
      ],
    );
    if (!boxed) return row;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: row,
    );
  }
}

/// A text input with an add button: adds the trimmed text and clears.
class _AddLine extends StatefulWidget {
  const _AddLine({required this.label, required this.onAdd});

  final String label;
  final ValueChanged<String> onAdd;

  @override
  State<_AddLine> createState() => _AddLineState();
}

class _AddLineState extends State<_AddLine> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add() {
    final v = _text.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: widget.label,
          icon: const Icon(Icons.add, size: 18),
          onPressed: _add,
        ),
      ),
      onSubmitted: (_) => _add(),
    ),
  );
}

double? _parseDouble(String s) =>
    double.tryParse(s.trim().replaceAll(',', '.'));

class _OptionsEditor extends StatefulWidget {
  const _OptionsEditor({required this.options, required this.onChanged});

  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<_OptionsEditor> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add() {
    final v = _text.text.trim();
    if (v.isEmpty || widget.options.contains(v)) return;
    widget.onChanged([...widget.options, v]);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in widget.options)
                _OptionPill(
                  text: o,
                  onRemove: () => widget.onChanged([
                    for (final x in widget.options)
                      if (x != o) x,
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: l10n.tplAddOption,
              suffixIcon: IconButton(
                tooltip: l10n.tplAddOption,
                icon: const Icon(Icons.add, size: 18),
                onPressed: _add,
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ small pieces

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: palette.tabText),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.tabText,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
      ),
    );
  }
}

/// The app's checkbox row: a small box and its label, the whole row
/// tappable. [dense] rows size to their label (for wraps).
class _Check extends StatelessWidget {
  const _Check({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.leading,
    this.trailing,
    this.dense = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: palette.tabActiveText),
        ),
        if (hint != null)
          Text(
            hint!,
            style: TextStyle(
              fontSize: 10,
              color: palette.sidebarLabelSecondary,
            ),
          ),
      ],
    );
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: palette.br,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            if (dense) Flexible(child: text) else Expanded(child: text),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 1…[count] as app pills (columns, width).
class _NumberPills extends StatelessWidget {
  const _NumberPills({
    required this.count,
    required this.value,
    required this.onChanged,
  });

  final int count;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TemplatePills<int>(
      items: [for (var n = 1; n <= count; n++) (n, '$n', null)],
      value: value.clamp(1, count),
      onChanged: onChanged,
    ),
  );
}

/// The pin colours, the current one if it is a custom colour, and a custom
/// colour button (HSV sliders).
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final current = value.toLowerCase();
    Widget dot(String hex) {
      final color = parseHexColor(hex);
      final on = hex.toLowerCase() == current;
      return Semantics(
        button: true,
        selected: on,
        label: hex,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onChanged(hex),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                width: on ? 2 : 1,
                color: on ? palette.tabActiveText : palette.featureCardBorder,
              ),
            ),
            child: on
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in kPinColorChoices) dot(hex),
        if (!kPinColorChoices.contains(current)) dot(value),
        Tooltip(
          message: l10n.mindMapCustomColor,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final picked = await showCustomColorDialog(
                context,
                initial: parseHexColor(value),
              );
              if (picked != null) onChanged(_hex(picked));
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.featureCardBorder),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 15,
                color: palette.tabText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The category's map pin icon: the current one in a small box; tap for
/// the pin icon set (names the world map draws, `mapIconFromName`).
class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.value,
    required this.onChanged,
    this.choices = kPinIconChoices,
    this.iconOf = mapIconFromName,
    this.tooltip,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, IconData)> choices;
  final IconData Function(String) iconOf;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return PopupMenuButton<String>(
      tooltip: tooltip ?? l10n.tplMapIcon,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 6 * 36,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (name, icon) in choices)
                  Tooltip(
                    message: name,
                    child: InkWell(
                      borderRadius: palette.br,
                      onTap: () => Navigator.pop(context, name),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: name == value
                              ? palette.featureCardAccent.withValues(
                                  alpha: 0.25,
                                )
                              : palette.featureCardBg,
                          borderRadius: palette.br,
                          border: Border.all(
                            color: name == value
                                ? palette.featureCardAccent
                                : palette.featureCardBorder,
                          ),
                        ),
                        child: Icon(icon, size: 18, color: palette.uiPopupText),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconOf(value), size: 16, color: palette.tabText),
            Icon(Icons.arrow_drop_down, size: 16, color: palette.tabText),
          ],
        ),
      ),
    );
  }
}

/// The player card's summary chips: each a field (or a Combat stats value,
/// or the user) with its icon, in order; added from what is not shown yet.
class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.card, required this.onChanged});

  final EntityCategorySchema card;
  final ValueChanged<List<SheetChip>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final chips = sheetChipsOf(card);
    final choices = [
      ...sheetChipChoices(card),
      (chip: (field: ownerChipField, sub: null, icon: ''), label: l10n.statUser),
    ];
    bool same(SheetChip a, SheetChip b) => a.field == b.field && a.sub == b.sub;
    String label(SheetChip c) =>
        choices.where((x) => same(x.chip, c)).firstOrNull?.label ?? c.field;
    final left = [
      for (final x in choices)
        if (!chips.any((c) => same(c, x.chip))) x,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in chips.indexed)
          _ListItem(
            key: ValueKey('chip-${c.field}-${c.sub}'),
            onUp: i > 0 ? () => onChanged(_moved(chips, i, i - 1)) : null,
            onDown: i < chips.length - 1
                ? () => onChanged(_moved(chips, i, i + 2))
                : null,
            onDelete: () => onChanged([...chips]..removeAt(i)),
            deleteLabel: l10n.btnDelete,
            child: Row(
              children: [
                _MapIconButton(
                  value: c.icon,
                  choices: kChipIconChoices,
                  iconOf: chipIconFromName,
                  tooltip: l10n.tplChipIcon,
                  onChanged: (icon) => onChanged([
                    for (final (j, x) in chips.indexed)
                      j == i ? (field: x.field, sub: x.sub, icon: icon) : x,
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label(c))),
              ],
            ),
          ),
        if (left.isNotEmpty)
          PopupMenuButton<SheetChip>(
            key: const ValueKey('chip_add'),
            tooltip: l10n.btnAdd,
            position: PopupMenuPosition.under,
            onSelected: (c) => onChanged([
              ...chips,
              (field: c.field, sub: c.sub, icon: 'star'),
            ]),
            itemBuilder: (_) => [
              for (final x in left)
                PopupMenuItem(value: x.chip, child: Text(x.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18),
                  const SizedBox(width: 4),
                  Text(l10n.btnAdd),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: palette.sidebarFilterBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 12, color: palette.tabText)),
          InkWell(
            borderRadius: palette.br,
            onTap: onRemove,
            child: Tooltip(
              message: l10n.btnDelete,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A text input that owns its controller; [value] only lands in it while
/// the user is not typing there. Border and fill come from the theme.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.number = false,
    this.hint,
    this.helper,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final bool number;
  final String? hint;

  /// Shown under the input.
  final String? helper;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _text = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_TextSetting old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _text.text) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _text,
      focusNode: _focus,
      maxLines: widget.maxLines,
      minLines: 1,
      style: const TextStyle(fontSize: 13),
      keyboardType: widget.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
      ),
      onChanged: widget.onChanged,
    ),
  );
}

/// A labelled, controlled dropdown (the value always follows [value]),
/// drawn like the app's `DropdownButtonFormField`s.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            dropdownColor: palette.uiPopupBg,
            borderRadius: palette.br,
            style: TextStyle(fontSize: 13, color: palette.tabActiveText),
            items: [
              for (final e in items.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Move up / down buttons: every drag reorder also works without dragging
/// (WCAG 2.2 dragging movements; keyboard too).
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.onUp, required this.onDown});

  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    Widget button(String tooltip, IconData icon, VoidCallback? onPressed) =>
        IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20),
          color: palette.tabText,
          disabledColor: palette.featureCardBorder,
          onPressed: onPressed,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.tplOrder,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.tabText,
              ),
            ),
          ),
          button(l10n.tplMoveUp, Icons.keyboard_arrow_up, onUp),
          button(l10n.tplMoveDown, Icons.keyboard_arrow_down, onDown),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.delete_outline, size: 18, color: palette.dangerBtnBg),
        label: Text(label, style: TextStyle(color: palette.dangerBtnBg)),
      ),
    );
  }
}
