import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../data/database/database_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/services/template_sync_service.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/schema/world_schema_hash.dart';
import '../../../core/utils/deep_copy.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/save_info_section.dart';
import '../../widgets/marketplace_panel.dart';

class PackagesTab extends ConsumerStatefulWidget {
  const PackagesTab({super.key});

  @override
  ConsumerState<PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<PackagesTab> {
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
    final l10n = L10n.of(context)!;
    final packageList = ref.watch(packageListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.tabPackages,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.tabActiveText)),
              const SizedBox(height: 4),
              Text('Select or create an entity package.',
                  style: TextStyle(
                      fontSize: 12, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 16),

              // Paket listesi
              packageList.when(
                data: (packages) => packages.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: palette.featureCardBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: palette.featureCardBorder),
                        ),
                        child: Center(
                          child: Text(
                            l10n.noPackages,
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
                        itemCount: packages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final info = packages[index];
                          final isSelected = index == _selectedIndex;
                          return InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () =>
                                setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadPackage(info.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.featureCardAccent
                                        .withValues(alpha: 0.1)
                                    : palette.featureCardBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? palette.featureCardAccent
                                      : palette.featureCardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2,
                                      size: 20,
                                      color: isSelected
                                          ? palette.featureCardAccent
                                          : palette.tabText),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(info.name,
                                            style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    palette.tabActiveText)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.description,
                                                size: 12,
                                                color: palette
                                                    .sidebarLabelSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${info.templateName} · ${l10n.packageEntityCount(info.entityCount)}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: palette
                                                      .sidebarLabelSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _showPackageSettings(info.name, palette),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(Icons.settings,
                                          size: 16,
                                          color: palette.sidebarLabelSecondary),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.check,
                                        size: 16,
                                        color: palette.featureCardAccent),
                                  ],
                                ],
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
                              final packages =
                                  ref.read(packageListProvider).valueOrNull ??
                                      [];
                              if (_selectedIndex < packages.length) {
                                _loadPackage(packages[_selectedIndex].name);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Load Package'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _selectedIndex >= 0 ? () => _deletePackage() : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.btnDelete),
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

              // Yeni paket oluşturma
              Text(l10n.packageCreate,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              const SizedBox(height: 8),
              // Template seçici
              ref.watch(allTemplatesProvider).when(
                    data: (templates) {
                      if (templates.isEmpty) return const Text('No templates');
                      final seen = <String>{};
                      final uniqueTemplates =
                          templates.where((t) => seen.add(t.schemaId)).toList();
                      final matched = uniqueTemplates
                          .where(
                              (t) => t.schemaId == _selectedTemplate?.schemaId)
                          .firstOrNull;
                      _selectedTemplate = matched ?? uniqueTemplates.first;
                      final finalId = _selectedTemplate!.schemaId;

                      return DropdownButtonFormField<String>(
                        key: ValueKey('pkg_tmpl_${uniqueTemplates.length}'),
                        initialValue: finalId,
                        decoration:
                            const InputDecoration(labelText: 'Template'),
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
                          for (final t in templates) {
                            if (t.schemaId == id) {
                              _selectedTemplate = t;
                              break;
                            }
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
                      decoration:
                          InputDecoration(hintText: l10n.packageName),
                      onSubmitted: (_) => _createPackage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createPackage,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.btnCreate),
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

  void _deletePackage() {
    final packages = ref.read(packageListProvider).valueOrNull ?? [];
    if (_selectedIndex < 0 || _selectedIndex >= packages.length) return;
    final name = packages[_selectedIndex].name;
    final l10n = L10n.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.packageDelete),
        content: Text(l10n.packageDeleteConfirm(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Cloud cleanup: load package to get package_id before local delete.
              String? packageId;
              try {
                final data = await ref.read(packageRepositoryProvider).load(name);
                packageId = data['package_id'] as String? ??
                    data['world_id'] as String? ??
                    name;
              } catch (_) {
                packageId = name;
              }
              await ref.read(activePackageProvider.notifier).delete(name);
              // Best-effort cloud cleanup — no-op when offline/signed-out.
              await ref
                  .read(cloudBackupOperationProvider.notifier)
                  .deleteBackupByItem(packageId, 'package');
              ref.invalidate(packageListProvider);
              ref.invalidate(trashListProvider);
              setState(() => _selectedIndex = -1);
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).extension<DmToolColors>()!.dangerBtnBg,
              foregroundColor:
                  Theme.of(context).extension<DmToolColors>()!.dangerBtnText,
            ),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _showPackageSettings(String packageName, DmToolColors palette) async {
    final l10n = L10n.of(context)!;

    Map<String, dynamic> data;
    try {
      data = await ref.read(packageRepositoryProvider).load(packageName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load package: $e')),
        );
      }
      return;
    }

    // Fetch local updatedAt from the DB row for SaveInfoSection.
    final packageRow =
        await ref.read(appDatabaseProvider).packageDao.getByName(packageName);
    final localUpdatedAt = packageRow?.updatedAt;
    final packageId = data['package_id'] as String? ??
        data['world_id'] as String? ??
        packageName;

    TemplateUpdatePrompt? drift;
    try {
      final result = await ref.read(templateSyncServiceProvider).checkDrift(
        campaignName: packageName,
        campaignData: data,
        ignoreDismissed: true,
      );
      drift = result.prompt;
      if (result.healedHash != null) {
        data['template_hash'] = result.healedHash!;
        await ref.read(packageRepositoryProvider).save(packageName, data);
      }
    } catch (_) {}

    if (!mounted) return;

    final schemaMap = data['world_schema'] as Map<String, dynamic>?;
    final templateName = schemaMap?['name'] as String? ?? 'Unknown';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$packageName — Settings'),
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
                itemName: packageName,
                itemId: packageId,
                type: 'package',
                localUpdatedAt: localUpdatedAt,
              ),
              const SizedBox(height: 12),
              MarketplacePanel(
                itemType: 'package',
                localId: packageName,
                title: packageName,
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
                await _applyPackageTemplateUpdate(packageName, data, drift!);
              },
              child: Text(l10n.templateDriftUpdate),
            ),
        ],
      ),
    );
  }

  Future<void> _applyPackageTemplateUpdate(
    String packageName,
    Map<String, dynamic> data,
    TemplateUpdatePrompt drift,
  ) async {
    try {
      final activeName = ref.read(activePackageProvider);
      if (activeName == packageName) {
        await ref
            .read(activePackageProvider.notifier)
            .applyTemplateUpdate(drift.newTemplate);
      } else {
        // Non-active package — mutate data map directly and save.
        data['world_schema'] = deepCopyJson(drift.newTemplate.toJson());
        data['template_id'] = drift.newTemplate.schemaId;
        data['template_hash'] = computeWorldSchemaContentHash(drift.newTemplate);
        if (drift.newTemplate.originalHash != null) {
          data['template_original_hash'] = drift.newTemplate.originalHash;
        }
        data.remove('template_dismissed_hash');
        await ref.read(packageRepositoryProvider).save(packageName, data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Package template updated to "${drift.templateName}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template update failed: $e')),
        );
      }
    }
  }

  Future<void> _loadPackage(String name) async {
    // 1. Load (with global loading overlay)
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-package-$name',
      'Opening package "$name"...',
      () => ref.read(activePackageProvider.notifier).load(name),
    );
    if (!success || !mounted) return;

    // 2. Template drift check
    final data = ref.read(activePackageProvider.notifier).data;
    if (data != null) {
      try {
        final result = await ref.read(templateSyncServiceProvider).checkDrift(
          campaignName: name,
          campaignData: data,
        );
        if (result.healedHash != null) {
          data['template_hash'] = result.healedHash!;
          await ref.read(packageRepositoryProvider).save(name, data);
        }
        final drift = result.prompt;
        if (drift != null && mounted) {
          final action = await _showPreOpenTemplateDialog(drift);
          if (!mounted) return;
          if (action == 'update') {
            await ref.read(activePackageProvider.notifier).applyTemplateUpdate(drift.newTemplate);
          } else if (action == 'mute') {
            await ref.read(activePackageProvider.notifier).muteTemplateUpdates();
          } else {
            await ref.read(activePackageProvider.notifier).dismissTemplateUpdate(drift.newHash);
          }
        }
      } catch (_) {}
    }

    // 3. Navigate
    if (mounted) context.go('/package');
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

  Future<void> _createPackage() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final l10n = L10n.of(context)!;
    final packages = ref.read(packageListProvider).valueOrNull ?? [];
    if (packages.any((p) => p.name == name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.packageAlreadyExists)));
      }
      return;
    }
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'create-package-$name',
      'Creating package "$name"...',
      () => ref
          .read(activePackageProvider.notifier)
          .create(name, template: _selectedTemplate),
    );
    if (success) {
      ref.invalidate(packageListProvider);
      if (mounted) context.go('/package');
    }
  }
}
