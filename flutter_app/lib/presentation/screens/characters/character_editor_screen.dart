import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/character_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/field_widgets/field_widget_factory.dart';

/// Standalone character editor. Hub-level Characters tab'dan push edilir.
/// Bir Character'ı template'inin Player kategorisine göre render eder.
class CharacterEditorScreen extends ConsumerStatefulWidget {
  final String characterId;

  const CharacterEditorScreen({super.key, required this.characterId});

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState
    extends ConsumerState<CharacterEditorScreen> {
  Character? _working;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final character =
        _working ?? ref.watch(characterByIdProvider(widget.characterId));

    if (character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Character')),
        body: const Center(child: Text('Character not found.')),
      );
    }

    if (_working == null) {
      _working = character;
      _nameCtrl.text = character.entity.name;
    }

    final templatesAsync = ref.watch(allTemplatesProvider);
    return templatesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (templates) {
        final template = templates
            .where((t) => t.schemaId == character.templateId)
            .firstOrNull;
        if (template == null) {
          return Scaffold(
            appBar: AppBar(title: Text(character.entity.name)),
            body: Center(
              child: Text(
                'Template "${character.templateName}" missing.\n'
                'Restore it in the Templates tab to edit this character.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.sidebarLabelSecondary),
              ),
            ),
          );
        }
        final playerCat = template.categories
            .where((c) => c.slug == playerCategorySlug)
            .firstOrNull;
        if (playerCat == null) {
          return Scaffold(
            appBar: AppBar(title: Text(character.entity.name)),
            body: const Center(
              child: Text('Template has no Player category.'),
            ),
          );
        }
        return _buildEditor(context, palette, playerCat, template);
      },
    );
  }

  Widget _buildEditor(
    BuildContext context,
    DmToolColors palette,
    EntityCategorySchema playerCat,
    WorldSchema template,
  ) {
    final character = _working!;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Character Name',
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          onChanged: (v) => setState(() {
            _working = character.copyWith(
              entity: character.entity.copyWith(name: v),
            );
          }),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _saveAndClose(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                template.name,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _linkedBadges(palette, character),
                _renderFields(palette, playerCat),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkedBadges(DmToolColors palette, Character c) {
    final packs = c.linkedPackages;
    final worlds = c.linkedWorlds;
    if (packs.isEmpty && worlds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final p in packs)
            Chip(
              avatar: const Icon(Icons.inventory_2, size: 14),
              label: Text(p, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          for (final w in worlds)
            Chip(
              avatar: const Icon(Icons.public, size: 14),
              label: Text(w, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }

  Widget _renderFields(DmToolColors palette, EntityCategorySchema cat) {
    final character = _working!;
    final fieldsByGroup = <String?, List<FieldSchema>>{};
    for (final f in cat.fields) {
      fieldsByGroup.putIfAbsent(f.groupId, () => []).add(f);
    }
    final groupsInOrder = [...cat.fieldGroups]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final children = <Widget>[];

    // Grupsuz field'lar üstte.
    final orphans = fieldsByGroup[null] ?? const <FieldSchema>[];
    for (final f in orphans) {
      children.add(_fieldTile(f, character));
    }

    for (final g in groupsInOrder) {
      final list = fieldsByGroup[g.groupId] ?? const <FieldSchema>[];
      if (list.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          g.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.tabActiveText,
          ),
        ),
      ));
      for (final f in list) {
        children.add(_fieldTile(f, character));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _fieldTile(FieldSchema f, Character character) {
    final value = character.entity.fields[f.fieldKey];
    return FieldWidgetFactory.create(
      schema: f,
      value: value,
      readOnly: false,
      onChanged: (v) {
        final updatedFields = {
          ...character.entity.fields,
          f.fieldKey: v,
        };
        setState(() {
          _working = character.copyWith(
            entity: character.entity.copyWith(fields: updatedFields),
          );
        });
      },
      entityFields: character.entity.fields,
      ref: ref,
    );
  }

  Future<void> _save() async {
    final w = _working;
    if (w == null) return;
    await ref.read(characterListProvider.notifier).update(w);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Character saved.')),
      );
    }
  }

  Future<void> _saveAndClose(BuildContext context) async {
    await _save();
    if (context.mounted) context.pop();
  }
}
