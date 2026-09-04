import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/template_mechanics.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../hub/template_editor.dart';

/// Template ekranı. Built-in şema için read-only gezgin; kullanıcı
/// template'leri için editör — değişiklikler `custom_templates` tablosuna
/// kaydedilir.
///
/// Kaydetme kartın kendisini değil kütüphaneyi günceller: bu template'ten
/// önce yaratılmış dünyalar kendi şema kopyalarını taşır ve etkilenmez.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final WorldSchema initial;

  const TemplateEditorScreen({super.key, required this.initial});

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late WorldSchema _schema = widget.initial;
  bool _dirty = false;
  bool _saving = false;

  bool get _readOnly => schemaHasMechanics(widget.initial);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(templateLibraryProvider).save(_schema);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Template saved.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_schema.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_readOnly)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Text('Read-only', style: TextStyle(fontSize: 12)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton.icon(
                onPressed: (_dirty && !_saving) ? _save : null,
                icon: const Icon(Icons.save, size: 16),
                label: Text(_dirty ? 'Save' : 'Saved'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_readOnly)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                'No automatic mechanics run on this template. Character '
                'resolution, the creation wizard and SRD content are built-in '
                'only — here, fields are pure data.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: TemplateEditor(
              initial: _schema,
              onChanged: _readOnly
                  ? null
                  : (s) => setState(() {
                        _schema = s;
                        _dirty = true;
                      }),
            ),
          ),
        ],
      ),
    );
  }
}
