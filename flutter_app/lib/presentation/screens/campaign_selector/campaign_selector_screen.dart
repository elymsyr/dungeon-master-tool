import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../core/config/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';

/// Kampanya seçim ekranı — Python ui/campaign_selector.py karşılığı.
class CampaignSelectorScreen extends ConsumerStatefulWidget {
  const CampaignSelectorScreen({super.key});

  @override
  ConsumerState<CampaignSelectorScreen> createState() =>
      _CampaignSelectorScreenState();
}

class _CampaignSelectorScreenState
    extends ConsumerState<CampaignSelectorScreen> {
  final _nameController = TextEditingController();
  int _selectedIndex = -1;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final campaignList = ref.watch(campaignListProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Icon(Icons.castle, size: 48, color: palette.tabIndicator),
              const SizedBox(height: 12),
              Text(
                l10n.lblSelectCampaign,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Kampanya listesi
              Flexible(
                child: campaignList.when(
                  data: (campaigns) => campaigns.isEmpty
                      ? Center(
                          child: Text(
                            'No campaigns found in:\n${AppPaths.worldsDir}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.sidebarLabelSecondary),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: campaigns.length,
                          itemBuilder: (context, index) {
                            final name = campaigns[index];
                            final isSelected = index == _selectedIndex;
                            return ListTile(
                              leading: Icon(
                                Icons.public,
                                color: isSelected
                                    ? palette.tabIndicator
                                    : palette.sidebarLabelSecondary,
                              ),
                              title: Text(name),
                              selected: isSelected,
                              selectedTileColor:
                                  palette.tabIndicator.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () =>
                                  setState(() => _selectedIndex = index),
                              onLongPress: () => _loadCampaign(name),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),

              const SizedBox(height: 16),

              // Yükle butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedIndex >= 0
                      ? () {
                          final campaigns =
                              ref.read(campaignListProvider).valueOrNull ?? [];
                          if (_selectedIndex < campaigns.length) {
                            _loadCampaign(campaigns[_selectedIndex]);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.btnSave), // TODO: BTN_LOAD key
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Yeni kampanya oluştur
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: l10n.lblWorldName,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _createCampaign(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createCampaign,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.btnCreate),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.successBtnBg,
                      foregroundColor: palette.successBtnText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Dil + Tema seçici (alt kısım)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Dil
                  DropdownButton<String>(
                    value: ref.watch(localeProvider).languageCode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                    ],
                    onChanged: (code) {
                      if (code != null) {
                        ref.read(localeProvider.notifier).setLocale(code);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  // Tema
                  DropdownButton<String>(
                    value: ref.watch(themeProvider),
                    underline: const SizedBox.shrink(),
                    items: themeNames
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: themePalettes[name]?.canvasBg,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: Colors.white24),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(name[0].toUpperCase() +
                                      name.substring(1)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (name) {
                      if (name != null) {
                        ref.read(themeProvider.notifier).setTheme(name);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadCampaign(String name) async {
    final success =
        await ref.read(activeCampaignProvider.notifier).load(name);
    if (success && mounted) {
      context.go('/main');
    }
  }

  Future<void> _createCampaign() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final campaigns = ref.read(campaignListProvider).valueOrNull ?? [];
    if (campaigns.contains(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign already exists')),
        );
      }
      return;
    }

    final success =
        await ref.read(activeCampaignProvider.notifier).create(name);
    if (success && mounted) {
      context.go('/main');
    }
  }
}
