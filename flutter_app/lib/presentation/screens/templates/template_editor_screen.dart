import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/template_editor_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/resizable_split.dart';
import 'phone/template_categories_page.dart';
import 'widgets/template_builtin_banner.dart';
import 'widgets/template_category_pane.dart';
import 'widgets/template_field_inspector.dart';
import 'widgets/template_field_list_pane.dart';

/// Responsive Template Editor shell (roadmap §1.5).
///
/// PR-1.5 lands the **read-only** layout contract every Phase 2 CRUD component
/// plugs into:
///
/// * **Desktop (≥1200)** — 3-pane: fixed 240px category list │ `ResizableSplit`
///   between the field list and the field inspector.
/// * **Tablet (600–1199)** — 2-pane: a master pane that drills category list →
///   field list in place │ `ResizableSplit` to the inspector.
/// * **Phone (<600)** — stacked navigation via a nested `Navigator`
///   (Categories → Fields → Field edit; system back works).
///
/// The app-bar Save button + dirty dot are wired to [templateEditorProvider]
/// (disabled until Phase 2 mutators flip `dirty`). Built-in templates show the
/// read-only banner with an inline Copy-to-edit action.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final WorldSchema initial;

  const TemplateEditorScreen({super.key, required this.initial});

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  @override
  void initState() {
    super.initState();
    // Load the incoming schema into the editor controller after the first
    // frame so we never mutate a provider during the initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(templateEditorProvider.notifier).load(
            widget.initial,
            isBuiltin: _isBuiltin(widget.initial),
          );
    });
  }

  @override
  void didUpdateWidget(covariant TemplateEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial.schemaId != widget.initial.schemaId) {
      ref.read(templateEditorProvider.notifier).load(
            widget.initial,
            isBuiltin: _isBuiltin(widget.initial),
          );
    }
  }

  static bool _isBuiltin(WorldSchema schema) =>
      schema.schemaId == builtinDnd5eV3SchemaId;

  /// Copies the open (built-in) template into an editable user copy and reopens
  /// the editor on that copy. Mirrors the library tab's copy-name suggestion so
  /// the new copy never shadows the built-in.
  Future<void> _copyToEdit() async {
    final schema = ref.read(templateEditorProvider).schema;
    if (schema == null) return;
    final repo = ref.read(templateRepositoryProvider);
    final base = '${schema.name} (Copy)';
    var name = base;
    var n = 2;
    while (await repo.nameExists(name)) {
      name = '${schema.name} (Copy $n)';
      n++;
    }
    try {
      final copy = await repo.copy(source: schema, newName: name);
      ref.invalidate(templateLibraryProvider);
      if (!mounted) return;
      ref
          .read(templateEditorProvider.notifier)
          .load(copy, isBuiltin: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied to "$name" — now editable.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e')),
      );
    }
  }

  Future<void> _save() async {
    final result = await ref.read(templateEditorProvider.notifier).save();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case TemplateSaveResult.saved:
        messenger.showSnackBar(
          const SnackBar(content: Text('Template saved.')),
        );
      case TemplateSaveResult.invalid:
        messenger.showSnackBar(
          const SnackBar(content: Text('Fix validation errors before saving.')),
        );
      case TemplateSaveResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('Save failed.')),
        );
      case TemplateSaveResult.noop:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(templateEditorProvider);
    final screen = getScreenType(context);

    // Phone: a self-contained nested-Navigator stack with its own per-page
    // app bars (system back pops the stack).
    if (screen == ScreenType.phone) {
      return TemplateCategoriesPage(
        rootTitle: state.schema?.name ?? widget.initial.name,
        onCopyToEdit: _copyToEdit,
        onSave: _save,
      );
    }

    final isDirty = state.isDirty;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                state.schema?.name ?? widget.initial.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDirty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.featureCardAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (state.isBuiltin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: _copyToEdit,
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('Copy to edit'),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: FilledButton.icon(
                  onPressed:
                      (isDirty && !state.isSaving) ? _save : null,
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.isBuiltin)
            TemplateBuiltinBanner(palette: palette, onCopy: _copyToEdit),
          Expanded(
            child: screen == ScreenType.desktop
                ? _DesktopLayout(palette: palette)
                : _TabletLayout(palette: palette),
          ),
        ],
      ),
    );
  }
}

/// Desktop ≥1200 — 3-pane.
class _DesktopLayout extends StatelessWidget {
  final DmToolColors palette;

  const _DesktopLayout({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 240, child: TemplateCategoryPane()),
        VerticalDivider(width: 1, color: palette.sidebarDivider),
        Expanded(
          child: ResizableSplit(
            palette: palette,
            initialRatio: 0.45,
            minFirstSize: 220,
            minSecondSize: 280,
            first: const TemplateFieldListPane(),
            second: const TemplateFieldInspector(),
          ),
        ),
      ],
    );
  }
}

/// Tablet 600–1199 — 2-pane: a master that drills category → field list in
/// place, `ResizableSplit` to the inspector.
class _TabletLayout extends StatefulWidget {
  final DmToolColors palette;

  const _TabletLayout({required this.palette});

  @override
  State<_TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends State<_TabletLayout> {
  bool _showFields = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final master = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(_showFields ? 0.15 : -0.15, 0),
          end: Offset.zero,
        ).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _showFields
          ? TemplateFieldListPane(
              key: const ValueKey('fields'),
              onBack: () => setState(() => _showFields = false),
            )
          : TemplateCategoryPane(
              key: const ValueKey('categories'),
              onCategoryTap: (EntityCategorySchema _) =>
                  setState(() => _showFields = true),
            ),
    );

    return ResizableSplit(
      palette: palette,
      initialRatio: 0.4,
      minFirstSize: 240,
      minSecondSize: 280,
      first: master,
      second: const TemplateFieldInspector(),
    );
  }
}
