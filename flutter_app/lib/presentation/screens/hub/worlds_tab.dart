import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/dnd5e/package/bundled_srd_packages.dart';
import '../../../application/providers/campaign_packages_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../core/config/app_paths.dart';
import '../../../data/database/database_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/marketplace_panel.dart';
import 'social_tab.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';


class WorldsTab extends ConsumerStatefulWidget {
  const WorldsTab({super.key});

  @override
  ConsumerState<WorldsTab> createState() => _WorldsTabState();
}

class _WorldsTabState extends ConsumerState<WorldsTab> {
  final _nameController = TextEditingController();
  int _selectedIndex = -1;

  /// Bundled SRD package ids the user has ticked for the next world create.
  /// Defaults to just the recommended ones (rules). Empty set = a world
  /// created with no SRD content at all.
  late final Set<String> _selectedBundleIds = bundledSrdPackages
      .where((b) => b.recommended)
      .map((b) => b.id)
      .toSet();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
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
                    child: Text('Worlds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(socialSubTabProvider.notifier).state = 'marketplace';
                      ref.read(hubTabIndexProvider.notifier).state = 0;
                    },
                    icon: const Icon(Icons.storefront, size: 16),
                    label: const Text('Marketplace'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Select or create a campaign world.', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
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
                            'No campaigns found.\n${AppPaths.worldsDir}',
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
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
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
                              final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
                              if (_selectedIndex < campaigns.length) _loadCampaign(campaigns[_selectedIndex].name);
                            }
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Load World'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedIndex >= 0 ? () => _deleteWorld() : null,
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

              // Yeni kampanya
              Text('Create New World', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
              const SizedBox(height: 4),
              Text(
                'Pick which SRD packages this world should use. You can change them later from the world\'s settings.',
                style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in bundledSrdPackages)
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selectedBundleIds.contains(b.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedBundleIds.add(b.id);
                        } else {
                          _selectedBundleIds.remove(b.id);
                        }
                      }),
                      title: Text(b.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.tabActiveText)),
                      subtitle: Text(b.description,
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary)),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(hintText: 'World name'),
                          onSubmitted: (_) => _createCampaign(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _createCampaign,
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
            ],
          ),
        ),
      ),
    );
  }

  void _deleteWorld() {
    final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
    if (_selectedIndex < 0 || _selectedIndex >= campaigns.length) return;
    final name = campaigns[_selectedIndex].name;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete World'),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'The world will be moved to trash and automatically deleted after 30 days.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(activeCampaignProvider.notifier).delete(name);
              ref.invalidate(campaignListProvider);
              ref.invalidate(campaignInfoListProvider);
              ref.invalidate(trashListProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'World moved to trash. Cloud backup is still available '
                      'under Cloud → Worlds.',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              setState(() => _selectedIndex = -1);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).extension<DmToolColors>()!.dangerBtnBg,
              foregroundColor: Theme.of(context).extension<DmToolColors>()!.dangerBtnText,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCampaign(String name) async {
    // Global loading overlay — unified across all open/close/save/backup
    // operations. Replaces the old ad-hoc dialog.
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-world-$name',
      'Opening world "$name"...',
      () => ref.read(activeCampaignProvider.notifier).load(name),
    );

    if (!success || !mounted) return;
    if (mounted) context.go('/main');
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
          SnackBar(content: Text('Failed to load campaign: $e')),
        );
      }
      return;
    }

    // Fetch local updatedAt from the DB row for SaveInfoSection.
    final campaignRow = await ref
        .read(appDatabaseProvider)
        .campaignDao
        .getByName(campaignName);
    final localUpdatedAt = campaignRow?.updatedAt;
    final worldId = data['world_id'] as String? ?? campaignName;

    if (!mounted) return;

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
        title: Text('$campaignName — Settings'),
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
              ),
              const SizedBox(height: 12),
              _CampaignPackagesSection(campaignId: worldId),
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
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _createCampaign() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
    if (campaigns.any((c) => c.name == name)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('World already exists')));
      return;
    }

    final picked = bundledSrdPackages
        .where((b) => _selectedBundleIds.contains(b.id))
        .toList();

    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'create-world-$name',
      'Creating world "$name"...',
      () async {
        final ok = await ref
            .read(activeCampaignProvider.notifier)
            .create(name);
        if (!ok) return false;
        // After create, `activeCampaignProvider.data['world_id']` holds the
        // new campaign's DB id. Install + enable each picked bundled
        // package in that campaign.
        final campaignId = ref
            .read(activeCampaignProvider.notifier)
            .data?['world_id'] as String?;
        if (campaignId == null) return true;
        final controller =
            ref.read(campaignPackagesControllerProvider);
        for (final bundle in picked) {
          await controller.ensureAndEnable(campaignId, bundle);
        }
        return true;
      },
    );
    if (success && mounted) {
      context.go('/main');
    }
  }
}

/// Campaign-settings section listing the 4 bundled SRD packages with toggle
/// switches. Switching on triggers install-if-missing + enable in this
/// campaign; switching off disables the package in this campaign only
/// (other worlds are untouched). Lives inside the Campaign Settings dialog.
class _CampaignPackagesSection extends ConsumerWidget {
  final String campaignId;

  const _CampaignPackagesSection({required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final enabledAsync =
        ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
    final enabledSet = enabledAsync.valueOrNull ?? const <String>{};
    final controller = ref.read(campaignPackagesControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Packages',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText)),
        const SizedBox(height: 4),
        Text(
          'Choose which SRD packages appear in this world. Disabling a package '
          'here hides its content from this world only — other worlds are '
          'unaffected and the package stays installed.',
          style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
        ),
        const SizedBox(height: 8),
        for (final bundle in bundledSrdPackages)
          Consumer(builder: (context, ref, _) {
            final installedAsync =
                ref.watch(installedPackageForBundleProvider(bundle));
            final installed = installedAsync.valueOrNull;
            final enabled =
                installed != null && enabledSet.contains(installed.id);
            return SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: enabled,
              title: Text(bundle.name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              subtitle: Text(
                installed == null ? 'Not installed' : bundle.description,
                style: TextStyle(
                    fontSize: 11, color: palette.sidebarLabelSecondary),
              ),
              onChanged: (v) async {
                if (v == true) {
                  await controller.ensureAndEnable(campaignId, bundle);
                } else if (installed != null) {
                  await controller.disable(campaignId, installed.id);
                }
                ref.invalidate(installedPackageForBundleProvider(bundle));
              },
            );
          }),
      ],
    );
  }
}
