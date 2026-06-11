import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../../../theme/dm_tool_colors.dart';
import '../widgets/template_builtin_banner.dart';
import '../widgets/template_category_pane.dart';
import 'template_fields_page.dart';

/// Phone landing page of the Template Editor (roadmap §1.5 stacked layout).
///
/// The first page of the editor's stacked flow: Categories → [TemplateFieldsPage]
/// → field edit. Tapping a category pushes the fields page on the navigator;
/// system back returns here, then leaves the editor.
class TemplateCategoriesPage extends ConsumerWidget {
  final String rootTitle;
  final Future<void> Function() onCopyToEdit;
  final Future<void> Function() onSave;

  const TemplateCategoriesPage({
    super.key,
    required this.rootTitle,
    required this.onCopyToEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(templateEditorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                state.schema?.name ?? rootTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.isDirty)
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
        actions: [
          if (!state.isBuiltin)
            IconButton(
              tooltip: 'Save',
              icon: state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed:
                  (state.isDirty && !state.isSaving) ? () => onSave() : null,
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.isBuiltin)
            TemplateBuiltinBanner(
              palette: palette,
              onCopy: () => onCopyToEdit(),
            ),
          Expanded(
            child: TemplateCategoryPane(
              onCategoryTap: (_) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TemplateFieldsPage(),
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
