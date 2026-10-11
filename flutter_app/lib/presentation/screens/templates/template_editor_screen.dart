import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/free_template.dart';
import '../hub/template_editor.dart';
import 'free_template_editor.dart';

/// Templates tab → View / Edit. A free template opens in the editor; the
/// built-in one in the read-only inspector ([TemplateEditor]), unchanged
/// (docs/free-template/ROADMAP.md R8).
class TemplateEditorScreen extends ConsumerWidget {
  final WorldSchema initial;

  const TemplateEditorScreen({super.key, required this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFreeTemplate(initial)) {
      return FreeTemplateEditorScreen(initial: initial);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(initial.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: TemplateEditor(initial: initial),
    );
  }
}
