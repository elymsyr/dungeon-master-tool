import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';

class CharactersTab extends ConsumerStatefulWidget {
  const CharactersTab({super.key});

  @override
  ConsumerState<CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends ConsumerState<CharactersTab> {
  final _nameController = TextEditingController();
  int _selectedIndex = -1;
  WorldSchema? _selectedTemplate;
  final Set<String> _selectedPackages = {};
  final Set<String> _selectedWorlds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final charactersAsync = ref.watch(characterListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Characters',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.tabActiveText)),
              const SizedBox(height: 4),
              Text('Select or create a character.',
                  style: TextStyle(
                      fontSize: 12, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              // Karakter listesi
              charactersAsync.when(
                data: (characters) => characters.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: palette.featureCardBg,
                          borderRadius: palette.br,
                          border:
                              Border.all(color: palette.featureCardBorder),
                        ),
                        child: Center(
                          child: Text(
                            'No characters found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: palette.sidebarLabelSecondary,
                                fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: characters.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final c = characters[index];
                          final isSelected = index == _selectedIndex;
                          return InkWell(
                            borderRadius: palette.br,
                            onTap: () =>
                                setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadCharacter(c.id),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.featureCardAccent
                                        .withValues(alpha: 0.1)
                                    : palette.featureCardBg,
                                borderRadius: palette.br,
                                border: Border.all(
                                  color: isSelected
                                      ? palette.featureCardAccent
                                      : palette.featureCardBorder,
                                ),
                              ),
                              child: MetadataListTile(
                                icon: Icons.person,
                                name: c.entity.name,
                                subtitle: _subInfo(c),
                                description: c.entity.description,
                                tags: c.entity.tags,
                                coverImagePath: c.entity.imagePath,
                                isSelected: isSelected,
                                palette: palette,
                                layout: MetadataTileLayout.leftAvatar,
                                onSettings: () =>
                                    _showCharacterSettings(c.id, palette),
                              ),
                            ),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 12),

              // Load + Delete butonları
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedIndex >= 0
                          ? () {
                              final list = ref
                                      .read(characterListProvider)
                                      .valueOrNull ??
                                  [];
                              if (_selectedIndex < list.length) {
                                _loadCharacter(list[_selectedIndex].id);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Load Character'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedIndex >= 0 ? _deleteCharacter : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.dangerBtnBg,
                      foregroundColor: palette.dangerBtnText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Divider(color: palette.sidebarDivider),
              const SizedBox(height: 16),

              // Yeni karakter oluşturma
              Text('Create New Character',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 8),
              _templatePicker(palette),
              const SizedBox(height: 8),
              _linkedPackagesChips(palette),
              const SizedBox(height: 8),
              _linkedWorldsChips(palette),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(hintText: 'Character name'),
                      onSubmitted: (_) => _createCharacter(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createCharacter,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create'),
                    style: FilledButton.styleFrom(
                        backgroundColor: palette.successBtnBg,
                        foregroundColor: palette.successBtnText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subInfo(Character c) {
    final parts = <String>[c.templateName];
    if (c.linkedPackages.isNotEmpty) {
      parts.add('${c.linkedPackages.length} pkg');
    }
    if (c.linkedWorlds.isNotEmpty) {
      parts.add('${c.linkedWorlds.length} world');
    }
    return parts.join(' · ');
  }

  Widget _templatePicker(DmToolColors palette) {
    final templatesAsync = ref.watch(allTemplatesProvider);
    return templatesAsync.when(
      data: (templates) {
        final eligible = templates
            .where((t) =>
                t.categories.any((c) => c.slug == playerCategorySlug))
            .toList();
        if (eligible.isEmpty) {
          return Text(
            'No templates with a Player category. Create a template first.',
            style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
                fontStyle: FontStyle.italic),
          );
        }
        // Deduplicate by schemaId to avoid DropdownButton assertion.
        final seen = <String>{};
        final uniqueTemplates =
            eligible.where((t) => seen.add(t.schemaId)).toList();
        final matched = uniqueTemplates
            .where((t) => t.schemaId == _selectedTemplate?.schemaId)
            .firstOrNull;
        _selectedTemplate = matched ?? uniqueTemplates.first;
        return DropdownButtonFormField<String>(
          key: ValueKey('char_tmpl_${uniqueTemplates.length}'),
          initialValue: _selectedTemplate!.schemaId,
          decoration: const InputDecoration(labelText: 'Template'),
          items: uniqueTemplates
              .map((t) => DropdownMenuItem(
                    value: t.schemaId,
                    child: Text(t.name,
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            for (final t in uniqueTemplates) {
              if (t.schemaId == id) {
                setState(() => _selectedTemplate = t);
                break;
              }
            }
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _linkedPackagesChips(DmToolColors palette) {
    final packagesAsync = ref.watch(packageListProvider);
    return packagesAsync.when(
      data: (packages) => _MultiSelectDropdown(
        label: 'Link Packages',
        options: packages.map((p) => p.name).toList(),
        selected: _selectedPackages,
        onToggle: (name, on) => setState(() {
          on ? _selectedPackages.add(name) : _selectedPackages.remove(name);
        }),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _linkedWorldsChips(DmToolColors palette) {
    final worldsAsync = ref.watch(campaignInfoListProvider);
    return worldsAsync.when(
      data: (worlds) => _MultiSelectDropdown(
        label: 'Link Worlds',
        options: worlds.map((c) => c.name).toList(),
        selected: _selectedWorlds,
        onToggle: (name, on) => setState(() {
          on ? _selectedWorlds.add(name) : _selectedWorlds.remove(name);
        }),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _loadCharacter(String id) => context.push('/character/$id');

  Future<void> _deleteCharacter() async {
    final list = ref.read(characterListProvider).valueOrNull ?? [];
    if (_selectedIndex < 0 || _selectedIndex >= list.length) return;
    final c = list[_selectedIndex];
    final palette = Theme.of(context).extension<DmToolColors>()!;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text('Delete "${c.entity.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(characterListProvider.notifier)
                  .delete(c.id);
              // Best-effort cloud cleanup — no-op when offline/signed-out.
              await ref
                  .read(cloudBackupOperationProvider.notifier)
                  .deleteBackupByItem(c.id, 'character');
              if (mounted) setState(() => _selectedIndex = -1);
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCharacter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final template = _selectedTemplate;
    if (template == null) return;

    final c = await ref.read(characterListProvider.notifier).create(
          name: name,
          template: template,
          linkedPackages: _selectedPackages.toList(),
          linkedWorlds: _selectedWorlds.toList(),
        );
    _nameController.clear();
    if (mounted) {
      setState(() {
        _selectedPackages.clear();
        _selectedWorlds.clear();
      });
      context.push('/character/${c.id}');
    }
  }

  Future<void> _showCharacterSettings(
      String characterId, DmToolColors palette) async {
    final list = ref.read(characterListProvider).valueOrNull ?? [];
    final c = list.where((x) => x.id == characterId).firstOrNull;
    if (c == null) return;

    DateTime? updatedAt;
    try {
      updatedAt = DateTime.parse(c.updatedAt);
    } catch (_) {}

    // Mutable working copy — edits committed on Save.
    var workingName = c.entity.name;
    var workingDescription = c.entity.description;
    var workingTags = [...c.entity.tags];
    var workingCover = c.entity.imagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: Text('${c.entity.name} — Settings'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetadataEditorSection(
                name: workingName,
                description: workingDescription,
                tags: workingTags,
                coverImagePath: workingCover,
                onNameChanged: (v) => workingName = v,
                onDescriptionChanged: (v) => workingDescription = v,
                onTagsChanged: (v) => setDialogState(() => workingTags = v),
                onCoverChanged: (v) =>
                    setDialogState(() => workingCover = v),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.description,
                      size: 16, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Template: ${c.templateName}',
                        style: TextStyle(
                            fontSize: 13, color: palette.tabActiveText)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (updatedAt != null)
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: palette.sidebarLabelSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Last edited: ${updatedAt.toLocal().toString().split('.').first}',
                      style: TextStyle(
                          fontSize: 12, color: palette.tabActiveText),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              SaveInfoSection(
                itemName: c.entity.name,
                itemId: c.id,
                type: 'character',
                localUpdatedAt: updatedAt,
              ),
              const SizedBox(height: 12),
              Text('Linked Packages',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 4),
              if (c.linkedPackages.isEmpty)
                Text('None',
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: palette.sidebarLabelSecondary))
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: c.linkedPackages
                      .map((p) => Chip(
                            avatar: const Icon(Icons.inventory_2, size: 12),
                            label: Text(p,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              Text('Linked Worlds',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 4),
              if (c.linkedWorlds.isEmpty)
                Text('None',
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: palette.sidebarLabelSecondary))
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: c.linkedWorlds
                      .map((w) => Chip(
                            avatar: const Icon(Icons.public, size: 12),
                            label: Text(w,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
            ],
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(characterListProvider.notifier).updateMetadata(
                    id: c.id,
                    name: workingName,
                    description: workingDescription,
                    tags: workingTags,
                    coverImagePath: workingCover,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }
}

/// Dropdown-style multi-select — DropdownButtonFormField görünümü, ama
/// tap sonrası açılan menüde birden fazla kutu işaretlenebilir.
/// Seçili öğeler InputDecorator içinde chip olarak gösterilir.
class _MultiSelectDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final Set<String> selected;
  final void Function(String, bool) onToggle;

  const _MultiSelectDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: options.isEmpty ? null : () => _openMenu(context),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: false,
            suffixIcon: Icon(Icons.arrow_drop_down, color: outline),
          ),
          child: selected.isEmpty
              ? Text(
                  options.isEmpty ? 'None available' : 'None selected',
                  style: TextStyle(
                    fontSize: 13,
                    color: outline,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: selected
                      .map((name) => Chip(
                            label: Text(name,
                                style: const TextStyle(fontSize: 11)),
                            onDeleted: () => onToggle(name, false),
                            deleteIconColor: outline,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    await showMenu<void>(
      context: context,
      position: position,
      constraints: BoxConstraints(minWidth: box.size.width),
      items: options.map((name) {
        final on = selected.contains(name);
        return CheckedPopupMenuItem<void>(
          checked: on,
          onTap: () => onToggle(name, !on),
          child: Text(name, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }
}
