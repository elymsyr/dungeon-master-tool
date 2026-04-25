import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../application/providers/soundpad_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../application/services/campaign_import_service.dart';
import '../../../core/config/app_paths.dart';
import '../../../core/utils/screen_type.dart';
import '../../../data/datasources/local/campaign_local_ds.dart' show TrashItem;
import '../../../domain/entities/audio/audio_models.dart';
import '../../dialogs/theme_builder_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/palettes.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  @override
  void initState() {
    super.initState();
    // Tab her açıldığında storage-ilgili provider'ları yenile:
    // trash sayısı, beta cloud quota, sound library + toplam boyut.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(trashListProvider);
      ref.read(betaProvider.notifier).refresh();
      ref.invalidate(soundpadLibraryProvider);
      ref.invalidate(soundpadTotalSizeProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final currentTheme = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = L10n.of(context)!;
    final phone = isPhone(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SUBSCRIPTIONS (top of settings) ---
              _SubscriptionsSection(palette: palette),
              const SizedBox(height: 32),

              // --- THEME ---
              Text(l10n.lblTheme, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: phone ? 2 : 4,
                  childAspectRatio: phone ? 2.4 : 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: themeNames.length,
                itemBuilder: (context, i) {
                  final name = themeNames[i];
                  final p = themePalettes[name]!;
                  final isSelected = name == currentTheme;

                  return InkWell(
                    borderRadius: palette.br,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.canvasBg,
                        borderRadius: palette.br,
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
              Text(l10n.lblLanguage, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: currentLocale.languageCode,
                onChanged: (v) {
                  if (v != null) {
                    ref.read(localeProvider.notifier).setLocale(v);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['en', 'tr', 'de', 'fr'].map((code) {
                    final label = switch (code) {
                      'en' => 'English',
                      'tr' => 'Türkçe',
                      'de' => 'Deutsch',
                      'fr' => 'Français',
                      _ => code,
                    };
                    final isSelected = currentLocale.languageCode == code;
                    return ListTile(
                      leading: Radio<String>(value: code),
                      title: Text(label, style: TextStyle(
                        fontSize: 14,
                        color: palette.tabActiveText,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                      onTap: () => ref.read(localeProvider.notifier).setLocale(code),
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // --- VOLUME ---
              Text(l10n.settingsVolume, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
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
              Text(l10n.settingsData, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              _pathRow(l10n.dataPathRoot, AppPaths.dataRoot, palette),
              _pathRow(l10n.dataPathWorlds, AppPaths.worldsDir, palette),
              _pathRow(l10n.dataPathCache, AppPaths.cacheDir, palette),
              const SizedBox(height: 8),
              _DataPathActions(path: AppPaths.dataRoot, palette: palette),

              const SizedBox(height: 32),

              // --- LEGACY IMPORT (v0.8.4 Python) ---
              Text(l10n.settingsImportLegacy, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 6),
              Text(
                l10n.settingsImportLegacyDesc,
                style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _importLegacyWorlds(context, ref),
                  icon: const Icon(Icons.drive_folder_upload),
                  label: Text(l10n.btnImportLegacyWorlds),
                ),
              ),

              const SizedBox(height: 32),

              // --- TRASH ---
              Text(l10n.settingsTrash, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
              const SizedBox(height: 12),
              ref.watch(trashListProvider).when(
                data: (items) => items.isEmpty
                    ? Text(l10n.trashEmpty, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary))
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
                              borderRadius: palette.br,
                              border: Border.all(color: palette.featureCardBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                item.type == 'Template'
                                    ? Icons.description
                                    : item.type == 'Package'
                                        ? Icons.inventory_2
                                        : item.type == 'Character'
                                            ? Icons.person
                                            : Icons.public,
                                size: 16,
                                color: palette.tabText,
                              ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.originalName, style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
                                      Text(
                                        '${item.type} · $dateStr · ${daysLeft > 0 ? l10n.trashAutoDeleteIn(daysLeft) : l10n.trashPendingCleanup}',
                                        style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.restore, size: 18, color: palette.successBtnBg),
                                  tooltip: l10n.btnRestore,
                                  onPressed: () => _restoreTrashItem(context, ref, item, palette),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_forever, size: 18, color: palette.dangerBtnBg),
                                  tooltip: l10n.trashDeleteTitle,
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
    final l10n = L10n.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trashRestoreTitle(item.type)),
        content: Text(l10n.trashRestoreBody(item.originalName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.type == 'Package') {
                final ds = ref.read(packageLocalDsProvider);
                final restoredData = await ds.restoreFromTrash(item.directoryName);
                if (restoredData != null) {
                  final name = restoredData['package_name'] as String? ?? item.originalName;
                  await ref.read(packageRepositoryProvider).save(name, restoredData);
                }
                ref.invalidate(trashListProvider);
                ref.invalidate(packageListProvider);
              } else if (item.type == 'Character') {
                await ref
                    .read(characterListProvider.notifier)
                    .restoreFromTrash(item.directoryName);
                ref.invalidate(trashListProvider);
              } else {
                final ds = ref.read(campaignLocalDsProvider);
                final restoreName = await ds.findUniqueRestoreName(item.originalName);
                await ds.restoreFromTrash(item.directoryName, restoreName);
                ref.invalidate(trashListProvider);
                ref.invalidate(campaignInfoListProvider);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.trashRestoreSuccess(item.originalName))),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: palette.successBtnBg, foregroundColor: palette.successBtnText),
            child: Text(l10n.btnRestore),
          ),
        ],
      ),
    );
  }

  void _permanentlyDeleteTrashItem(BuildContext context, WidgetRef ref, TrashItem item, DmToolColors palette) {
    final l10n = L10n.of(context)!;
    final typeLabel = item.type.toLowerCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trashDeleteTitle),
        content: Text(l10n.trashDeleteBody(typeLabel, item.originalName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.type == 'Package') {
                await ref.read(packageLocalDsProvider).permanentlyDeleteFromTrash(item.directoryName);
              } else {
                await ref.read(campaignLocalDsProvider).permanentlyDeleteFromTrash(item.directoryName);
              }
              ref.invalidate(trashListProvider);
            },
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _importLegacyWorlds(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context)!;
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.importLegacyDialogTitle,
    );
    if (dir == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    CampaignImportResult result;
    try {
      result = await ref
          .read(campaignImportServiceProvider)
          .importFromDirectory(dir);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importLegacyErrorGeneric(e.toString()))),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ref.invalidate(campaignListProvider);
    ref.invalidate(campaignInfoListProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_buildImportSummary(l10n, result)),
        duration: const Duration(seconds: 6),
        backgroundColor: result.errors.isNotEmpty
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }

  String _buildImportSummary(L10n l10n, CampaignImportResult result) {
    if (!result.hasAny && result.skipped.isNotEmpty) {
      return l10n.importLegacyNoWorlds;
    }
    final parts = <String>[];
    if (result.imported.isNotEmpty) {
      parts.add(l10n.importLegacyImportedCount(result.imported.length));
    }
    if (result.renamed.isNotEmpty) {
      parts.add(l10n.importLegacyRenamed(result.renamed.length));
    }
    if (result.skipped.isNotEmpty) {
      parts.add(l10n.importLegacySkipped(result.skipped.length));
    }
    if (result.errors.isNotEmpty) {
      parts.add(l10n.importLegacyErrors(result.errors.length));
    }
    return parts.join(' · ');
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

/// Copy path + open-in-file-manager helper. Open button is desktop-only.
class _DataPathActions extends StatelessWidget {
  final String path;
  final DmToolColors palette;
  const _DataPathActions({required this.path, required this.palette});

  bool get _canOpen =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _open(BuildContext context) async {
    try {
      final String exe;
      final List<String> args;
      if (Platform.isWindows) {
        exe = 'explorer';
        args = [path];
      } else if (Platform.isMacOS) {
        exe = 'open';
        args = [path];
      } else {
        exe = 'xdg-open';
        args = [path];
      }
      await Process.start(exe, args, mode: ProcessStartMode.detached);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open folder: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: path));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Path copied')));
            }
          },
          icon: const Icon(Icons.copy, size: 14),
          label: const Text('Copy path',
              style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 28),
          ),
        ),
        if (_canOpen) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.folder_open, size: 14),
            label: const Text('Open data folder',
                style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
            ),
          ),
        ],
      ],
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
    final l10n = L10n.of(context)!;
    final themesAsync = ref.watch(soundpadThemesProvider);
    final libraryAsync = ref.watch(soundpadLibraryProvider);
    final totalSizeAsync = ref.watch(soundpadTotalSizeProvider);
    final notifier = ref.read(soundpadStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSoundLibrary, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
        const SizedBox(height: 4),
        Text(
          l10n.soundpadRootLabel(AppPaths.soundpadRoot),
          style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          totalSizeAsync.when(
            data: (bytes) => l10n.soundpadTotalSize(
                (bytes / (1024 * 1024)).toStringAsFixed(1)),
            loading: () => l10n.soundpadTotalSize('—'),
            error: (_, _) => l10n.soundpadTotalSize('?'),
          ),
          style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
        ),

        const SizedBox(height: 16),

        // --- THEMES ---
        _sectionHeader(l10n.soundpadThemes, Icons.music_note, palette),
        const SizedBox(height: 8),
        themesAsync.when(
          data: (themes) => Column(
            children: [
              if (themes.isEmpty)
                _emptyHint(l10n.soundpadNoThemes, palette),
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
                  label: Text(l10n.soundpadCreateTheme),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 20),

        // --- AMBIENCE ---
        _sectionHeader(l10n.soundpadTabAmbience, Icons.water, palette),
        const SizedBox(height: 8),
        libraryAsync.when(
          data: (library) => Column(
            children: [
              if (library.ambience.isEmpty)
                _emptyHint(l10n.soundpadNoAmbience, palette),
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
                  label: Text(l10n.soundpadAddAmbience),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 20),

        // --- SFX ---
        _sectionHeader(l10n.soundpadTabSfx, Icons.volume_up, palette),
        const SizedBox(height: 8),
        libraryAsync.when(
          data: (library) => Column(
            children: [
              if (library.sfx.isEmpty)
                _emptyHint(l10n.soundpadNoSfx, palette),
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
                  label: Text(l10n.soundpadAddSfx),
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
    final l10n = L10n.of(context)!;
    final result = await ThemeBuilderDialog.show(context, palette);
    if (result == null) return;

    final createResult = await notifier.createTheme(result.name, result.id, result.stateMap);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createResult.$1 ? l10n.soundpadThemeCreated(result.name) : createResult.$2)),
      );
    }
  }

  Future<void> _deleteTheme(BuildContext context, WidgetRef ref, SoundpadNotifier notifier, SoundpadTheme theme) async {
    final l10n = L10n.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.soundpadDeleteThemeTitle),
        content: Text(l10n.soundpadDeleteThemeBody(theme.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await notifier.deleteTheme(theme.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.$1 ? l10n.soundpadThemeDeleted : result.$2)),
      );
    }
  }

  Future<void> _addSound(BuildContext context, WidgetRef ref, SoundpadNotifier notifier, String category) async {
    final l10n = L10n.of(context)!;
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
          title: Text(l10n.soundpadAddSoundDialogTitle),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.btnCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.btnAdd),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      final addResult = await notifier.addSound(category, name, result.files.first.path!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addResult.$1 ? l10n.soundpadSoundAdded : addResult.$2)),
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
          SnackBar(content: Text(l10n.soundpadSoundsAdded(added))),
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
    final l10n = L10n.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.soundpadRemoveSoundTitle),
        content: Text(l10n.soundpadRemoveSoundBody(soundName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: palette.dangerBtnBg, foregroundColor: palette.dangerBtnText),
            child: Text(l10n.btnRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await notifier.removeSound(category, soundId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.$1 ? l10n.soundpadSoundRemoved : result.$2)),
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
    final l10n = L10n.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
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
                  l10n.soundpadStatesCount(theme.states.length, theme.states.keys.join(", ")),
                  style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: palette.dangerBtnBg),
            tooltip: l10n.soundpadDeleteThemeTitle,
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
    final l10n = L10n.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
          ),
          Text(
            l10n.soundpadFilesCount(fileCount),
            style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: palette.dangerBtnBg),
            tooltip: l10n.btnRemove,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Subscriptions Section — Beta Program (first 200 users, 50 MB cloud save)
// =============================================================================

class _SubscriptionsSection extends ConsumerWidget {
  final DmToolColors palette;
  const _SubscriptionsSection({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final auth = ref.watch(authProvider);
    final beta = ref.watch(betaProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsSubscriptions,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: palette.tabActiveText,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border.all(color: palette.featureCardBorder),
            borderRadius: palette.br,
          ),
          child: _buildBody(context, ref, l10n, auth, beta),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    AuthState? auth,
    BetaState beta,
  ) {
    // Header — every state shows the title + icon.
    final header = Row(
      children: [
        Icon(Icons.science_outlined,
            size: 18, color: palette.featureCardAccent),
        const SizedBox(width: 8),
        Text(
          l10n.subsBetaTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.tabActiveText,
          ),
        ),
      ],
    );

    // State: not signed in
    if (auth == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaSignInHint,
            style: TextStyle(fontSize: 12, color: palette.tabText, height: 1.4),
          ),
        ],
      );
    }

    // State: loading
    if (beta.loading && !beta.isActive && beta.slotNumber == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    // State: beta active
    if (beta.isActive) {
      final usedMb = (beta.usedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (beta.quotaBytes / (1024 * 1024)).toStringAsFixed(0);
      final lastSeen = beta.lastActiveAt == null
          ? '—'
          : DateFormat.yMMMd().add_Hm().format(beta.lastActiveAt!.toLocal());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle,
                  size: 18, color: palette.successBtnBg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  beta.slotNumber == null
                      ? l10n.subsBetaTitle
                      : l10n.subsBetaActiveBadge(beta.slotNumber!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: beta.usageRatio,
              minHeight: 8,
              backgroundColor: palette.featureCardBorder,
              valueColor:
                  AlwaysStoppedAnimation<Color>(palette.featureCardAccent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.subsBetaQuotaLabel(usedMb, totalMb),
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaQuotaScopeNote,
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaLastSeen(lastSeen),
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaInactivityDisclaimer,
            style: TextStyle(
              fontSize: 11,
              color: palette.sidebarLabelSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaRoadmap,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: palette.featureCardAccent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.dangerBtnBg,
                side: BorderSide(color: palette.dangerBtnBg),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: palette.br),
              ),
              onPressed: beta.loading ? null : () => _leave(context, ref, l10n),
              child: Text(
                l10n.subsBetaLeaveBtn,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }

    // State: beta full
    if (beta.slotsRemaining <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaFull,
            style: TextStyle(fontSize: 12, color: palette.tabText, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.subsBetaRoadmap,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: palette.featureCardAccent,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    // State: can join (slot available)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 10),
        Text(
          l10n.subsBetaDescription,
          style: TextStyle(fontSize: 12, color: palette.tabText, height: 1.4),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.subsBetaInactivityDisclaimer,
          style: TextStyle(
            fontSize: 11,
            color: palette.sidebarLabelSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.subsBetaSlotsRemaining(beta.slotsRemaining),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.featureCardAccent,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.featureCardAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape:
                  RoundedRectangleBorder(borderRadius: palette.br),
            ),
            onPressed: beta.loading
                ? null
                : () => _join(context, ref, l10n),
            child: beta.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l10n.subsBetaJoinBtn,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.subsBetaRoadmap,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: palette.featureCardAccent,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _join(
      BuildContext context, WidgetRef ref, L10n l10n) async {
    final result = await ref.read(betaProvider.notifier).joinBeta();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case BetaJoinStatus.joined:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.subsBetaActiveBadge(result.slotNumber ?? 0),
            ),
          ),
        );
      case BetaJoinStatus.already:
        // No message — UI state already reflects membership.
        break;
      case BetaJoinStatus.full:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.subsBetaJoinFailedFull)),
        );
      case BetaJoinStatus.notSignedIn:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.subsBetaSignInHint)),
        );
      case BetaJoinStatus.error:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.subsBetaJoinFailedGeneric(
                  result.errorMessage ?? 'unknown'),
            ),
          ),
        );
    }
  }

  Future<void> _leave(
      BuildContext context, WidgetRef ref, L10n l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.subsBetaLeaveConfirmTitle),
        content: Text(l10n.subsBetaLeaveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.subsBetaLeaveBtn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(betaProvider.notifier).leaveBeta();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.subsBetaLeaveSuccess : l10n.subsBetaLeaveFailed,
        ),
      ),
    );
  }
}
