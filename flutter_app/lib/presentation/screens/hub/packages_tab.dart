import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/cloud_backup_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/hub_tab_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../data/database/database_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/marketplace_panel.dart';
import 'social_tab.dart';
import '../../widgets/metadata_editor_section.dart';
import '../../widgets/metadata_list_tile.dart';
import '../../widgets/save_info_section.dart';

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
                    child: Text(l10n.tabPackages,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText)),
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
                          borderRadius: palette.br,
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
                          final metaAsync =
                              ref.watch(packageMetadataProvider(info.name));
                          final meta =
                              metaAsync.valueOrNull ?? const <String, dynamic>{};
                          return InkWell(
                            borderRadius: palette.br,
                            onTap: () =>
                                setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadPackage(info.name),
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
                                icon: Icons.inventory_2,
                                name: info.name,
                                subtitle:
                                    '${info.templateName} · ${l10n.packageEntityCount(info.entityCount)}',
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
                                    _showPackageSettings(info.name, palette),
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
              ref.watch(allTemplatesProvider).when(
                data: (templates) {
                  if (templates.isEmpty) {
                    // No template → paket oluşturulamaz. Kullanıcıyı
                    // Marketplace'e yönlendir.
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.featureCardBg,
                        borderRadius: palette.br,
                        border: Border.all(color: palette.featureCardBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No templates installed',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                          const SizedBox(height: 6),
                          Text('You need at least one template to create a package. Visit the Marketplace to install one.',
                              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(socialSubTabProvider.notifier).state = 'marketplace';
                              ref.read(hubTabIndexProvider.notifier).state = 0;
                            },
                            icon: const Icon(Icons.storefront, size: 16),
                            label: const Text('Go to Marketplace'),
                          ),
                        ],
                      ),
                    );
                  }
                  final seen = <String>{};
                  final uniqueTemplates =
                      templates.where((t) => seen.add(t.schemaId)).toList();
                  final matched = uniqueTemplates
                      .where(
                          (t) => t.schemaId == _selectedTemplate?.schemaId)
                      .firstOrNull;
                  _selectedTemplate = matched ?? uniqueTemplates.first;
                  final finalId = _selectedTemplate!.schemaId;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
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
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
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

    if (!mounted) return;

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
        title: Text('$packageName — Settings'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetadataEditorSection(
                showNameField: false,
                name: packageName,
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
              await updatePackageMetadata(ref, packageName, workingMeta);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _loadPackage(String name) async {
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'open-package-$name',
      'Opening package "$name"...',
      () => ref.read(activePackageProvider.notifier).load(name),
    );
    if (!success || !mounted) return;
    if (mounted) context.go('/package');
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

    final templateFinal = _selectedTemplate;
    final success = await withLoading(
      ref.read(globalLoadingProvider.notifier),
      'create-package-$name',
      'Creating package "$name"...',
      () => ref
          .read(activePackageProvider.notifier)
          .create(name, template: templateFinal),
    );
    if (success) {
      ref.invalidate(packageListProvider);
      if (mounted) context.go('/package');
    }
  }
}
