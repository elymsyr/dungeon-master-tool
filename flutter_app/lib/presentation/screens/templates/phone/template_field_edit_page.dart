import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/template_editor_provider.dart';
import '../widgets/template_field_inspector.dart';

/// Phone page 3 — the field detail / edit surface (roadmap §1.5).
///
/// Full-screen so the Phase 2.2 `typeConfig` forms have keyboard room. In
/// PR-1.5 it shows the read-only field inspector; the editing forms mount here
/// later. The AppBar owns the field title.
class TemplateFieldEditPage extends ConsumerWidget {
  const TemplateFieldEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateEditorProvider);
    final field = state.selectedField;
    final title = field == null
        ? 'Field'
        : (field.label.isEmpty ? field.fieldKey : field.label);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const TemplateFieldInspector(fieldOnly: true),
    );
  }
}
