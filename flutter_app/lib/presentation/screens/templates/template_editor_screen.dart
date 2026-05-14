import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/schema/world_schema.dart';
import '../hub/template_editor.dart';

/// Read-only template inspector screen. Wraps [TemplateEditor] with a
/// scaffold + close button. Templates are no longer editable; this screen
/// is reachable from Templates tab → "View".
class TemplateEditorScreen extends ConsumerWidget {
  final WorldSchema initial;

  const TemplateEditorScreen({super.key, required this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
