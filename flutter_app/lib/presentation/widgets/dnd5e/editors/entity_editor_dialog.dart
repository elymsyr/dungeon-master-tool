import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../data/database/database_provider.dart';

/// Generic typed-entity editor. Loads the current row by id, renders a
/// form (name + category-specific column hints + raw body JSON textarea),
/// and on save forks through [saveEditedEntity] so package-owned rows
/// clone into the active campaign as `hb:<cid>:<uuid>` instead of being
/// mutated in place.
///
/// The dialog is intentionally minimalist — the goal is to unblock
/// copy-on-write editing for every typed category without having to build
/// 9 bespoke forms first. Category-specific editors can replace this via
/// the `showEntityEditor` dispatcher below as they land.
class EntityEditorDialog extends ConsumerStatefulWidget {
  final String entityId;
  final String categorySlug;

  /// Called with the id of the written row after save. Callers use this to
  /// re-open the card on the new `hb:` id after a fork.
  final void Function(String writtenId)? onSaved;

  const EntityEditorDialog({
    required this.entityId,
    required this.categorySlug,
    this.onSaved,
    super.key,
  });

  @override
  ConsumerState<EntityEditorDialog> createState() =>
      _EntityEditorDialogState();
}

class _EntityEditorDialogState extends ConsumerState<EntityEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _itemTypeCtrl = TextEditingController();
  final _rarityCtrl = TextEditingController();
  final _parentClassCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    _levelCtrl.dispose();
    _schoolCtrl.dispose();
    _itemTypeCtrl.dispose();
    _rarityCtrl.dispose();
    _parentClassCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final db = ref.read(appDatabaseProvider);
    String? name;
    String? body;
    switch (widget.categorySlug) {
      case 'spell':
        final row = await db.dnd5eContentDao.getSpell(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
          _levelCtrl.text = row.level.toString();
          _schoolCtrl.text = row.schoolId;
        }
        break;
      case 'monster':
      case 'npc':
        final row = await db.dnd5eContentDao.getMonster(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.statBlockJson;
        }
        break;
      case 'item':
      case 'equipment':
        final row = await db.dnd5eContentDao.getItem(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
          _itemTypeCtrl.text = row.itemType;
          _rarityCtrl.text = row.rarityId ?? '';
        }
        break;
      case 'feat':
        final row = await db.dnd5eContentDao.getFeat(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
        }
        break;
      case 'background':
        final row = await db.dnd5eContentDao.getBackground(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
        }
        break;
      case 'race':
      case 'species':
        final row = await db.dnd5eContentDao.getSpecies(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
        }
        break;
      case 'subclass':
        final row = await db.dnd5eContentDao.getSubclass(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
          _parentClassCtrl.text = row.parentClassId;
        }
        break;
      case 'class':
        final row =
            await db.dnd5eContentDao.getClassProgression(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
        }
        break;
      case 'condition':
        final row = await db.dnd5eContentDao.getCondition(widget.entityId);
        if (row != null) {
          name = row.name;
          body = row.bodyJson;
        }
        break;
    }
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name ?? '';
      _bodyCtrl.text = _prettyJson(body ?? '{}');
      _loaded = true;
    });
  }

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    Map<String, Object?> parsed;
    try {
      final decoded = jsonDecode(_bodyCtrl.text);
      if (decoded is! Map) {
        throw const FormatException('Body JSON must be an object');
      }
      parsed = decoded.cast<String, Object?>();
    } on FormatException catch (e) {
      setState(() => _error = 'Invalid JSON: ${e.message}');
      return;
    }

    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) {
      setState(() => _error = 'No active campaign');
      return;
    }

    final extras = <String, Object?>{};
    if (widget.categorySlug == 'spell') {
      extras['level'] = int.tryParse(_levelCtrl.text) ?? 0;
      extras['schoolId'] =
          _schoolCtrl.text.trim().isEmpty ? null : _schoolCtrl.text.trim();
    } else if (widget.categorySlug == 'item' ||
        widget.categorySlug == 'equipment') {
      extras['itemType'] =
          _itemTypeCtrl.text.trim().isEmpty ? 'gear' : _itemTypeCtrl.text.trim();
      extras['rarityId'] =
          _rarityCtrl.text.trim().isEmpty ? null : _rarityCtrl.text.trim();
    } else if (widget.categorySlug == 'subclass') {
      extras['parentClassId'] = _parentClassCtrl.text.trim();
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final writtenId = await saveEditedEntity(
        db: ref.read(appDatabaseProvider),
        currentId: widget.entityId,
        categorySlug: widget.categorySlug,
        activeCampaignId: campaignId,
        name: name,
        bodyJson: parsed,
        extras: extras,
      );
      if (!mounted) return;
      widget.onSaved?.call(writtenId);
      Navigator.of(context).pop(writtenId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Save failed: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForking = widget.entityId.startsWith('srd:') ||
        !widget.entityId.startsWith('hb:');
    return AlertDialog(
      title: Text('Edit ${widget.categorySlug}'),
      content: SizedBox(
        width: 520,
        child: !_loaded
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isForking)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Saving will create a homebrew copy in this world. '
                          'The original package content stays untouched.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    ..._categorySpecificFields(),
                    const SizedBox(height: 12),
                    Text('Body JSON',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 16,
                      minLines: 8,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      inputFormatters: const [],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || !_loaded ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  List<Widget> _categorySpecificFields() {
    switch (widget.categorySlug) {
      case 'spell':
        return [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _levelCtrl,
                decoration: const InputDecoration(labelText: 'Level'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _schoolCtrl,
                decoration:
                    const InputDecoration(labelText: 'School ID'),
              ),
            ),
          ]),
        ];
      case 'item':
      case 'equipment':
        return [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _itemTypeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Item type (weapon/armor/gear/…)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _rarityCtrl,
                decoration:
                    const InputDecoration(labelText: 'Rarity ID (optional)'),
              ),
            ),
          ]),
        ];
      case 'subclass':
        return [
          TextField(
            controller: _parentClassCtrl,
            decoration:
                const InputDecoration(labelText: 'Parent class ID'),
          ),
        ];
      default:
        return const [];
    }
  }
}

/// Opens the editor for the given typed entity. Category slugs without a
/// typed editor return without showing anything. Resolves to the written
/// id (may differ from the input id after a fork), or null on cancel.
Future<String?> showEntityEditor({
  required BuildContext context,
  required String entityId,
  required String categorySlug,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        EntityEditorDialog(entityId: entityId, categorySlug: categorySlug),
  );
}
