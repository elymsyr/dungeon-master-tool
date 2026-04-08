import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../core/config/app_paths.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';

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
                          borderRadius: BorderRadius.circular(4),
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
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => setState(() => _selectedIndex = index),
                            onDoubleTap: () => _loadCampaign(info.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? palette.featureCardAccent.withValues(alpha: 0.1) : palette.featureCardBg,
                                borderRadius: BorderRadius.circular(4),
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
                  _selectedTemplate ??= templates.first;
                  // initialValue items'da yoksa ilk item'ı seç
                  final validId = templates.any((t) => t.schemaId == _selectedTemplate?.schemaId)
                      ? _selectedTemplate!.schemaId
                      : templates.first.schemaId;
                  if (validId != _selectedTemplate?.schemaId) _selectedTemplate = templates.first;

                  // Deduplicate by schemaId to avoid DropdownButton assertion
                  final seen = <String>{};
                  final uniqueTemplates = templates.where((t) => seen.add(t.schemaId)).toList();
                  final finalId = uniqueTemplates.any((t) => t.schemaId == validId)
                      ? validId
                      : uniqueTemplates.first.schemaId;
                  if (finalId != validId) _selectedTemplate = uniqueTemplates.first;

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
              await ref.read(activeCampaignProvider.notifier).delete(name);
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
    final success = await ref.read(activeCampaignProvider.notifier).load(name);
    if (success && mounted) {
      context.go('/main');
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
    final success = await ref.read(activeCampaignProvider.notifier).create(name, template: _selectedTemplate);
    if (success && mounted) {
      context.go('/main');
    }
  }
}
