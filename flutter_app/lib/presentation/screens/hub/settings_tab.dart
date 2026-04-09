import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/soundpad_provider.dart';
import '../../../application/providers/template_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/config/app_paths.dart';
import '../../../data/datasources/local/campaign_local_ds.dart' show TrashItem;
import '../../../domain/entities/audio/audio_models.dart';
import '../../dialogs/theme_builder_dialog.dart';
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

              // --- SOUND LIBRARY ---
              _SoundLibrarySection(palette: palette),

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
                                Icon(item.type == 'Template' ? Icons.description : Icons.public, size: 16, color: palette.tabText),
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
    final isTemplate = item.type == 'Template';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore ${isTemplate ? 'Template' : 'World'}'),
        content: Text('Restore "${item.originalName}" from trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (isTemplate) {
                await ref.read(templateLocalDsProvider).restoreFromTrash(item.directoryName);
                ref.invalidate(trashListProvider);
                ref.invalidate(customTemplatesProvider);
                ref.invalidate(allTemplatesProvider);
              } else {
                final ds = ref.read(campaignLocalDsProvider);
                final restoreName = await ds.findUniqueRestoreName(item.originalName);
                await ds.restoreFromTrash(item.directoryName, restoreName);
                ref.invalidate(trashListProvider);
                ref.invalidate(campaignInfoListProvider);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restored "${item.originalName}"')),
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
    final typeLabel = item.type == 'Template' ? 'template' : 'world';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Permanently delete $typeLabel "${item.originalName}"?\n\nThis cannot be undone.'),
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

// =============================================================================
// Sound Library Section
// =============================================================================

class _SoundLibrarySection extends ConsumerWidget {
  final DmToolColors palette;
  const _SoundLibrarySection({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(soundpadThemesProvider);
    final libraryAsync = ref.watch(soundpadLibraryProvider);
    final notifier = ref.read(soundpadStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sound Library', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
        const SizedBox(height: 4),
        Text(
          'Soundpad Root: ${AppPaths.soundpadRoot}',
          style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),

        // --- THEMES ---
        _sectionHeader('Themes', Icons.music_note, palette),
        const SizedBox(height: 8),
        themesAsync.when(
          data: (themes) => Column(
            children: [
              if (themes.isEmpty)
                _emptyHint('No themes found', palette),
              ...themes.entries.map((e) => _ThemeCard(
                    theme: e.value,
                    palette: palette,
                    onDelete: () => _deleteTheme(context, ref, notifier, e.value),
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _createTheme(context, ref, notifier),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Theme'),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 20),

        // --- AMBIENCE ---
        _sectionHeader('Ambience', Icons.water, palette),
        const SizedBox(height: 8),
        libraryAsync.when(
          data: (library) => Column(
            children: [
              if (library.ambience.isEmpty)
                _emptyHint('No ambience sounds', palette),
              ...library.ambience.map((a) => _SoundRow(
                    name: a.name,
                    id: a.id,
                    fileCount: a.files.length,
                    palette: palette,
                    onDelete: () => _deleteSound(context, ref, notifier, 'ambience', a.id, a.name),
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addSound(context, ref, notifier, 'ambience'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Ambience'),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 20),

        // --- SFX ---
        _sectionHeader('SFX', Icons.volume_up, palette),
        const SizedBox(height: 8),
        libraryAsync.when(
          data: (library) => Column(
            children: [
              if (library.sfx.isEmpty)
                _emptyHint('No SFX sounds', palette),
              ...library.sfx.map((s) => _SoundRow(
                    name: s.name,
                    id: s.id,
                    fileCount: s.files.length,
                    palette: palette,
                    onDelete: () => _deleteSound(context, ref, notifier, 'sfx', s.id, s.name),
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addSound(context, ref, notifier, 'sfx'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add SFX'),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, DmToolColors palette) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.featureCardAccent),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
      ],
    );
  }

  Widget _emptyHint(String text, DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
    );
  }

  Future<void> _createTheme(BuildContext context, WidgetRef ref, SoundpadNotifier notifier) async {
    final result = await ThemeBuilderDialog.show(context, palette);
    if (result == null) return;

    final createResult = await notifier.createTheme(result.name, result.id, result.stateMap);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createResult.$1 ? 'Theme "${result.name}" created' : createResult.$2)),
      );
    }
  }

  Future<void> _deleteTheme(BuildContext context, WidgetRef ref, SoundpadNotifier notifier, SoundpadTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Theme'),
        content: Text('Delete theme "${theme.name}" and all its audio files?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await notifier.deleteTheme(theme.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.$1 ? 'Theme deleted' : result.$2)),
      );
    }
  }

  Future<void> _addSound(BuildContext context, WidgetRef ref, SoundpadNotifier notifier, String category) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'ogg', 'flac', 'm4a'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final controller = TextEditingController();
    // Tek dosya ise isim sor, çoklu ise dosya adlarını kullan
    if (result.files.length == 1) {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sound Name'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      final addResult = await notifier.addSound(category, name, result.files.first.path!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addResult.$1 ? 'Sound added' : addResult.$2)),
        );
      }
    } else {
      var added = 0;
      for (final file in result.files) {
        if (file.path == null) continue;
        final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final r = await notifier.addSound(category, name, file.path!);
        if (r.$1) added++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$added sound(s) added')),
        );
      }
    }
  }

  Future<void> _deleteSound(
    BuildContext context,
    WidgetRef ref,
    SoundpadNotifier notifier,
    String category,
    String soundId,
    String soundName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Sound'),
        content: Text('Remove "$soundName" from the library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await notifier.removeSound(category, soundId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.$1 ? 'Sound removed' : result.$2)),
      );
    }
  }
}

// =============================================================================
// Theme Card (settings)
// =============================================================================

class _ThemeCard extends StatelessWidget {
  final SoundpadTheme theme;
  final DmToolColors palette;
  final VoidCallback onDelete;

  const _ThemeCard({required this.theme, required this.palette, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.music_note, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(theme.name, style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                Text(
                  '${theme.states.length} state(s): ${theme.states.keys.join(", ")}',
                  style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: palette.dangerBtnBg),
            tooltip: 'Delete Theme',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sound Row (ambience / sfx item in settings)
// =============================================================================

class _SoundRow extends StatelessWidget {
  final String name;
  final String id;
  final int fileCount;
  final DmToolColors palette;
  final VoidCallback onDelete;

  const _SoundRow({
    required this.name,
    required this.id,
    required this.fileCount,
    required this.palette,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
          ),
          Text(
            '$fileCount file(s)',
            style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: palette.dangerBtnBg),
            tooltip: 'Remove',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
