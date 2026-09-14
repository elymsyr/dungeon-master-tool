import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../data/services/entity_parser.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../l10n/app_localizations.dart';

/// Dialog for importing entities from JSON data.
class ImportDialog extends ConsumerStatefulWidget {
  final WorldSchema schema;

  const ImportDialog({required this.schema, super.key});

  static Future<void> show(BuildContext context, WorldSchema schema) {
    return showDialog(
      context: context,
      builder: (_) => ImportDialog(schema: schema),
    );
  }

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  final _jsonController = TextEditingController();
  String _selectedSlug = 'npc';
  String? _error;
  bool _importing = false;

  List<EntityCategorySchema> get _categories =>
      widget.schema.categories.where((c) => !c.isArchived).toList();

  @override
  void initState() {
    super.initState();
    if (_categories.isNotEmpty) _selectedSlug = _categories.first.slug;
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _doImport() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please paste JSON data');
      return;
    }

    setState(() {
      _error = null;
      _importing = true;
    });

    try {
      dynamic parsed;
      try {
        parsed = jsonDecode(text);
      } catch (e) {
        setState(() {
          _error = 'Invalid JSON: $e';
          _importing = false;
        });
        return;
      }

      final entityNotifier = ref.read(entityProvider.notifier);
      int count = 0;

      if (parsed is List) {
        for (final item in parsed) {
          if (item is Map<String, dynamic>) {
            final entity = EntityParser.parseFromExternal(
                item, _selectedSlug, widget.schema);
            entityNotifier.update(entity);
            count++;
          }
        }
      } else if (parsed is Map<String, dynamic>) {
        final entity = EntityParser.parseFromExternal(
            parsed, _selectedSlug, widget.schema);
        entityNotifier.update(entity);
        count = 1;
      }

      setState(() => _importing = false);

      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(L10n.of(context)!.importEntitiesDone(count))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = 'Import failed: $e';
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.of(context)!.importEntityTitle),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selection
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              initialValue: _selectedSlug,
              decoration: InputDecoration(
                labelText: L10n.of(context)!.lblCategory,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: _categories
                  .map((c) =>
                      DropdownMenuItem(value: c.slug, child: Text(c.name)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedSlug = v ?? _selectedSlug),
            ),
            const SizedBox(height: 12),
            // JSON input
            Text(L10n.of(context)!.importPasteJson,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: _jsonController,
              maxLines: 10,
              minLines: 6,
              decoration: InputDecoration(
                hintText: '{"name": "Goblin", "cr": "1/4", ...}',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _error,
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.of(context)!.importJsonHelp,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context)!.btnCancel)),
        FilledButton(
          onPressed: _importing ? null : _doImport,
          child: _importing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(L10n.of(context)!.btnImport),
        ),
      ],
    );
  }
}
