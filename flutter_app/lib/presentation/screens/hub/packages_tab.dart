import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/package_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

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
                                  if (isSelected)
                                    Icon(Icons.check,
                                        size: 16,
                                        color: palette.featureCardAccent),
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
              await ref.read(activePackageProvider.notifier).delete(name);
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

  Future<void> _loadPackage(String name) async {
    final success =
        await ref.read(activePackageProvider.notifier).load(name);
    if (success && mounted) {
      context.go('/package');
    }
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
    final success = await ref
        .read(activePackageProvider.notifier)
        .create(name, template: _selectedTemplate);
    if (success && mounted) {
      context.go('/package');
    }
  }
}
