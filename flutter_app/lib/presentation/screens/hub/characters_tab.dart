import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../domain/entities/character.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/marketplace_panel.dart';
import 'social_tab.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';

/// View + manage all characters across worlds. Creation also available here;
/// per-world creation lives in the campaign Characters sidebar.
class CharactersTab extends ConsumerStatefulWidget {
  const CharactersTab({super.key});

  @override
  ConsumerState<CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends ConsumerState<CharactersTab> {
  int _selectedIndex = -1;

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
              Row(
                children: [
                  Expanded(
                    child: Text('Characters',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(socialSubTabProvider.notifier).state =
                          'marketplace';
                      ref.read(hubTabIndexProvider.notifier).state = 0;
                    },
                    icon: const Icon(Icons.storefront, size: 16),
                    label: const Text('Marketplace'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Open or manage your characters.',
                  style: TextStyle(
                      fontSize: 12,
                      color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              charactersAsync.when(
                data: (all) {
                  // Sort by updatedAt DESC — last edited/opened first.
                  final sorted = [...all]
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  if (sorted.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: palette.featureCardBg,
                        borderRadius: palette.br,
                        border:
                            Border.all(color: palette.featureCardBorder),
                      ),
                      child: Center(
                        child: Text(
                          'No characters yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: palette.sidebarLabelSecondary,
                              fontSize: 12),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final c = sorted[index];
                      final isSelected = index == _selectedIndex;
                      return InkWell(
                        borderRadius: palette.br,
                        onTap: () =>
                            setState(() => _selectedIndex = index),
                        onDoubleTap: () => _openCharacter(c),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 140),
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
                        ),
                      );
                    },
                  );
                },
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
                              final list = _sortedList();
                              if (_selectedIndex < list.length) {
                                _openCharacter(list[_selectedIndex]);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Open Character'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _selectedIndex >= 0 ? _deleteSelected : null,
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/character/new'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Create Character'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.successBtnBg,
                    foregroundColor: palette.successBtnText,
                    minimumSize: const Size(0, 38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loads the character's world (so entityProvider populates and relation
  /// fields resolve names) before pushing to the editor.
  Future<void> _openCharacter(Character c) async {
    if (c.worldName.isNotEmpty) {
      final active = ref.read(activeCampaignProvider);
      if (active != c.worldName) {
        await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'open-world-${c.worldName}',
          'Opening world "${c.worldName}"...',
          () => ref
              .read(activeCampaignProvider.notifier)
              .load(c.worldName),
        );
      }
    }
    if (!mounted) return;
    context.push('/character/${c.id}');
  }

  List<Character> _sortedList() {
    final all = ref.read(characterListProvider).valueOrNull ?? const [];
    return [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _subInfo(Character c, L10n l10n) {
    final parts = <String>[c.templateName];
    parts.add(c.worldName.isEmpty ? l10n.charWorldOrphan : c.worldName);
    return parts.join(' · ');
  }

  Future<void> _deleteSelected() async {
    final list = _sortedList();
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
              await ref.read(characterListProvider.notifier).delete(c.id);
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

  Future<void> _showCharacterSettings(
      String characterId, DmToolColors palette) async {
    final list = ref.read(characterListProvider).valueOrNull ?? const [];
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
                              fontSize: 13, color: palette.tabActiveText),
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
