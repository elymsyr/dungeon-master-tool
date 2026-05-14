import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_claim_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../../application/services/builtin_srd_entities.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/entity.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/character_stat_chips.dart';
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
  bool _importing = false;
  bool _releasing = false;

  /// Char tab visibility is own-only: signed-in users see characters whose
  /// `ownerId == auth.uid`. Pre-auth (offline) data has `ownerId == null`
  /// AND `selfUid == null` — treat that as owned so the local-only flow
  /// still shows the user's characters.
  bool _isOwned(Character c, String? selfUid) {
    if (c.ownerId == null) return selfUid == null;
    return c.ownerId == selfUid;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    // H3: single screen-level entity merge instead of per-row
    // readCharacterEntities calls. 200 rows × 3 provider watches → 3
    // watches total. Lazy CombinedMapView so reads stay O(1) per id.
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    final activeWorld = ref.watch(activeCampaignProvider) ?? '';
    final campaign = ref.watch(entityProvider);
    final merged = (activeWorld.isEmpty || campaign.isEmpty)
        ? builtin
        : UnmodifiableMapView<String, Entity>(
            CombinedMapView<String, Entity>([campaign, builtin]),
          );
    Map<String, Entity> entitiesFor(Character c) {
      if (c.worldName.isEmpty) return builtin;
      if (c.worldName != activeWorld) return builtin;
      return merged;
    }

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
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => context.push('/character/new'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      minimumSize: const Size(32, 32),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Icon(Icons.add, size: 16),
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
                  // H3: sort hoisted to provider — cached until the list
                  // identity changes. `all` parameter retained to keep
                  // the AsyncValue.when type contract; we use the
                  // provider's cached result instead.
                  final sortedAll = ref.watch(sortedCharactersProvider);
                  final selfUid = ref.watch(authProvider)?.uid;
                  final sorted =
                      sortedAll.where((c) => _isOwned(c, selfUid)).toList();
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
                              infoChips: CharacterStatChips(
                                lines: characterStatLines(
                                    c, entitiesFor(c)),
                                palette: palette,
                                compact: true,
                              ),
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

              Builder(builder: (context) {
                final list = _visibleList();
                final selected =
                    (_selectedIndex >= 0 && _selectedIndex < list.length)
                        ? list[_selectedIndex]
                        : null;
                // Hard delete only when char has no owner AND no world.
                // Otherwise the action releases ownership: char stays in
                // its world ownerless (or, for the worldless self-owned
                // case, becomes deletable on the next press once owner
                // is cleared — handled in `_releaseOrDeleteSelected`).
                final isHardDelete = selected != null &&
                    selected.ownerId == null &&
                    selected.worldName.isEmpty;
                final actionButton = FilledButton.icon(
                  onPressed: selected == null || _releasing
                      ? null
                      : _releaseOrDeleteSelected,
                  icon: _releasing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isHardDelete
                              ? Icons.delete_outline
                              : Icons.logout,
                          size: 18,
                        ),
                  label: Text(isHardDelete ? 'Delete' : 'Release'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.dangerBtnBg,
                    foregroundColor: palette.dangerBtnText,
                  ),
                );
                final importTarget =
                    selected == null ? null : _importTargetWorld(selected);
                return Column(
                  children: [
                    if (importTarget != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _importing
                              ? null
                              : () => _importToActiveWorld(
                                  selected!, importTarget),
                          icon: _importing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.input, size: 18),
                          label: Text('Import to "$importTarget"'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: selected != null
                                ? () => _openCharacter(selected)
                                : null,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Open Character'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        actionButton,
                      ],
                    ),
                  ],
                );
              }),

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
        final ok = await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'open-world-${c.worldName}',
          'Opening world "${c.worldName}"...',
          () => ref
              .read(activeCampaignProvider.notifier)
              .load(c.worldName),
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

  /// Own-only view. Char tab shows characters whose owner is the signed-in
  /// user (or, pre-auth, the local fallback). Action buttons share this
  /// output with the list builder so selection indices line up.
  List<Character> _visibleList() {
    final sorted = ref.read(sortedCharactersProvider);
    final selfUid = ref.read(authProvider)?.uid;
    return sorted.where((c) => _isOwned(c, selfUid)).toList();
  }

  /// Active world'e import edilebilirlik check'i. Null = uygun değil.
  /// Geri dönüş = hedef world adı (button label'da kullanılır).
  /// Eligibility:
  ///   - char.worldName != active world (zaten bağlı değil)
  ///   - active world var
  ///   - active world online (member listesi var)
  ///   - user member (dm veya player)
  ///   - char ownerId null (offline/orphan) ya da ownerId == selfUid
  String? _importTargetWorld(Character c) {
    final activeWorld = ref.watch(activeCampaignProvider);
    if (activeWorld == null || activeWorld.isEmpty) return null;
    if (c.worldName == activeWorld) return null;
    final infoList =
        ref.watch(campaignInfoListProvider).valueOrNull ?? const [];
    final info = infoList.where((w) => w.name == activeWorld).firstOrNull;
    if (info == null) return null;
    final onlineIds = ref.watch(onlineWorldIdsProvider);
    if (!onlineIds.contains(info.id)) return null;
    final role = ref.watch(worldRoleProvider(info.id)).valueOrNull;
    if (role != WorldRole.dm && role != WorldRole.player) return null;
    final selfUid = ref.watch(authProvider)?.uid;
    if (c.ownerId != null && c.ownerId != selfUid) return null;
    return activeWorld;
  }

  Future<void> _importToActiveWorld(Character c, String worldName) async {
    setState(() => _importing = true);
    try {
      final selfUid = ref.read(authProvider)?.uid;
      final infoList =
          ref.read(campaignInfoListProvider).valueOrNull ?? const [];
      final info = infoList.where((w) => w.name == worldName).firstOrNull;
      if (info == null) return;
      final role = ref.read(worldRoleProvider(info.id)).valueOrNull;
      // Player keeps ownership (and RLS `owner_id = auth.uid()` requires
      // it). DM drops ownership on import — char becomes claimable in the
      // world and disappears from the DM's own-only char tab.
      final isPlayer = role == WorldRole.player;
      final newOwnerId = isPlayer ? selfUid : null;
      if (!isPlayer) {
        // Unpublish personal sync BEFORE the update so `_mirrorPush` won't
        // re-publish an ownerless payload to `personal_characters`. Char
        // tab visibility on other devices stays consistent.
        try {
          await ref.read(characterListProvider.notifier).makeOffline(c.id);
        } catch (e) {
          debugPrint('import makeOffline error: $e');
        }
      }
      final patched = c.copyWith(
        worldName: worldName,
        ownerId: newOwnerId,
      );
      await ref.read(characterListProvider.notifier).update(patched);
      if (!mounted) return;
      setState(() => _selectedIndex = -1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "${c.entity.name}" to "$worldName"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  String _subInfo(Character c, L10n l10n) {
    final parts = <String>[c.templateName];
    parts.add(_worldLabel(c, l10n));
    return parts.join(' · ');
  }

  /// Resolves the world label for the tab. Falls back to the active
  /// campaign when the character is referenced only via that world's
  /// `linked_character_ids` (pre-fix linked-only chars); otherwise
  /// shows the localized orphan string so unclaimed chars stay clear.
  String _worldLabel(Character c, L10n l10n) {
    if (c.worldName.isNotEmpty) return c.worldName;
    final activeWorld = ref.read(activeCampaignProvider);
    if (activeWorld != null && activeWorld.isNotEmpty) {
      final data = ref.read(activeCampaignProvider.notifier).data;
      final linked =
          (data?['linked_character_ids'] as List?)?.whereType<String>();
      if (linked != null && linked.contains(c.id)) {
        return activeWorld;
      }
    }
    return l10n.charWorldOrphan;
  }

  /// Char tab's destructive action. Branches on the canonical
  /// "ownerless AND worldless" delete predicate:
  ///   - Both true: hard delete (row gone, cloud backup wiped).
  ///   - World-bound: release ownership. Online world uses the
  ///     `release_character` RPC so RLS + CDC stay coherent. Offline
  ///     world clears `ownerId` locally — char stays in its world for
  ///     other players (or the DM) to see.
  ///   - Worldless + self-owned: clear ownerId locally, then immediately
  ///     hard delete since the row is now ownerless+worldless.
  Future<void> _releaseOrDeleteSelected() async {
    final list = _visibleList();
    if (_selectedIndex < 0 || _selectedIndex >= list.length) return;
    final c = list[_selectedIndex];
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final isHardDelete = c.ownerId == null && c.worldName.isEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHardDelete ? 'Delete Character' : 'Release Character'),
        content: Text(
          isHardDelete
              ? 'Delete "${c.entity.name}"? This cannot be undone.'
              : c.worldName.isNotEmpty
                  ? 'Release "${c.entity.name}" in "${c.worldName}"? '
                      'The character stays in the world and can be claimed '
                      'again. It disappears from your Characters tab.'
                  : 'Release "${c.entity.name}"? You give up ownership; the '
                      'character is deleted because it has no world.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: Text(isHardDelete ? 'Delete' : 'Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _releasing = true);
    try {
      if (isHardDelete) {
        await _hardDelete(c);
      } else if (c.worldName.isNotEmpty) {
        await _releaseWorldBound(c);
      } else {
        // Worldless + self-owned → release self, then hard delete: the
        // row would otherwise linger as ownerless+worldless garbage and
        // be invisible to every user under the own-only filter.
        await _hardDelete(c);
      }
      if (mounted) setState(() => _selectedIndex = -1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _hardDelete(Character c) async {
    await ref.read(characterListProvider.notifier).delete(c.id);
    await ref
        .read(cloudBackupOperationProvider.notifier)
        .deleteBackupByItem(c.id, 'character');
  }

  /// Releases ownership of a world-bound character.
  ///
  /// Online world: `world_characters` is the canonical store. The
  /// `release_character` RPC flips `owner_id` to null atomically under
  /// RLS; CDC broadcasts to every member, and we drop the local mirror
  /// so the char disappears from this user's own-only char tab without
  /// waiting on the echo.
  ///
  /// Offline world: the local row IS the canonical store (the world's
  /// `linked_character_ids` points at this id). We clear `ownerId` in
  /// place — the row stays so the world keeps its character — and stop
  /// personal sync. The char tab filter hides ownerless-with-auth rows
  /// so it leaves the tab on its own.
  Future<void> _releaseWorldBound(Character c) async {
    final infoList =
        ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final info = infoList.where((w) => w.name == c.worldName).firstOrNull;
    final onlineIds = ref.read(onlineWorldIdsProvider);
    final isOnline = info != null && onlineIds.contains(info.id);

    try {
      await ref.read(characterListProvider.notifier).makeOffline(c.id);
    } catch (e) {
      debugPrint('release makeOffline error: $e');
    }

    if (isOnline) {
      final svc = ref.read(characterClaimServiceProvider);
      if (svc != null) {
        await svc.release(c.id);
      }
      await ref.read(characterListProvider.notifier).removeMirror(c.id);
      try {
        await ref
            .read(cloudBackupOperationProvider.notifier)
            .deleteBackupByItem(c.id, 'character');
      } catch (e) {
        debugPrint('release cloud backup cleanup error: $e');
      }
    } else {
      // Offline: keep the row, just clear `ownerId`. World's
      // `linked_character_ids` still resolves to this character.
      await ref
          .read(characterListProvider.notifier)
          .update(c.copyWith(ownerId: null));
    }
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
                          () {
                            final label =
                                _worldLabel(c, L10n.of(context)!);
                            return c.worldName.isEmpty &&
                                    label == L10n.of(context)!.charWorldOrphan
                                ? label
                                : 'World: $label';
                          }(),
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
