import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/free_template.dart' show guideOf, isBuiltinTemplate;
import '../../../domain/services/template_edit.dart'
    show missingOwnFields, presetUses, presetsOf;
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../database/database_screen.dart' show parseHexColor;
import 'template_card_preview.dart';
import 'template_edit_controller.dart';
import 'template_layout_canvas.dart';
import 'template_settings_forms.dart';
import 'template_styles.dart';

/// Below this width the three panels do not fit; the editor becomes the
/// phone flow of nested pages (DESIGN §7.6).
const _threePanelMinWidth = 1000.0;

/// The free template editor (docs/free-template/ROADMAP.md Faz 2). Desktop:
/// template · layout · settings panels over a palette strip (DESIGN §7.5).
/// Narrow: template page → category page → settings sheet. Edits save on
/// their own (V26).
class FreeTemplateEditorScreen extends ConsumerStatefulWidget {
  const FreeTemplateEditorScreen({super.key, required this.initial});

  final WorldSchema initial;

  @override
  ConsumerState<FreeTemplateEditorScreen> createState() =>
      _FreeTemplateEditorScreenState();
}

class _FreeTemplateEditorScreenState
    extends ConsumerState<FreeTemplateEditorScreen> {
  late final TemplateEditController _c;

  @override
  void initState() {
    super.initState();
    final id = widget.initial.schemaId;
    final latest =
        ref
            .read(userTemplatesProvider)
            .valueOrNull
            ?.where((t) => t.schemaId == id)
            .firstOrNull ??
        widget.initial;
    _c = TemplateEditController(
      latest,
      ref.read(userTemplatesProvider.notifier).save,
      readOnly: isBuiltinTemplate(latest),
    );
    // Desktop opens on the player card (E2.1).
    final first =
        latest.categories.where((c) => c.isPlayerCard == true).firstOrNull ??
        latest.categories.firstOrNull;
    if (first != null) _c.openCategory(first.categoryId);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _threePanelMinWidth;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => wide ? _desktop(context) : _phoneHome(context),
    );
  }

  Widget _desktop(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final cat = _c.category;
    final Widget center;
    if (cat == null) {
      center = Center(
        child: Text(
          l10n.tplNoCategory,
          style: TextStyle(color: palette.sidebarLabelSecondary),
        ),
      );
    } else {
      center = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryBar(controller: _c, category: cat),
          Expanded(
            child: _c.preview
                ? TemplateCardPreview(category: cat)
                : TemplateLayoutCanvas(controller: _c, compact: false),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_c.schema.name),
        actions: [
          _SaveStatus(controller: _c, compact: false),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _OwnFieldWarning(controller: _c),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: _TemplateNav(
                    controller: _c,
                    compact: false,
                    onInfo: _c.selectInfo,
                    onCategory: _c.openCategory,
                    onPreset: _c.selectPreset,
                    onGuide: _c.selectGuide,
                    onEncounter: _c.selectEncounter,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: center),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 340,
                  child: TemplateSettingsPanel(controller: _c),
                ),
              ],
            ),
          ),
          if (cat != null && !_c.preview) ...[
            TemplatePaletteStrip(
              presets: presetsOf(_c.schema),
              onAdd: (d) =>
                  addFromPalette(context, _c, d, groupId: _c.targetGroupId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _phoneHome(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_c.schema.name),
        actions: [_SaveStatus(controller: _c, compact: true)],
      ),
      body: Column(
        children: [
          _OwnFieldWarning(controller: _c),
          Expanded(child: _phoneNav(context)),
        ],
      ),
    );
  }

  Widget _phoneNav(BuildContext context) {
    final l10n = L10n.of(context)!;
    return _TemplateNav(
        controller: _c,
        compact: true,
        onInfo: () {
          _c.selectInfo();
          _push(
            context,
            alive: () => true,
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(l10n.tplInfo),
                actions: [_SaveStatus(controller: _c, compact: true)],
              ),
              body: TemplateInfoForm(controller: _c),
            ),
          );
        },
        onCategory: (id) {
          _c.openCategory(id);
          _push(
            context,
            alive: () => _c.category != null,
            builder: (_) => _PhoneCategoryPage(controller: _c),
          );
        },
        onGuide: () {
          _c.selectGuide();
          _push(
            context,
            alive: () => true,
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(l10n.tplGuide),
                actions: [_SaveStatus(controller: _c, compact: true)],
              ),
              body: TemplateGuideForm(controller: _c),
            ),
          );
        },
        onEncounter: () {
          _c.selectEncounter();
          _push(
            context,
            alive: () => true,
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(l10n.tplEncounter),
                actions: [_SaveStatus(controller: _c, compact: true)],
              ),
              body: TemplateEncounterForm(controller: _c),
            ),
          );
        },
        onPreset: (id) {
          _c.selectPreset(id);
          _push(
            context,
            alive: () => _c.preset != null,
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(_c.preset!.label),
                actions: [_SaveStatus(controller: _c, compact: true)],
              ),
              body: TemplatePresetForm(controller: _c),
            ),
          );
        },
      );
  }

  void _push(
    BuildContext context, {
    required bool Function() alive,
    required WidgetBuilder builder,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _Live(controller: _c, alive: alive, builder: builder),
      ),
    );
  }
}

/// Rebuilds [builder] on every edit; removes its own route once what it
/// shows is gone (a deleted field, group or category).
class _Live extends StatefulWidget {
  const _Live({
    required this.controller,
    required this.alive,
    required this.builder,
  });

  final TemplateEditController controller;
  final bool Function() alive;
  final WidgetBuilder builder;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      if (widget.alive()) return widget.builder(context);
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final route = mounted ? ModalRoute.of(context) : null;
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        });
      }
      return const SizedBox.shrink();
    },
  );
}

/// Phone: one category's layout; tapping a field or group opens its
/// settings in a bottom sheet, "+ Add" opens the style sheet.
class _PhoneCategoryPage extends StatelessWidget {
  const _PhoneCategoryPage({required this.controller});

  final TemplateEditController controller;

  void _sheet(
    BuildContext context,
    bool Function() alive,
    Widget Function() form,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => PrimaryScrollController(
          controller: scroll,
          child: _Live(
            controller: controller,
            alive: alive,
            builder: (_) => form(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final c = controller;
    final cat = c.category!;
    return Scaffold(
      appBar: AppBar(
        title: Text(cat.name),
        actions: [
          _SaveStatus(controller: c, compact: true),
          IconButton(
            tooltip: c.preview ? l10n.tplLayout : l10n.tplPreview,
            icon: Icon(
              c.preview
                  ? Icons.view_agenda_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: c.togglePreview,
          ),
          IconButton(
            tooltip: l10n.tplCategorySettings,
            icon: const Icon(Icons.tune),
            onPressed: () {
              c.selectGroup(null);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _Live(
                    controller: c,
                    alive: () => c.category != null,
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(l10n.tplCategorySettings)),
                      body: TemplateCategoryForm(controller: c),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _OwnFieldWarning(controller: c),
          Expanded(
            child: c.preview
                ? TemplateCardPreview(category: cat)
                : TemplateLayoutCanvas(
                    controller: c,
                    compact: true,
                    onOpenField: (_) => _sheet(
                      context,
                      () => c.field != null,
                      () => TemplateFieldForm(controller: c),
                    ),
                    onOpenGroup: (_) => _sheet(
                      context,
                      () => c.group != null,
                      () => TemplateGroupForm(controller: c),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: c.preview
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final d = await showStylePickerSheet(
                  context,
                  presets: presetsOf(c.schema),
                );
                if (d != null && context.mounted) {
                  await addFromPalette(context, c, d, groupId: c.targetGroupId);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.tplAddField),
            ),
    );
  }
}

/// Desktop: the open category's name over the canvas, with the layout /
/// preview pills and its settings.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.controller, required this.category});

  final TemplateEditController controller;
  final EntityCategorySchema category;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.featureCardBorder)),
      ),
      child: Row(
        children: [
          TemplateColorDot(color: parseHexColor(category.color), size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
          ),
          TemplatePills<bool>(
            items: [
              (false, l10n.tplLayout, Icons.view_agenda_outlined),
              (true, l10n.tplPreview, Icons.visibility_outlined),
            ],
            value: c.preview,
            onChanged: (v) {
              if (v != c.preview) c.togglePreview();
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.tplCategorySettings,
            isSelected: c.panel == TemplatePanel.category,
            icon: const Icon(Icons.tune, size: 20),
            selectedIcon: Icon(
              Icons.tune,
              size: 20,
              color: palette.featureCardAccent,
            ),
            onPressed: () => c.selectGroup(null),
          ),
        ],
      ),
    );
  }
}

/// Template details, the player card and its guide (DESIGN §13.2), the
/// presets (§9), then the other categories in sidebar order (drag to
/// reorder).
class _TemplateNav extends StatelessWidget {
  const _TemplateNav({
    required this.controller,
    required this.compact,
    required this.onInfo,
    required this.onCategory,
    required this.onPreset,
    required this.onGuide,
    required this.onEncounter,
  });

  final TemplateEditController controller;
  final bool compact;
  final VoidCallback onInfo;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onPreset;
  final VoidCallback onGuide;
  final VoidCallback onEncounter;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = controller;
    final players = [
      for (final x in c.schema.categories)
        if (x.isPlayerCard == true) x,
    ];
    final others = [
      for (final x in c.schema.categories)
        if (x.isPlayerCard != true) x,
    ];

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavLabel(text: l10n.tplSectionTemplate),
          _NavRow(
            nav: this,
            selected: !compact && c.panel == TemplatePanel.info,
            leading: Icon(Icons.info_outline, size: 16, color: palette.tabText),
            title: l10n.tplInfo,
            onTap: onInfo,
          ),
          _NavRow(
            key: const ValueKey('nav-encounter'),
            nav: this,
            selected: !compact && c.panel == TemplatePanel.encounter,
            leading: Icon(
              Icons.sports_kabaddi_outlined,
              size: 16,
              color: palette.tabText,
            ),
            title: l10n.tplEncounter,
            onTap: onEncounter,
          ),
          for (final pc in players) ...[
            _CategoryTile(nav: this, category: pc, tag: l10n.tplPlayerCard),
            _NavRow(
              key: const ValueKey('nav-guide'),
              nav: this,
              selected: !compact && c.panel == TemplatePanel.guide,
              leading: Icon(
                Icons.signpost_outlined,
                size: 16,
                color: palette.tabText,
              ),
              title: l10n.tplGuide,
              count: '${guideOf(pc).length}',
              countTooltip: l10n.tplGuideSteps,
              onTap: onGuide,
            ),
          ],
          _NavLabel(
            text: l10n.tplPresets,
            action: IconButton(
              tooltip: l10n.tplAddPreset,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () async {
                if (await addPresetWithLabel(context, c) && compact) {
                  onPreset(c.presetId!);
                }
              },
            ),
          ),
          if (presetsOf(c.schema).isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Text(
                l10n.tplPresetHint,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          for (final p in presetsOf(c.schema))
            _NavRow(
              key: ValueKey('nav-preset-${p.fieldId}'),
              nav: this,
              selected:
                  !compact &&
                  c.panel == TemplatePanel.preset &&
                  c.presetId == p.fieldId,
              leading: Icon(
                Icons.bookmark_outline,
                size: 16,
                color: palette.tabText,
              ),
              title: p.label,
              count: '${presetUses(c.schema, p.fieldId).length}',
              countTooltip: l10n.tplPresetUsedIn,
              onTap: () => onPreset(p.fieldId),
            ),
          _NavLabel(
            text: l10n.tplCategories,
            action: IconButton(
              tooltip: l10n.tplAddCategory,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () async {
                if (await addCategoryWithName(context, c) && compact) {
                  onCategory(c.categoryId!);
                }
              },
            ),
          ),
        ],
      ),
      itemCount: others.length,
      itemBuilder: (context, i) => _CategoryTile(
        key: ValueKey(others[i].categoryId),
        nav: this,
        category: others[i],
        index: i,
      ),
      onReorderItem: (from, to) {
        final ids = [for (final x in others) x.categoryId];
        ids.insert(to, ids.removeAt(from));
        c.reorderCategories([for (final p in players) p.categoryId, ...ids]);
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.nav,
    required this.category,
    this.index,
    this.tag,
  });

  final _TemplateNav nav;
  final EntityCategorySchema category;

  /// Position in the reorderable list; null for the pinned player card.
  final int? index;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = nav.controller;
    final row = _NavRow(
      nav: nav,
      selected:
          !nav.compact &&
          c.panel != TemplatePanel.info &&
          c.panel != TemplatePanel.preset &&
          c.panel != TemplatePanel.guide &&
          c.panel != TemplatePanel.encounter &&
          c.categoryId == category.categoryId,
      // The pinned player card shows what it is where the others have
      // their drag handle.
      leading: index == null
          ? Tooltip(
              message: tag ?? '',
              child: Icon(
                Icons.person_outline,
                size: 16,
                color: palette.sidebarLabelSecondary,
              ),
            )
          : ReorderableDragStartListener(
              index: index!,
              child: Tooltip(
                message: l10n.tplDragHandle,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
            ),
      dot: parseHexColor(category.color),
      title: category.name,
      count: '${category.fields.length}',
      countTooltip: l10n.templateFieldCount('${category.fields.length}'),
      onTap: () => nav.onCategory(category.categoryId),
    );
    // Long press anywhere on the row drags it (touch).
    return index == null
        ? row
        : ReorderableDelayedDragStartListener(index: index!, child: row);
  }
}

/// A nav row as the codex sidebar draws one: colour dot, name, a count on
/// the right; the selected row tinted.
class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.nav,
    required this.selected,
    required this.leading,
    required this.title,
    required this.onTap,
    this.dot,
    this.count,
    this.countTooltip,
  });

  final _TemplateNav nav;
  final bool selected;
  final Widget leading;
  final String title;
  final VoidCallback onTap;
  final Color? dot;
  final String? count;
  final String? countTooltip;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final accent = dot ?? palette.featureCardAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: palette.br,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: nav.compact ? 12 : 8,
          ),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : null,
            borderRadius: palette.br,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 6),
              if (dot != null) ...[
                TemplateColorDot(color: dot!),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.tabActiveText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: countTooltip ?? '',
                  child: Text(
                    count!,
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
              ],
              if (nav.compact)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: palette.sidebarLabelSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 16, action == null ? 8 : 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Saved / saving / not saved; a failed save retries on tap.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.controller, required this.compact});

  final TemplateEditController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final c = controller;
    final failed = c.saveState == TemplateSaveState.failed;
    final (icon, text, color) = c.readOnly
        ? (Icons.lock_outline, l10n.templateBuiltinReadOnly,
            palette.sidebarLabelSecondary)
        : switch (c.saveState) {
      TemplateSaveState.saved => (
        Icons.cloud_done_outlined,
        l10n.tplSaved,
        palette.uiAutosaveTextSaved,
      ),
      TemplateSaveState.failed => (
        Icons.error_outline,
        l10n.tplSaveFailed,
        palette.dangerBtnBg,
      ),
      _ => (Icons.sync, l10n.tplSaving, palette.uiAutosaveTextEditing),
    };
    final content = compact
        ? Icon(icon, size: 20, color: color)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(text, style: TextStyle(fontSize: 12, color: color)),
            ],
          );
    return Tooltip(
      message: failed ? '$text — ${c.saveError}' : text,
      child: failed
          ? TextButton(onPressed: c.flush, child: content)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: content),
            ),
    );
  }
}

/// DESIGN §10.1 (D34): what the template uses needs a field the player card
/// lacks — the Level for a Level table, the Pool for Grants. Stays until
/// it is added; [Add] puts it in the player card's first group.
class _OwnFieldWarning extends StatelessWidget {
  const _OwnFieldWarning({required this.controller});

  final TemplateEditController controller;

  @override
  Widget build(BuildContext context) {
    final missing = missingOwnFields(controller.schema);
    if (missing.isEmpty) return const SizedBox.shrink();
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      width: double.infinity,
      color: palette.featureCardAccent.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          for (final t in missing)
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: palette.featureCardAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tplNeedsOwnField(styleLabel(l10n, t)),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  key: ValueKey('own_field_add_${t.name}'),
                  onPressed: () =>
                      controller.addOwnField(t, styleLabel(l10n, t)),
                  child: Text(l10n.btnAdd),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
