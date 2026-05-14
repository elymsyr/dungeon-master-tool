import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_claim_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/online/world_role.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'character_stat_chips.dart';
import 'marketplace_panel.dart';
import 'metadata_editor_section.dart';
import 'metadata_list_tile.dart';
import 'save_info_section.dart';

/// Right-sidebar character workspace. Lists characters scoped to the active
/// world and routes to [CharacterEditorScreen] on tap so the open experience
/// matches the Characters hub tab (full header, stat chips, level-up + rest
/// buttons).
class CharactersSidebar extends ConsumerStatefulWidget {
  final DmToolColors palette;

  const CharactersSidebar({super.key, required this.palette});

  @override
  ConsumerState<CharactersSidebar> createState() => _CharactersSidebarState();
}

class _CharactersSidebarState extends ConsumerState<CharactersSidebar> {
  @override
  Widget build(BuildContext context) {
    return _buildList(widget.palette);
  }

  Widget _buildList(DmToolColors palette) {
    final activeWorld = ref.watch(activeCampaignProvider);
    final charactersAsync = ref.watch(characterListProvider);
    // Bump trigger so linked_character_ids changes (import/unlink) cause
    // the sidebar to recompute scoped list.
    ref.watch(campaignRevisionProvider);
    final linkedIds = activeWorld == null
        ? const <String>{}
        : ((ref.read(activeCampaignProvider.notifier).data?[
                    'linked_character_ids']
                as List?)
                ?.whereType<String>()
                .toSet() ??
            const <String>{});
    // F2 / H3-extension: single merged entity map for the sidebar list.
    // Per-row `readCharacterEntities` was watching three providers and
    // spreading two maps for every character tile. Now: 1 watch, lazy
    // CombinedMapView, no per-row allocation.
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    final campaign = ref.watch(entityProvider);
    final merged = (activeWorld == null || campaign.isEmpty)
        ? builtin
        : UnmodifiableMapView<String, Entity>(
            CombinedMapView<String, Entity>([campaign, builtin]),
          );
    Map<String, Entity> entitiesFor(Character c) {
      if (c.worldName.isEmpty) return builtin;
      if (c.worldName != activeWorld) return builtin;
      return merged;
    }

    return Column(
      children: [
        // Header
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.tabBg,
            border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
          ),
          child: Row(
            children: [
              Icon(Icons.people, size: 16, color: palette.tabActiveText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeWorld == null
                      ? 'Characters'
                      : 'Characters · $activeWorld',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Create Character',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
                iconSize: 18,
                onPressed: activeWorld == null ? null : _createCharacter,
                icon: Icon(Icons.add, color: palette.tabActiveText),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: charactersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: palette.dangerBtnBg),
                ),
              ),
            ),
            data: (all) {
              final scoped = activeWorld == null
                  ? const <Character>[]
                  : (all
                          .where((c) =>
                              c.worldName == activeWorld ||
                              linkedIds.contains(c.id))
                          .toList()
                        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
              if (scoped.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      activeWorld == null
                          ? 'Open a world to see its characters.'
                          : 'No characters in this world yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.sidebarLabelSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              final l10n = L10n.of(context)!;
              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: scoped.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final c = scoped[i];
                  // Legacy linked-only chars (pre-fix) live in this world's
                  // `linked_character_ids` with their own `worldName` empty.
                  // Display the active world so the row stops claiming
                  // "No world assigned" while plainly sitting in that world.
                  final worldLabel = c.worldName.isNotEmpty
                      ? c.worldName
                      : (activeWorld != null && linkedIds.contains(c.id)
                          ? activeWorld
                          : l10n.charWorldOrphan);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapDown: (details) =>
                        _showRowContextMenu(c, details.globalPosition, palette),
                    onLongPressStart: (details) =>
                        _showRowContextMenu(c, details.globalPosition, palette),
                    child: InkWell(
                      borderRadius: palette.br,
                      onTap: () => _openCharacter(c),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 140),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: palette.featureCardBg,
                            borderRadius: palette.br,
                            border:
                                Border.all(color: palette.featureCardBorder),
                          ),
                          child: MetadataListTile(
                            icon: Icons.person,
                            name: c.entity.name,
                            subtitle: '${c.templateName} · $worldLabel',
                            description: c.entity.description,
                            tags: c.entity.tags,
                            coverImagePath: c.entity.imagePath,
                            isSelected: false,
                            palette: palette,
                            layout: MetadataTileLayout.leftAvatar,
                            onSettings: () =>
                                _showCharacterSettings(c.id, palette),
                            infoChips: CharacterStatChips(
                              lines: characterStatLines(c, entitiesFor(c)),
                              palette: palette,
                              compact: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

      ],
    );
  }

  void _createCharacter() {
    // Wizard auto-prefills the active world; after creation it navigates
    // to the editor screen.
    context.push('/character/new');
  }

  /// Label used in the settings dialog's "Public" row. Falls back to
  /// the active campaign when the character is referenced only via that
  /// world's `linked_character_ids` (pre-fix linked-only chars). Returns
  /// the localized orphan string when nothing claims the character.
  String _settingsWorldLabel(Character c) {
    final l10n = L10n.of(context)!;
    if (c.worldName.isNotEmpty) return 'World: ${c.worldName}';
    final activeWorld = ref.read(activeCampaignProvider);
    if (activeWorld != null && activeWorld.isNotEmpty) {
      final data = ref.read(activeCampaignProvider.notifier).data;
      final linked =
          (data?['linked_character_ids'] as List?)?.whereType<String>();
      if (linked != null && linked.contains(c.id)) {
        return 'World: $activeWorld';
      }
    }
    return l10n.charWorldOrphan;
  }

  Future<void> _openCharacter(Character c) async {
    if (c.worldName.isNotEmpty) {
      final active = ref.read(activeCampaignProvider);
      if (active != c.worldName) {
        final ok = await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'open-world-${c.worldName}',
          'Opening world "${c.worldName}"...',
          () => ref.read(activeCampaignProvider.notifier).load(c.worldName),
        );
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'World "${c.worldName}" not found on disk — character cannot open.'),
            ),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    context.push('/character/${c.id}');
  }

  Future<void> _showRowContextMenu(
    Character c,
    Offset globalPosition,
    DmToolColors palette,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final role =
        ref.read(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
    final isDmOnline = role == WorldRole.dm;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        if (isDmOnline)
          PopupMenuItem<String>(
            value: 'assign',
            child: Row(
              children: [
                Icon(Icons.person_pin,
                    size: 16, color: palette.tabActiveText),
                const SizedBox(width: 8),
                const Text('Assign to player...'),
              ],
            ),
          ),
        if (isDmOnline)
          PopupMenuItem<String>(
            value: 'pool',
            child: Row(
              children: [
                Icon(Icons.inventory_2,
                    size: 16, color: palette.tabActiveText),
                const SizedBox(width: 8),
                const Text('Make available for claim'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 16, color: palette.dangerBtnBg),
              const SizedBox(width: 8),
              const Text('Remove from world'),
            ],
          ),
        ),
      ],
    );
    if (selected == 'remove') {
      await _removeFromWorld(c, palette);
    } else if (selected == 'assign') {
      await _assignToPlayerDialog(c, palette);
    } else if (selected == 'pool') {
      await _markAvailableForClaim(c, palette);
    }
  }

  Future<void> _assignToPlayerDialog(Character c, DmToolColors palette) async {
    final worldId = ref.read(activeCampaignIdProvider).valueOrNull;
    if (worldId == null) return;
    final membersAsync = await ref
        .read(worldMembersProvider(worldId).future);
    final players = membersAsync
        .where((m) => m.role == WorldRole.player)
        .toList();
    if (!mounted) return;
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players have joined yet')),
      );
      return;
    }
    final selectedUserId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assign "${c.entity.name}" to'),
        children: players
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, m.userId),
                  child: Text(m.displayName ??
                      m.username ??
                      m.userId.substring(0, 8)),
                ))
            .toList(),
      ),
    );
    if (selectedUserId == null) return;
    try {
      final svc = ref.read(characterClaimServiceProvider);
      if (svc == null) return;
      await svc.assignToPlayer(
          characterId: c.id, userId: selectedUserId);
      // Local karakteri de owner_id ile güncelle (mirror echo gerek yok).
      await ref
          .read(characterListProvider.notifier)
          .update(c.copyWith(ownerId: selectedUserId));
      ref.invalidate(claimPoolProvider(worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assigned to player')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _markAvailableForClaim(
      Character c, DmToolColors palette) async {
    final worldId = ref.read(activeCampaignIdProvider).valueOrNull;
    if (worldId == null) return;
    try {
      final svc = ref.read(characterClaimServiceProvider);
      if (svc == null) return;
      await svc.markAvailable(characterId: c.id, worldId: worldId);
      ref.invalidate(claimPoolProvider(worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"${c.entity.name}" is now available for claim')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeFromWorld(Character c, DmToolColors palette) async {
    final worldName = c.worldName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from World'),
        content: Text(
            'Remove "${c.entity.name}" from "$worldName"? '
            'The character itself is kept and can be reattached to a world later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(characterListProvider.notifier)
                  .update(c.copyWith(worldName: ''));
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Remove'),
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
                          _settingsWorldLabel(c),
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
