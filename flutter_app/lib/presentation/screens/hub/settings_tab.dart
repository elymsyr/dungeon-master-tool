import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/config/app_paths.dart';
import '../../../data/datasources/local/campaign_local_ds.dart' show TrashItem;
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final currentTheme = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- THEME ---
              Text('Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: themeNames.length,
                itemBuilder: (context, i) {
                  final name = themeNames[i];
                  final p = themePalettes[name]!;
                  final isSelected = name == currentTheme;

                  return InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => ref.read(themeProvider.notifier).setTheme(name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.canvasBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? p.featureCardAccent : palette.featureCardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Renk noktaları
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _dot(p.featureCardAccent),
                              _dot(p.nodeBgNote),
                              _dot(p.tokenBorderHostile),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name[0].toUpperCase() + name.substring(1),
                            style: TextStyle(
                              fontSize: 10,
                              color: p.tabActiveText,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // --- LANGUAGE ---
              Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              ...['en', 'tr', 'de', 'fr'].map((code) {
                final label = switch (code) {
                  'en' => 'English',
                  'tr' => 'Türkçe',
                  'de' => 'Deutsch',
                  'fr' => 'Français',
                  _ => code,
                };
                final isSelected = currentLocale.languageCode == code;
                return ListTile(
                  leading: Radio<String>(
                    value: code,
                    groupValue: currentLocale.languageCode,
                    onChanged: (v) {
                      if (v != null) ref.read(localeProvider.notifier).setLocale(v);
                    },
                  ),
                  title: Text(label, style: TextStyle(
                    fontSize: 14,
                    color: palette.tabActiveText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  )),
                  onTap: () => ref.read(localeProvider.notifier).setLocale(code),
                  dense: true,
                );
              }),
              const SizedBox(height: 32),

              // --- VOLUME ---
              Text('Volume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.volume_down, color: palette.tabText, size: 20),
                  Expanded(
                    child: Slider(
                      value: ref.watch(uiStateProvider).volume,
                      onChanged: (v) => ref.read(uiStateProvider.notifier).update((s) => s.copyWith(volume: v)),
                    ),
                  ),
                  Icon(Icons.volume_up, color: palette.tabText, size: 20),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(ref.watch(uiStateProvider).volume * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: palette.tabText),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- DATA PATH ---
              Text('Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              _pathRow('Data Root', AppPaths.dataRoot, palette),
              _pathRow('Worlds', AppPaths.worldsDir, palette),
              _pathRow('Cache', AppPaths.cacheDir, palette),

              const SizedBox(height: 32),

              // --- TRASH ---
              Text('Trash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              ref.watch(trashListProvider).when(
                data: (items) => items.isEmpty
                    ? Text('Trash is empty.', style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final daysAgo = DateTime.now().difference(item.deletedAt).inDays;
                          final daysLeft = 30 - daysAgo;
                          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(item.deletedAt);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: palette.featureCardBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: palette.featureCardBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.public, size: 16, color: palette.tabText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.originalName, style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                                      Text(
                                        '${item.type} · $dateStr · ${daysLeft > 0 ? '${daysLeft}d until auto-delete' : 'Pending cleanup'}',
                                        style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.restore, size: 18, color: palette.successBtnBg),
                                  tooltip: 'Restore',
                                  onPressed: () => _restoreTrashItem(context, ref, item, palette),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_forever, size: 18, color: palette.dangerBtnBg),
                                  tooltip: 'Delete Permanently',
                                  onPressed: () => _permanentlyDeleteTrashItem(context, ref, item, palette),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),

            ],
          ),
        ),
      ),
    );
  }

  void _restoreTrashItem(BuildContext context, WidgetRef ref, TrashItem item, DmToolColors palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore World'),
        content: Text('Restore "${item.originalName}" from trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ds = ref.read(campaignLocalDsProvider);
              final restoreName = await ds.findUniqueRestoreName(item.originalName);
              await ds.restoreFromTrash(item.directoryName, restoreName);
              ref.invalidate(trashListProvider);
              ref.invalidate(campaignInfoListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restored as "$restoreName"')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, foregroundColor: palette.successBtnText),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _permanentlyDeleteTrashItem(BuildContext context, WidgetRef ref, TrashItem item, DmToolColors palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Permanently delete "${item.originalName}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(campaignLocalDsProvider).permanentlyDeleteFromTrash(item.directoryName);
              ref.invalidate(trashListProvider);
            },
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _pathRow(String label, String path, DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabText))),
          Expanded(child: Text(path, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
