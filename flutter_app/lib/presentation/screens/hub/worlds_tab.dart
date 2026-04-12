import 'package:flutter/material.dart';

import '../../../core/utils/deep_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/services/template_sync_service.dart';
import '../../../core/config/app_paths.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/schema/world_schema_hash.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/save_info_section.dart';
import '../../widgets/marketplace_panel.dart';


class WorldsTab extends ConsumerStatefulWidget {
  const WorldsTab({super.key});

  @override
  ConsumerState<WorldsTab> createState() => _WorldsTabState();
}

class _WorldsTabState extends ConsumerState<WorldsTab> {
  final _nameController = TextEditingController();
  int _selectedIndex = -1;
  WorldSchema? _selectedTemplate;

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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Worlds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
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
                          return InkWell(
                            borderRadius: palette.br,
                            onTap: () => setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadCampaign(info.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? palette.featureCardAccent.withValues(alpha: 0.1) : palette.featureCardBg,
                                borderRadius: palette.br,
                                border: Border.all(
                                  color: isSelected ? palette.featureCardAccent : palette.featureCardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 20, color: isSelected ? palette.featureCardAccent : palette.tabText),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(info.name, style: TextStyle(fontSize: 14, color: palette.tabActiveText)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.description, size: 12, color: palette.sidebarLabelSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              info.templateName,
                                              style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.settings, size: 16, color: palette.tabText),
                                    tooltip: 'World Settings',
                                    onPressed: () => _showCampaignSettings(info.name, palette),
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check, size: 16, color: palette.featureCardAccent),
                                ],
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
              const SizedBox(height: 8),
              // Template seçici
              ref.watch(allTemplatesProvider).when(
                data: (templates) {
                  if (templates.isEmpty) return const Text('No templates');
                  // Deduplicate by schemaId to avoid DropdownButton assertion.
                  final seen = <String>{};
                  final uniqueTemplates = templates.where((t) => seen.add(t.schemaId)).toList();
                  // ALWAYS refresh `_selectedTemplate` to the matching object
                  // from the freshly-fetched list. The schemaId stays stable
                  // across template edits, so the old "only swap when the id
                  // disappears" check kept us pointing at a stale in-memory
                  // copy whenever the user edited a template — and the new
                  // campaign would then be created from pre-edit columns
                  // (e.g., the removed `lvl` column would reappear).
                  final matched = uniqueTemplates
                      .where((t) => t.schemaId == _selectedTemplate?.schemaId)
                      .firstOrNull;
                  _selectedTemplate = matched ?? uniqueTemplates.first;
                  final finalId = _selectedTemplate!.schemaId;

                  return DropdownButtonFormField<String>(
                    key: ValueKey('tmpl_${uniqueTemplates.length}'),
                    initialValue: finalId,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: uniqueTemplates.map((t) => DropdownMenuItem(
                      value: t.schemaId,
                      child: Text('${t.name}  (${t.categories.length} cat)', style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      for (final t in templates) {
                        if (t.schemaId == id) { _selectedTemplate = t; break; }
                      }
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
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
                    style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, foregroundColor: palette.successBtnText),
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
              // Cloud cleanup: load campaign data to get world_id before local
              // delete. If either the load or the cloud delete fails, we still
              // proceed with local delete (it's not fatal).
              String? worldId;
              try {
                final data = await ref.read(campaignRepositoryProvider).load(name);
                worldId = data['world_id'] as String? ?? name;
              } catch (_) {
                worldId = name;
              }
              await ref.read(activeCampaignProvider.notifier).delete(name);
              // Best-effort cloud cleanup — no-op when offline/signed-out.
              await ref
                  .read(cloudBackupOperationProvider.notifier)
                  .deleteBackupByItem(worldId, 'world');
              ref.invalidate(campaignListProvider);
              ref.invalidate(campaignInfoListProvider);
              ref.invalidate(trashListProvider);
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

    // 4. Template drift check — uyarı dialogu göster (loading sonrası)
    final drift = ref.read(pendingTemplateUpdateProvider);
    if (drift != null) {
      ref.read(pendingTemplateUpdateProvider.notifier).state = null;
      final action = await _showPreOpenTemplateDialog(drift);
      if (!mounted) return;
      if (action == 'update') {
        await ref.read(activeCampaignProvider.notifier).applyTemplateUpdate(drift.newTemplate);
      } else if (action == 'mute') {
        await ref.read(activeCampaignProvider.notifier).muteTemplateUpdates();
      } else {
        await ref.read(activeCampaignProvider.notifier).dismissTemplateUpdate(drift.newHash);
      }
    }

    // 5. Navigate
    if (mounted) context.go('/main');
  }

  Future<String?> _showPreOpenTemplateDialog(TemplateUpdatePrompt prompt) {
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

    TemplateUpdatePrompt? drift;
    try {
      final result = await ref.read(templateSyncServiceProvider).checkDrift(
        campaignName: campaignName,
        campaignData: data,
        ignoreDismissed: true,
      );
      drift = result.prompt;
      if (result.healedHash != null) {
        data['template_hash'] = result.healedHash!;
        await ref.read(campaignRepositoryProvider).save(campaignName, data);
      }
    } catch (_) {
      // Best-effort — show the dialog without drift info.
    }

    if (!mounted) return;

    final schemaMap = data['world_schema'] as Map<String, dynamic>?;
    final templateName = schemaMap?['name'] as String? ?? 'Unknown';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$campaignName — Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, size: 16, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 6),
                  Text('Template: $templateName',
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
              if (drift == null)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: palette.successBtnBg),
                    const SizedBox(width: 6),
                    Text(l10n.templateDriftUpToDate,
                        style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: palette.featureCardAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(l10n.templateDriftBody(drift.templateName),
                          style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                    ),
                  ],
                ),
                if (drift.diffSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.templateDriftChanges,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...drift.diffSummary.map((line) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 ', style: TextStyle(fontSize: 12)),
                        Expanded(child: Text(line, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.btnCancel),
          ),
          if (drift != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _applyTemplateFromSettings(campaignName, data, drift!);
              },
              child: Text(l10n.templateDriftUpdate),
            ),
        ],
      ),
    );
  }

  /// Applies a template update from the settings dialog. Handles both the
  /// active campaign (uses the notifier) and non-active campaigns (direct
  /// repo save).
  Future<void> _applyTemplateFromSettings(
    String campaignName,
    Map<String, dynamic> data,
    TemplateUpdatePrompt drift,
  ) async {
    try {
      final activeName = ref.read(activeCampaignProvider);
      if (activeName == campaignName) {
        await ref
            .read(activeCampaignProvider.notifier)
            .applyTemplateUpdate(drift.newTemplate);
      } else {
        // Non-active campaign — mutate data map directly and save.
        data['world_schema'] = deepCopyJson(drift.newTemplate.toJson());
        data['template_id'] = drift.newTemplate.schemaId;
        data['template_hash'] = computeWorldSchemaContentHash(drift.newTemplate);
        if (drift.newTemplate.originalHash != null) {
          data['template_original_hash'] = drift.newTemplate.originalHash;
        }
        data.remove('template_dismissed_hash');
        await ref.read(campaignRepositoryProvider).save(campaignName, data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.templateDriftUpdated)),
        );
      }
    } catch (e, st) {
      debugPrint('Template apply from settings failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _createCampaign() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final campaigns = ref.read(campaignInfoListProvider).valueOrNull ?? [];
    if (campaigns.any((c) => c.name == name)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('World already exists')));
      return;
    }
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'create-world-$name',
      'Creating world "$name"...',
      () => ref
          .read(activeCampaignProvider.notifier)
          .create(name, template: _selectedTemplate),
    );
    if (success && mounted) {
      context.go('/main');
    }
  }
}
