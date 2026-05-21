import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/sync_engine_provider.dart';
import '../../../application/services/builtin_srd_entities.dart';
import '../../../application/services/cloud_catchup_service.dart';
import '../../../domain/entities/character.dart';
import '../../../domain/entities/character_ext.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/value_objects/media_kind.dart';
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
  // U2: ValueNotifier — seçim değişimi tüm tab build()'ini değil yalnızca
  // satır + aksiyon paneli VLB'lerini rebuild eder (100+ karakterde kritik).
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(-1);
  bool _releasing = false;
  bool _refreshing = false;

  @override
  void dispose() {
    _selectedIndex.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Drain outbox first so pending deletes hit the server before we pull.
      // Otherwise the catchup pulls a still-present cloud_backups row and
      // resurrects a character the user just deleted.
      await ref.read(syncEngineProvider).forceTick();
      await ref.read(cloudCatchupServiceProvider).runAll();
    } catch (e) {
      debugPrint('Characters refresh error: $e');
    }
    if (!mounted) return;
    // `invalidate` yerine `refresh()`: invalidate notifier'ı yok edip yenisini
    // `AsyncValue.loading()` ile kurar → liste bir frame boş kalır → karakter
    // "gelip kayboluyor" titremesi. `refresh()` = `_load()`, loading emit
    // etmez; mevcut data state'i diskten yeniden yükleyerek günceller.
    await ref.read(characterListProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

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
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    final campaign = ref.watch(entityProvider);
    final merged = (activeWorldId == null || campaign.isEmpty)
        ? builtin
        : UnmodifiableMapView<String, Entity>(
            CombinedMapView<String, Entity>([campaign, builtin]),
          );
    Map<String, Entity> entitiesFor(Character c) {
      if (c.worldId == null) return builtin;
      if (c.worldId != activeWorldId) return builtin;
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
                    child: Text(l10n.charactersHeading,
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
                    label: Text(l10n.hubBtnMarketplace),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: l10n.hubTooltipRefresh,
                    child: OutlinedButton(
                      onPressed: _refreshing ? null : _doRefresh,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: const Size(32, 32),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _refreshing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 16),
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
              Text(l10n.charactersSubtitle,
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
                          l10n.charactersEmpty,
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
                      // Ağır iş (stat satırları + entity çözümü) itemBuilder
                      // gövdesinde bir kez hesaplanır — seçim değişiminde
                      // VLB builder'ında TEKRARLANMAZ.
                      final infoChips = CharacterStatChips(
                        lines: characterStatLines(
                          c,
                          entitiesFor(c),
                          ownerLabel: resolveCharacterOwnerLabel(ref, c),
                        ),
                        palette: palette,
                        compact: true,
                      );
                      return RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _selectedIndex,
                          builder: (context, selectedIdx, _) {
                            final isSelected = index == selectedIdx;
                            return InkWell(
                              borderRadius: palette.br,
                              onTap: () => _selectedIndex.value = index,
                              onDoubleTap: () => _openCharacter(c),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 140),
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
                                    infoChips: infoChips,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.hubErrorGeneric(e.toString())),
              ),

              const SizedBox(height: 12),

              ValueListenableBuilder<int>(
                valueListenable: _selectedIndex,
                builder: (context, selectedIdx, _) {
                final list = _visibleList();
                final selected =
                    (selectedIdx >= 0 && selectedIdx < list.length)
                        ? list[selectedIdx]
                        : null;
                // Hard delete only when char has no owner AND no world.
                // Otherwise the action releases ownership: char stays in
                // its world ownerless (or, for the worldless self-owned
                // case, becomes deletable on the next press once owner
                // is cleared — handled in `_releaseOrDeleteSelected`).
                final isHardDelete = selected != null &&
                    selected.ownerId == null &&
                    selected.worldId == null;
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
                  label: Text(isHardDelete ? l10n.btnDelete : l10n.charBtnRelease),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.dangerBtnBg,
                    foregroundColor: palette.dangerBtnText,
                  ),
                );
                // Import butonu 039 model'de Characters Tab'da YOK. Kullanıcı
                // kuralı: "Karakteri yalnızca dünya içinden import edebiliriz."
                // World view (sidebar / player tab) üst kısmında dedicated
                // Import buton var.
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selected != null
                            ? () => _openCharacter(selected)
                            : null,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(l10n.charBtnOpen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    actionButton,
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
    final l10n = L10n.of(context)!;
    final worldId = c.worldId;
    if (worldId != null) {
      final infos =
          ref.read(campaignInfoListProvider).valueOrNull ?? const [];
      var worldName = c.resolvedWorldName(infos);
      // Cross-device: char synced via cloud_backup but world wasn't pulled
      // yet. One-shot restore from cloud_backup keyed by worldId before
      // giving up.
      if (worldName.isEmpty) {
        final restored = await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'pull-world-$worldId',
          l10n.charPullingWorld,
          () => ensureWorldLocalById(ref, worldId),
        );
        if (!mounted) return;
        if (restored != null && restored.isNotEmpty) {
          worldName = restored;
        }
      }
      if (worldName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.charWorldNotFound),
          ),
        );
        return;
      }
      final active = ref.read(activeCampaignProvider);
      if (active != worldName) {
        // Optimistic flip (B1 pattern): sync state change so the editor
        // route pushes immediately. Heavy flush + file IO completes in the
        // background; relation widgets render with the default schema until
        // _data lands and the revision bump triggers a reparse.
        final notifier = ref.read(activeCampaignProvider.notifier);
        notifier.beginLoad(worldName);
        if (!mounted) return;
        context.push('/character/${c.id}');
        final ok = await notifier.completeLoad();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.charWorldMissingOnDisk(worldName)),
            ),
          );
        }
        return;
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

  String _subInfo(Character c, L10n l10n) {
    final parts = <String>[c.templateName];
    parts.add(_worldLabel(c, l10n));
    return parts.join(' · ');
  }

  /// Display label: `worldId` üzerinden `campaignInfoListProvider`'den ad
  /// çözer. NULL veya bulunamadıysa orphan label döner.
  String _worldLabel(Character c, L10n l10n) {
    final infos = ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final name = c.resolvedWorldName(infos);
    return name.isEmpty ? l10n.charWorldOrphan : name;
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
    final l10n = L10n.of(context)!;
    final list = _visibleList();
    final idx = _selectedIndex.value;
    if (idx < 0 || idx >= list.length) return;
    final c = list[idx];
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final isHardDelete = c.ownerId == null && c.worldId == null;
    final infos =
        ref.read(campaignInfoListProvider).valueOrNull ?? const [];
    final worldName = c.resolvedWorldName(infos);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHardDelete ? l10n.charDeleteTitle : l10n.charReleaseTitle),
        content: Text(
          isHardDelete
              ? l10n.charDeleteBody(c.entity.name)
              : c.worldId != null
                  ? (worldName.isNotEmpty
                      ? l10n.charReleaseBodyInWorldNamed(c.entity.name, worldName)
                      : l10n.charReleaseBodyInWorldUnnamed(c.entity.name))
                  : l10n.charReleaseBodyNoWorld(c.entity.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: Text(isHardDelete ? l10n.btnDelete : l10n.charBtnRelease),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _releasing = true);
    try {
      // 039 model: provider.delete(id) server-side router.
      //   - world-bound → remove_from_world RPC (owner varsa orphan'a düşür)
      //   - orphan → delete_character RPC (hard delete)
      // Cloud backup cleanup parallel: yine de tetikle, orphan→delete path'inde
      // server row gitti, eski backup'lar silinmeli.
      await ref.read(characterListProvider.notifier).delete(c.id);
      try {
        await ref
            .read(cloudBackupOperationProvider.notifier)
            .deleteBackupByItem(c.id, 'character');
      } catch (e) {
        debugPrint('cloud backup cleanup error: $e');
      }
      if (mounted) _selectedIndex.value = -1;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _showCharacterSettings(
      String characterId, DmToolColors palette) async {
    final l10n = L10n.of(context)!;
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
          title: Text(l10n.charSettingsTitle(c.entity.name)),
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
                    coverKind: MediaKind.characterPortrait,
                    coverScopeId: c.id,
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
                        child: Text(l10n.charTemplateLine(c.templateName),
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
                            final label = _worldLabel(c, l10n);
                            return c.worldId == null &&
                                    label == l10n.charWorldOrphan
                                ? label
                                : l10n.charWorldLine(label);
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
                          l10n.charLastEdited(updatedAt.toLocal().toString().split('.').first),
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
              child: Text(l10n.btnCancel),
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
              child: Text(l10n.btnSave),
            ),
          ],
        ),
      ),
    );
  }
}
