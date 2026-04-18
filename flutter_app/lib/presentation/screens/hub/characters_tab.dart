import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/marketplace_panel.dart';
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
  String? _selectedWorldName;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
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
                                subtitle: _subInfo(c, l10n),
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

              Text('Create New Character',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 8),
              _worldPicker(palette, l10n),
              const SizedBox(height: 8),
              _inheritedTemplateRow(palette),
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
                    onPressed: _canCreate() ? _createCharacter : null,
                    icon: _creating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
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

  String _subInfo(Character c, L10n l10n) {
    final parts = <String>[c.templateName];
    if (c.worldName.isNotEmpty) {
      parts.add(c.worldName);
    } else {
      parts.add(l10n.charWorldOrphan);
    }
    return parts.join(' · ');
  }

  Widget _worldPicker(DmToolColors palette, L10n l10n) {
    final worldsAsync = ref.watch(campaignInfoListProvider);
    return worldsAsync.when(
      data: (worlds) {
        if (worlds.isEmpty) {
          return Text(
            l10n.charCreateWorldRequired,
            style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
                fontStyle: FontStyle.italic),
          );
        }
        final names = worlds.map((w) => w.name).toList();
        if (_selectedWorldName != null &&
            !names.contains(_selectedWorldName)) {
          _selectedWorldName = null;
        }
        // Key selection'a bağlı — setState tetiklenince widget fully remount
        // olur ve yeni initialValue'yu direkt gösterir. FormField'in internal
        // state ile initialValue arasındaki yarışı temizler.
        return DropdownButtonFormField<String>(
          key: ValueKey(
              'char_world_${worlds.length}_${_selectedWorldName ?? "none"}'),
          initialValue: _selectedWorldName,
          decoration: InputDecoration(
            labelText: '${l10n.charCreateWorldLabel} *',
          ),
          items: worlds
              .map((w) => DropdownMenuItem(
                    value: w.name,
                    child: Text('${w.name}  (${w.templateName})',
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedWorldName = v),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _inheritedTemplateRow(DmToolColors palette) {
    final worlds = ref.watch(campaignInfoListProvider).valueOrNull ?? const [];
    final match = worlds.where((w) => w.name == _selectedWorldName).firstOrNull;
    final templateText = match == null
        ? '—'
        : '${match.templateName}  (inherited from world)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.description,
              size: 14, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 6),
          Text('Template: ',
              style: TextStyle(
                  fontSize: 12, color: palette.sidebarLabelSecondary)),
          Expanded(
            child: Text(
              templateText,
              style:
                  TextStyle(fontSize: 12, color: palette.tabActiveText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _canCreate() {
    if (_creating) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedWorldName == null) return false;
    return true;
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
    if (!_canCreate()) return;
    final name = _nameController.text.trim();
    final worldName = _selectedWorldName!;
    setState(() => _creating = true);
    try {
      final data =
          await ref.read(campaignRepositoryProvider).load(worldName);
      final schemaMap = data['world_schema'] as Map<String, dynamic>?;
      if (schemaMap == null) {
        _snack('World is missing a template schema.');
        return;
      }
      // Campaign repo, world_schema.schemaId'yi kendi row-id'siyle
      // (rotasyona uğramış) döndürüyor; kaynak template'i eşleştirmek için
      // `template_id` alanını kullanıp schemaId'yi override ediyoruz.
      final realTemplateId = (data['template_id'] as String?) ??
          (schemaMap['schemaId'] as String? ?? '');
      final template = WorldSchema.fromJson(Map<String, dynamic>.from(schemaMap))
          .copyWith(schemaId: realTemplateId);
      if (!template.categories.any((c) => c.slug == playerCategorySlug)) {
        _snack('This world\'s template has no Player category.');
        return;
      }

      final c = await ref.read(characterListProvider.notifier).create(
            name: name,
            template: template,
            worldName: worldName,
          );
      _nameController.clear();
      if (mounted) {
        setState(() {});
        context.push('/character/${c.id}');
      }
    } catch (e) {
      _snack('Failed to create character: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
            width: 440,
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
                    onTagsChanged: (v) =>
                        setDialogState(() => workingTags = v),
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
                                fontSize: 13,
                                color: palette.tabActiveText)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.public,
                          size: 16, color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.worldName.isEmpty
                              ? L10n.of(context)!.charWorldOrphan
                              : 'World: ${c.worldName}',
                          style: TextStyle(
                              fontSize: 13,
                              color: palette.tabActiveText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (updatedAt != null)
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16,
                            color: palette.sidebarLabelSecondary),
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
                  MarketplacePanel(
                    itemType: 'character',
                    localId: c.id,
                    title: c.entity.name,
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
