import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../widgets/template_field_list_pane.dart';
import 'template_field_edit_page.dart';

/// Phone page 2 — the field list for the selected category (roadmap §1.5).
/// Pushed by [TemplateCategoriesPage]; tapping a field pushes
/// [TemplateFieldEditPage]. The AppBar owns the title, so the in-pane header is
/// hidden.
class TemplateFieldsPage extends ConsumerWidget {
  const TemplateFieldsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateEditorProvider);
    final category = state.selectedCategory;

    return Scaffold(
      appBar: AppBar(
        title: Text(category?.name ?? 'Fields'),
      ),
      body: TemplateFieldListPane(
        showHeader: false,
        onFieldTap: (_) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TemplateFieldEditPage(),
            ),
          );
        },
      ),
    );
  }
}
