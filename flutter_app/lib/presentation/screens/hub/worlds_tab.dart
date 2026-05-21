import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../application/providers/marketplace_listing_provider.dart';
import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/world_membership_provider.dart';
import '../../../application/services/cloud_catchup_service.dart';
import '../../../application/services/world_reconciler.dart';
import '../../../core/config/app_paths.dart';
import '../../../core/config/supabase_config.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/value_objects/media_kind.dart';
import '../../dialogs/join_world_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/marketplace_panel.dart';
import '../../widgets/online_world_section.dart';
import 'social_tab.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';
import '../../widgets/world_packages_section.dart';


class WorldsTab extends ConsumerStatefulWidget {
  const WorldsTab({super.key});

  @override
  ConsumerState<WorldsTab> createState() => _WorldsTabState();
}

class _WorldsTabState extends ConsumerState<WorldsTab> {
  final _nameController = TextEditingController();
  int _selectedIndex = -1;
  WorldSchema? _selectedTemplate;
  bool _refreshing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(worldReconcilerProvider).reconcile();
      await ref.read(cloudCatchupServiceProvider).runAll();
    } catch (e) {
      debugPrint('Worlds refresh error: $e');
    }
    if (!mounted) return;
    ref.invalidate(campaignListProvider);
    ref.invalidate(campaignInfoListProvider);
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final campaignInfoList = ref.watch(campaignInfoListProvider);

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
                    child: Text(l10n.worldsHeading, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(socialSubTabProvider.notifier).state = 'marketplace';
                      ref.read(hubTabIndexProvider.notifier).state = 0;
                    },
                    icon: const Icon(Icons.storefront, size: 16),
                    label: Text(l10n.hubBtnMarketplace),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (SupabaseConfig.isConfigured) ...[
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: () => JoinWorldDialog.show(context),
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(l10n.worldsBtnJoin),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
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
                    onPressed: _openCreateWorldDialog,
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
              Text(l10n.worldsSubtitle, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              // Kampanya listesi
              campaignInfoList.when(
                data: (campaigns) => campaigns.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: palette.featureCardBg,
                          borderRadius: palette.br,
                          border: Border.all(color: palette.featureCardBorder),
                        ),
                        child: Center(
                          child: Text(
                            l10n.worldsEmpty(AppPaths.worldsDir),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: campaigns.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final info = campaigns[index];
                          final isSelected = index == _selectedIndex;
                          final metaAsync =
                              ref.watch(campaignMetadataProvider(info.name));
                          final meta =
                              metaAsync.valueOrNull ?? const <String, dynamic>{};
                          // Online + role indicator: user joined this world
                          // either as DM (publisher) or player. Both cases
                          // land in `onlineWorldIds`; role decides which
                          // icon we render.
                          final onlineIds =
                              ref.watch(onlineWorldIdsProvider);
                          final isOnlineMember =
                              onlineIds.contains(info.id);
                          final role = isOnlineMember
                              ? (ref
                                      .watch(worldRoleProvider(info.id))
                                      .valueOrNull ??
                                  WorldRole.none)
                              : WorldRole.none;
                          return InkWell(
                            borderRadius: palette.br,
                            onTap: () => setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadCampaign(info.name),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isSelected ? palette.featureCardAccent.withValues(alpha: 0.1) : palette.featureCardBg,
                                borderRadius: palette.br,
                                border: Border.all(
                                  color: isSelected ? palette.featureCardAccent : palette.featureCardBorder,
                                ),
                              ),
                              child: MetadataListTile(
                                icon: Icons.public,
                                name: info.name,
                                subtitle: info.templateName,
                                description:
                                    (meta['description'] as String?) ?? '',
                                tags: ((meta['tags'] as List?) ?? const [])
                                    .whereType<String>()
                                    .toList(),
                                coverImagePath:
                                    (meta['cover_image_path'] as String?) ?? '',
                                isSelected: isSelected,
                                palette: palette,
                                layout: MetadataTileLayout.topBanner,
                                onSettings: () =>
                                    _showCampaignSettings(info.name, palette),
                                topRightOverlay: isOnlineMember
                                    ? [
                                        _OnlineRoleBadge(
                                          role: role,
                                          palette: palette,
                                        ),
                                      ]
                                    : const [],
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.hubErrorGeneric(e.toString())),
              ),

              const SizedBox(height: 12),

              // Load + Delete butonları
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selectedIndex >= 0
                          ? () {
                              final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
                              if (_selectedIndex < campaigns.length) _loadCampaign(campaigns[_selectedIndex].name);
                            }
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(l10n.worldsBtnLoad),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedIndex >= 0 ? () => _deleteWorld() : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.btnDelete),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.dangerBtnBg,
                      foregroundColor: palette.dangerBtnText,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateWorldDialog() async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final templatesAsync = await ref.read(allTemplatesProvider.future);
    if (!mounted) return;
    if (templatesAsync.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.worldsNoTemplatesTitle),
          content: Text(l10n.worldsNoTemplatesBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(socialSubTabProvider.notifier).state = 'marketplace';
                ref.read(hubTabIndexProvider.notifier).state = 0;
              },
              icon: const Icon(Icons.storefront, size: 16),
              label: Text(l10n.worldsBtnGoToMarketplace),
            ),
          ],
        ),
      );
      return;
    }
    final seen = <String>{};
    final uniqueTemplates =
        templatesAsync.where((t) => seen.add(t.schemaId)).toList();
    final matched = uniqueTemplates
        .where((t) => t.schemaId == _selectedTemplate?.schemaId)
        .firstOrNull;
    _selectedTemplate = matched ?? uniqueTemplates.first;
    _nameController.clear();
    final nameFocus = FocusNode();
    // Dialog transition + IME açılışı aynı frame'e binince mobilde gecikme
    // hissediliyor; dialog mount sonrası focus iste.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (nameFocus.canRequestFocus) nameFocus.requestFocus();
    });

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.worldsCreateTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplate!.schemaId,
                  decoration: InputDecoration(labelText: l10n.worldsTemplateLabel),
                  items: uniqueTemplates
                      .map((t) => DropdownMenuItem(
                            value: t.schemaId,
                            child: Text(
                                '${t.name}  (${t.categories.length} cat)',
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    for (final t in uniqueTemplates) {
                      if (t.schemaId == id) {
                        setLocal(() => _selectedTemplate = t);
                        break;
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  focusNode: nameFocus,
                  decoration: InputDecoration(hintText: l10n.worldsNameHint),
                  onSubmitted: (_) async {
                    Navigator.pop(ctx);
                    await _createCampaign();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.btnCancel)),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _createCampaign();
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.btnCreate),
              style: FilledButton.styleFrom(
                  backgroundColor: palette.successBtnBg,
                  foregroundColor: palette.successBtnText),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWorld() async {
    final l10n = L10n.of(context)!;
    final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
    if (_selectedIndex < 0 || _selectedIndex >= campaigns.length) return;
    final name = campaigns[_selectedIndex].name;
    final worldId = campaigns[_selectedIndex].id;
    // Online role decides the UX: a player "deleting" the world is really
    // leaving it — server-side trigger releases their owned characters
    // back into the claim pool, and the local mirror is purged directly
    // (no `.trash/` indirection). DM keeps the existing soft-delete flow.
    final role = ref.read(worldRoleProvider(worldId)).valueOrNull
        ?? WorldRole.none;
    final isPlayer = role == WorldRole.player;

    // Marketplace listing kontrolü — offline-safe local index okuması.
    // Sadece DM-delete yolunda; player Leave dünyayı silmez, listing'i
    // etkilemez.
    var hasListings = false;
    if (!isPlayer) {
      try {
        final ids = await ref
            .read(marketplaceLinksLocalDsProvider)
            .getOwnedListingIds('world', name);
        hasListings = ids.isNotEmpty;
      } catch (_) {/* ignore */}
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPlayer ? l10n.worldsLeaveTitle : l10n.worldsDeleteTitle),
        content: Text(
          isPlayer
              ? l10n.worldsLeaveBody(name)
              : hasListings
                  ? '${l10n.worldsDeleteBody(name)}\n\n'
                      '${l10n.worldsDeleteMarketplaceWarning}'
                  : l10n.worldsDeleteBody(name),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final wasOnline =
                  ref.read(onlineWorldIdsProvider).contains(worldId);
              try {
                if (isPlayer) {
                  await _leaveOnlineAndPurge(worldId, name);
                } else {
                  await ref
                      .read(activeCampaignProvider.notifier)
                      .delete(name);
                  ref.invalidate(trashListProvider);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.worldsDeleteFailed(e.toString())),
                    duration: const Duration(seconds: 6),
                  ),
                );
                return;
              }
              ref.invalidate(campaignListProvider);
              ref.invalidate(campaignInfoListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isPlayer
                          ? l10n.worldsLeftSnack(name)
                          : wasOnline
                              ? l10n.worldsDeletedCloudSnack
                              : l10n.worldsDeletedSnack,
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              setState(() => _selectedIndex = -1);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).extension<DmToolColors>()!.dangerBtnBg,
              foregroundColor: Theme.of(context).extension<DmToolColors>()!.dangerBtnText,
            ),
            child: Text(isPlayer ? l10n.worldsBtnLeave : l10n.btnDelete),
          ),
        ],
      ),
    );
  }

  /// Player-side "delete world" path: leave online membership (server-side
  /// trigger releases owned characters back to the claim pool), then purge
  /// the local mirror without going through `.trash/`.
  Future<void> _leaveOnlineAndPurge(String worldId, String name) async {
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .leaveWorld(worldId);
    } catch (e) {
      // Best effort — proceed with local purge even if leave call fails
      // (e.g. already-removed by DM). Surface for diagnostics.
      debugPrint('leaveWorld error: $e');
    }
    ref.read(onlineWorldIdsProvider.notifier).remove(worldId);
    ref.invalidate(currentWorldRoleProvider);
    ref.invalidate(worldRoleProvider(worldId));
    await ref.read(activeCampaignProvider.notifier).purge(name);
  }

  Future<void> _loadCampaign(String name) async {
    // Optimistic two-phase open: synchronously flip the active campaign +
    // navigate so the route change happens in the same frame as the tap,
    // then run the heavy flush + file IO in [completeLoad]. Skeletons in
    // the affected tabs watch `activeCampaignLoadingProvider` for the
    // transient state.
    final notifier = ref.read(activeCampaignProvider.notifier);
    notifier.beginLoad(name);
    if (!mounted) return;
    context.go('/main');
    final success = await notifier.completeLoad();
    if (!success && mounted) {
      final l10n = L10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.worldsOpenFailed(name))),
      );
    }
  }

  // ignore: unused_element
  Future<String?> _showPreOpenTemplateDialogDead(dynamic prompt) {
    bool doNotShowAgain = false;
    final l10n = L10n.of(context)!;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.templateDriftTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.templateDriftBody(prompt.templateName)),
                if (prompt.diffSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.templateDriftChanges,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...prompt.diffSummary.map((line) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 ',
                            style: TextStyle(fontSize: 13)),
                        Expanded(
                            child: Text(line,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: doNotShowAgain,
                        onChanged: (v) =>
                            setDialogState(() => doNotShowAgain = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(l10n.templateDriftDoNotShowAgain,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, doNotShowAgain ? 'mute' : 'ignore'),
              child: Text(l10n.templateDriftIgnore),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: Text(l10n.templateDriftUpdate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCampaignSettings(String campaignName, DmToolColors palette) async {
    final l10n = L10n.of(context)!;

    // Load campaign data and check drift against its source template.
    Map<String, dynamic> data;
    try {
      data = await ref.read(campaignRepositoryProvider).load(campaignName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.worldsLoadFailed(e.toString()))),
        );
      }
      return;
    }

    // Fetch local updatedAt from the DB row for SaveInfoSection.
    final campaignRow = await ref
        .read(appDatabaseProvider)
        .worldsDao
        .getByName(campaignName);
    final localUpdatedAt = campaignRow?.updatedAt;
    final worldId = data['world_id'] as String? ?? campaignName;

    if (!mounted) return;

    final schemaMap = data['world_schema'] as Map<String, dynamic>?;
    final templateName = schemaMap?['name'] as String? ?? l10n.worldsUnknownTemplate;

    // Mutable metadata working copy — committed on Save.
    final existingMeta = data['metadata'];
    final workingMeta = existingMeta is Map
        ? Map<String, dynamic>.from(existingMeta)
        : <String, dynamic>{};
    workingMeta['description'] ??= '';
    workingMeta['tags'] ??= <String>[];
    workingMeta['cover_image_path'] ??= '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.worldsSettingsTitle(campaignName)),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetadataEditorSection(
                showNameField: false,
                name: campaignName,
                description: workingMeta['description'] as String? ?? '',
                tags: ((workingMeta['tags'] as List?) ?? const [])
                    .whereType<String>()
                    .toList(),
                coverImagePath:
                    workingMeta['cover_image_path'] as String? ?? '',
                onNameChanged: (_) {},
                onDescriptionChanged: (v) =>
                    workingMeta['description'] = v,
                onTagsChanged: (v) =>
                    setDialogState(() => workingMeta['tags'] = v),
                onCoverChanged: (v) => setDialogState(
                    () => workingMeta['cover_image_path'] = v),
                coverKind: MediaKind.worldCover,
                coverScopeId: campaignName,
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.description, size: 16, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 6),
                  Text(l10n.worldsTemplateLine(templateName),
                      style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                ],
              ),
              const SizedBox(height: 12),
              SaveInfoSection(
                itemName: campaignName,
                itemId: worldId,
                type: 'world',
                localUpdatedAt: localUpdatedAt,
              ),
              const SizedBox(height: 12),
              MarketplacePanel(
                itemType: 'world',
                localId: campaignName,
                title: campaignName,
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              OnlineWorldSection(
                campaignId: worldId,
                campaignName: campaignName,
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.featureCardBorder),
              const SizedBox(height: 12),
              WorldPackagesSection(campaignId: worldId),
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
              await updateCampaignMetadata(ref, campaignName, workingMeta);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.btnSave),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _createCampaign() async {
    final l10n = L10n.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
    if (campaigns.any((c) => c.name == name)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.worldsAlreadyExists)));
      return;
    }

    final templateFinal = _selectedTemplate;
    if (templateFinal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.worldsInstallTemplate)),
        );
      }
      return;
    }
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'create-world-$name',
      l10n.worldsCreatingLoad(name),
      () => ref
          .read(activeCampaignProvider.notifier)
          .create(name, template: templateFinal),
    );
    if (success && mounted) {
      context.go('/main');
    }
  }
}

/// Small pill rendered on the top-right of an online world card. Shows a
/// cloud glyph plus a role-specific icon (shield for DM, person for player).
/// Colors come from the active theme palette so it adapts across themes.
class _OnlineRoleBadge extends StatelessWidget {
  final WorldRole role;
  final DmToolColors palette;
  const _OnlineRoleBadge({required this.role, required this.palette});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final (IconData roleIcon, String tooltip) = switch (role) {
      WorldRole.dm => (Icons.shield, l10n.worldsRoleBadgeDm),
      WorldRole.player => (Icons.person, l10n.worldsRoleBadgePlayer),
      WorldRole.none => (Icons.help_outline, l10n.worldsRoleBadgeNone),
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: palette.tabBg.withValues(alpha: 0.85),
          borderRadius: palette.chr,
          border: Border.all(color: palette.featureCardAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud, size: 12, color: palette.featureCardAccent),
            const SizedBox(width: 4),
            Icon(roleIcon, size: 12, color: palette.tabActiveText),
          ],
        ),
      ),
    );
  }
}
