import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/beta_provider.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/cloud_sync_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/template_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/database_provider.dart';
import '../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../../domain/entities/cloud_backup_meta.dart';
import '../theme/dm_tool_colors.dart';
import 'save_info_section.dart';

/// AppBar'da save + cloud sync durumunu gösteren unified indicator.
/// Tap → center dialog (ayarlar, aksiyonlar, storage, sync results).
///
/// [compact] true ise (hub screen) sadece storage bilgisi gösterilir.
/// false ise (main screen / inside world) tam panel açılır.
class SaveSyncIndicator extends ConsumerWidget {
  final bool compact;
  const SaveSyncIndicator({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hasCloud = SupabaseConfig.isConfigured;

    // Compact (hub) mode: independent of any item's sync state — just a
    // static cloud / save icon that opens the storage panel.
    if (compact) {
      final icon = hasCloud ? Icons.cloud_queue : Icons.save;
      return IconButton(
        icon: Icon(icon, size: 20, color: palette.sidebarLabelSecondary),
        tooltip: hasCloud ? 'Cloud Storage' : 'Save',
        onPressed: () => _showSaveSyncDialog(context, ref, compact: true),
      );
    }

    // Full (inside item) mode: reflects the active item's save + sync state.
    final saveStatus = ref.watch(saveStateProvider);
    final syncState = hasCloud ? ref.watch(cloudSyncProvider) : null;

    final (IconData icon, Color color) = _resolveIcon(
      saveStatus, syncState, palette, hasCloud,
    );

    return Stack(
      children: [
        IconButton(
          icon: (saveStatus == SaveStatus.saving ||
                  syncState?.status == CloudSyncStatus.syncing)
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 20, color: color),
          tooltip: _tooltip(saveStatus, syncState),
          onPressed: () => _showSaveSyncDialog(context, ref, compact: false),
        ),
        if (syncState != null && syncState.failedCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: palette.dangerBtnBg,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '${syncState.failedCount}',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  (IconData, Color) _resolveIcon(
    SaveStatus save,
    CloudSyncState? sync,
    DmToolColors palette,
    bool hasCloud,
  ) {
    if (!hasCloud) {
      // Local-only mode
      return switch (save) {
        SaveStatus.saving => (Icons.save, palette.featureCardAccent),
        SaveStatus.dirty => (Icons.save_outlined, palette.featureCardAccent),
        SaveStatus.saved => (Icons.save, palette.sidebarLabelSecondary),
      };
    }
    // Cloud mode — prioritize cloud status over local
    if (sync == null) {
      return (Icons.cloud_queue, palette.sidebarLabelSecondary);
    }
    return switch (sync.status) {
      CloudSyncStatus.syncing => (Icons.cloud_sync, palette.featureCardAccent),
      CloudSyncStatus.synced => (Icons.cloud_done, palette.successBtnBg),
      CloudSyncStatus.error => (Icons.cloud_off, palette.dangerBtnBg),
      CloudSyncStatus.pending => (Icons.cloud_upload_outlined, palette.featureCardAccent),
      CloudSyncStatus.idle => save == SaveStatus.dirty
          ? (Icons.cloud_upload_outlined, palette.featureCardAccent)
          : (Icons.cloud_queue, palette.sidebarLabelSecondary),
    };
  }

  String _tooltip(SaveStatus save, CloudSyncState? sync) {
    if (sync != null) {
      return switch (sync.status) {
        CloudSyncStatus.syncing => 'Syncing...',
        CloudSyncStatus.synced => 'Cloud synced',
        CloudSyncStatus.error => '${sync.failedCount} item(s) not synced',
        CloudSyncStatus.pending => 'Sync pending...',
        CloudSyncStatus.idle => save == SaveStatus.dirty
            ? 'Unsaved changes'
            : 'Save & Sync',
      };
    }
    return switch (save) {
      SaveStatus.saving => 'Saving...',
      SaveStatus.dirty => 'Unsaved changes',
      SaveStatus.saved => 'Save & Sync',
    };
  }

  void _showSaveSyncDialog(BuildContext context, WidgetRef ref, {bool compact = false}) {
    showDialog(
      context: context,
      builder: (ctx) => _SaveSyncDialog(compact: compact),
    );
  }
}

// ── Dialog ──────────────────────────────────────────────────────────

class _SaveSyncDialog extends ConsumerWidget {
  final bool compact;
  const _SaveSyncDialog({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final uiState = ref.watch(uiStateProvider);
    final saveStatus = ref.watch(saveStateProvider);
    final hasCloud = SupabaseConfig.isConfigured;
    final syncState = hasCloud ? ref.watch(cloudSyncProvider) : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ──
                Row(
                  children: [
                    Icon(
                      hasCloud ? Icons.cloud_sync : Icons.save,
                      size: 20,
                      color: palette.tabActiveText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      compact && hasCloud ? 'Cloud Storage' : 'Save & Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Active item info (full mode only) ──
                if (!compact) ...[
                  _ActiveItemSaveInfo(palette: palette),
                ],

                // ── Settings (full mode only) ──
                if (!compact) ...[
                  _SectionLabel('Settings', palette),
                  const SizedBox(height: 4),
                  _SettingsCheckbox(
                    label: 'Auto local save',
                    value: uiState.autoLocalSave,
                    onChanged: (v) => ref.read(uiStateProvider.notifier).update(
                        (s) => s.copyWith(autoLocalSave: v)),
                    palette: palette,
                  ),
                  if (hasCloud)
                    _SettingsCheckbox(
                      label: 'Auto cloud save (debounced)',
                      value: uiState.autoCloudSave,
                      onChanged: (v) => ref.read(uiStateProvider.notifier).update(
                          (s) => s.copyWith(autoCloudSave: v)),
                      palette: palette,
                    ),
                  const SizedBox(height: 16),

                  // ── Actions (full mode only) ──
                  _SectionLabel('Actions', palette),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionButton(
                        icon: Icons.save,
                        label: saveStatus == SaveStatus.saving
                            ? 'Saving...'
                            : 'Save Locally',
                        onPressed: saveStatus == SaveStatus.saving
                            ? null
                            : () => withLoading(
                                  ref.read(globalLoadingProvider.notifier),
                                  'manual-save-local',
                                  'Saving locally...',
                                  () => ref
                                      .read(saveStateProvider.notifier)
                                      .saveNow(),
                                ),
                        palette: palette,
                      ),
                      if (hasCloud)
                        _ActionButton(
                          icon: Icons.cloud_upload_outlined,
                          label: syncState?.status == CloudSyncStatus.syncing
                              ? 'Syncing...'
                              : 'Backup to Cloud',
                          onPressed: syncState?.status == CloudSyncStatus.syncing
                              ? null
                              : () => _backupToCloud(context, ref),
                          palette: palette,
                        ),
                      if (hasCloud)
                        _ActionButton(
                          icon: Icons.cloud_download_outlined,
                          label: 'Sync from Cloud',
                          onPressed: () => _syncFromCloud(context, ref),
                          palette: palette,
                        ),
                    ],
                  ),
                ],

                // ── Backups (compact mode: show list above storage) ──
                if (hasCloud && compact) ...[
                  _SectionLabel('Backups', palette),
                  const SizedBox(height: 8),
                  _CompactBackupList(palette: palette),
                  const SizedBox(height: 16),
                ],

                // ── Storage ──
                if (hasCloud) ...[
                  if (!compact) const SizedBox(height: 16),
                  if (compact) _SectionLabel('Storage', palette),
                  if (!compact) _SectionLabel('Storage', palette),
                  const SizedBox(height: 8),
                  _StorageUsageBar(palette: palette),
                ],

                // ── Sync results (full mode only) ──
                if (!compact && syncState != null && syncState.results.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionLabel('Sync Results', palette),
                  const SizedBox(height: 8),
                  ...syncState.results.map((r) => _ResultRow(r, palette)),
                ],

                // ── Compact mode hint ──
                if (compact && !hasCloud)
                  Text(
                    'Open a world to access full save & sync controls.',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Force-uploads the currently active world/package to cloud. Wraps the
  /// operation in the global loading overlay so the user sees progress.
  Future<void> _backupToCloud(BuildContext context, WidgetRef ref) async {
    // Gate up front so we can surface a clear "open something first"
    // message instead of silently doing nothing.
    final hasCampaign = ref.read(activeCampaignProvider) != null;
    final hasPackage = ref.read(activePackageProvider) != null;
    final hasTemplate = ref.read(activeTemplateProvider) != null;
    if (!hasCampaign && !hasPackage && !hasTemplate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a world, package or template first to back up to cloud.'),
        ),
      );
      return;
    }
    // Beta gate — cloud save özelliği yalnızca beta katılımcılarına açık.
    if (!ref.read(betaProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cloud save is beta-only. Open Settings → Subscriptions to join the free beta.',
          ),
        ),
      );
      return;
    }

    try {
      final ok = await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'manual-backup-cloud',
        'Backing up to cloud...',
        () => ref.read(cloudSyncProvider.notifier).backupActiveItem(),
      );
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to back up.')),
        );
        return;
      }
      final state = ref.read(cloudSyncProvider);
      final msg = state.status == CloudSyncStatus.error
          ? 'Cloud backup failed (${state.failedCount} item(s))'
          : 'Cloud backup complete';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloud backup failed: $e')),
        );
      }
    }
  }

  /// Restores the currently open world/package from its latest cloud
  /// backup. Targets ONLY the active item so the user-visible flow is:
  /// "open world → Sync from Cloud → local state is replaced with the
  /// cloud copy of this exact world". No other items are touched.
  ///
  /// Requires an active item; if the user opens the panel from the hub
  /// (nothing open), we tell them to open something first.
  Future<void> _syncFromCloud(BuildContext context, WidgetRef ref) async {
    // 1. Resolve the active item (world, package or template).
    final campaignName = ref.read(activeCampaignProvider);
    final packageName = ref.read(activePackageProvider);
    final templateId = ref.read(activeTemplateProvider);
    String? itemName;
    String? itemId;
    String? type;
    if (campaignName != null) {
      final data = ref.read(activeCampaignProvider.notifier).data;
      itemName = campaignName;
      itemId = (data?['world_id'] as String?) ?? campaignName;
      type = 'world';
    } else if (packageName != null) {
      final data = ref.read(activePackageProvider.notifier).data;
      itemName = packageName;
      itemId = (data?['package_id'] as String?) ??
          (data?['world_id'] as String?) ??
          packageName;
      type = 'package';
    } else if (templateId != null) {
      final schema = ref.read(activeTemplateProvider.notifier).schema;
      if (schema != null) {
        itemName = schema.name;
        itemId = schema.schemaId;
        type = 'template';
      }
    }

    if (itemName == null || itemId == null || type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a world, package or template first to sync from cloud.'),
        ),
      );
      return;
    }

    // 2. Fetch the cloud backup for this exact item.
    final CloudBackupRemoteDataSource remoteDs = CloudBackupRemoteDataSource();
    final loading = ref.read(globalLoadingProvider.notifier);
    const fetchTaskId = 'sync-from-cloud-fetch';
    loading.start(LoadingTask(
      id: fetchTaskId,
      message: 'Looking up cloud backup for "$itemName"...',
    ));
    final meta = await (() async {
      try {
        return await remoteDs.fetchByItem(itemId!, type!);
      } catch (e) {
        debugPrint('fetchByItem failed: $e');
        return null;
      } finally {
        loading.end(fetchTaskId);
      }
    })();

    if (meta == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No cloud backup found for "$itemName".'),
          ),
        );
      }
      return;
    }

    // 3. Destructive confirm — this replaces in-memory + on-disk state.
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore "$itemName" from cloud?'),
        content: const Text(
          'This will OVERWRITE the current local state with the cloud '
          'backup. Any unsaved changes since the last cloud backup will '
          'be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 4. Download + overwrite in place.
    try {
      await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'sync-from-cloud',
        'Restoring "$itemName" from cloud...',
        () async {
          final repo = ref.read(cloudBackupRepositoryProvider);
          final data = await repo.downloadBackup(meta.id);
          if (type == 'world') {
            await ref
                .read(activeCampaignProvider.notifier)
                .replaceWithData(data);
          } else if (type == 'template') {
            await ref
                .read(activeTemplateProvider.notifier)
                .replaceWithData(data);
            ref.invalidate(allTemplatesProvider);
          } else {
            await ref
                .read(activePackageProvider.notifier)
                .replaceWithData(data);
            // PackageScreen wraps its own activeCampaignProvider inside
            // a nested ProviderScope — invalidate the downstream providers
            // so entity/schema views re-read the restored data.
            ref.invalidate(cloudBackupListProvider);
          }
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored "$itemName" from cloud.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

// ── Helper widgets ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const _SectionLabel(this.text, this.palette);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final DmToolColors palette;

  const _SettingsCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.tabActiveText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DmToolColors palette;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: palette.featureCardBorder),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StorageUsageBar extends ConsumerWidget {
  final DmToolColors palette;
  const _StorageUsageBar({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(cloudStorageUsedProvider);
    final quotaBytes = ref.watch(betaProvider).quotaBytes;

    return storageAsync.when(
      data: (bytes) {
        final usedMb = bytes / (1024 * 1024);
        final totalMb = quotaBytes / (1024 * 1024);
        final itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / quotaBytes).clamp(0.0, 1.0);
        final remainingMb = totalMb - usedMb;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: palette.featureCardBorder,
                      color: ratio > 0.9
                          ? palette.dangerBtnBg
                          : palette.featureCardAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${usedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(0)} MB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${remainingMb.toStringAsFixed(1)} MB remaining  |  Max ${itemLimitMb.toStringAsFixed(0)} MB per item',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: palette.featureCardAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Combined: cloud backups + media assets. Temporary limit.',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 8,
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        isOfflineError(e)
            ? "You're offline — storage info unavailable."
            : 'Could not load storage info',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
    );
  }
}

/// Shows the active item's local + cloud save info inside the full-mode
/// dialog. Detects the item type by watching [activeCampaignProvider] and
/// [activePackageProvider] — if neither is set, renders nothing.
class _ActiveItemSaveInfo extends ConsumerStatefulWidget {
  final DmToolColors palette;
  const _ActiveItemSaveInfo({required this.palette});

  @override
  ConsumerState<_ActiveItemSaveInfo> createState() =>
      _ActiveItemSaveInfoState();
}

class _ActiveItemSaveInfoState extends ConsumerState<_ActiveItemSaveInfo> {
  Future<({String name, String id, String type, DateTime? updatedAt})?>?
      _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = _resolveActive();
  }

  Future<({String name, String id, String type, DateTime? updatedAt})?>
      _resolveActive() async {
    final campaignName = ref.read(activeCampaignProvider);
    final packageName = ref.read(activePackageProvider);

    if (campaignName != null) {
      final row = await ref
          .read(appDatabaseProvider)
          .campaignDao
          .getByName(campaignName);
      final data = ref.read(activeCampaignProvider.notifier).data;
      final worldId = (data?['world_id'] as String?) ?? campaignName;
      return (
        name: campaignName,
        id: worldId,
        type: 'world',
        updatedAt: row?.updatedAt,
      );
    }
    if (packageName != null) {
      final row = await ref
          .read(appDatabaseProvider)
          .packageDao
          .getByName(packageName);
      final data = ref.read(activePackageProvider.notifier).data;
      final packageId = (data?['package_id'] as String?) ??
          (data?['world_id'] as String?) ??
          packageName;
      return (
        name: packageName,
        id: packageId,
        type: 'package',
        updatedAt: row?.updatedAt,
      );
    }
    final templateId = ref.read(activeTemplateProvider);
    if (templateId != null) {
      final schema = ref.read(activeTemplateProvider.notifier).schema;
      if (schema != null) {
        DateTime? localUpdatedAt;
        try { localUpdatedAt = DateTime.parse(schema.updatedAt); } catch (_) {}
        return (
          name: schema.name,
          id: schema.schemaId,
          type: 'template',
          updatedAt: localUpdatedAt,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _infoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionLabel(info.name, widget.palette),
              const SizedBox(height: 6),
              SaveInfoSection(
                itemName: info.name,
                itemId: info.id,
                type: info.type,
                localUpdatedAt: info.updatedAt,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SyncItemResult result;
  final DmToolColors palette;
  const _ResultRow(this.result, this.palette);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (result.result) {
      SyncResult.synced => (Icons.cloud_done, palette.successBtnBg, 'Synced'),
      SyncResult.pending => (Icons.cloud_upload_outlined, palette.featureCardAccent, 'Pending'),
      SyncResult.tooLarge => (Icons.warning_amber, palette.dangerBtnBg, 'Too large (>5 MB)'),
      SyncResult.quotaExceeded => (Icons.storage, palette.dangerBtnBg, 'Quota exceeded'),
      SyncResult.networkError => (Icons.wifi_off, palette.dangerBtnBg, 'Network error'),
    };

    final typeIcon = switch (result.type) {
      'world' => Icons.public,
      'template' => Icons.description,
      'package' => Icons.inventory_2,
      _ => Icons.file_present,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            Icon(typeIcon, size: 14, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(result.name,
                  style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
            ),
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Compact backup list — top-right cloud icon dialog'unda storage bar'ın
/// üstünde gösterilir. Restore/delete aksiyonları ile birlikte cloud
/// backup'ları listeler.
class _CompactBackupList extends ConsumerWidget {
  final DmToolColors palette;
  const _CompactBackupList({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupsAsync = ref.watch(cloudBackupListProvider);
    final opState = ref.watch(cloudBackupOperationProvider);

    // Surface operation completion as snackbar.
    ref.listen<CloudBackupOperationState>(cloudBackupOperationProvider, (prev, next) {
      if (prev?.isBusy != true) return;
      if (next.errorMessage != null) {
        final msg = next.errorMessage!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.startsWith("You're offline") ? msg : 'Backup error: $msg',
            ),
          ),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      } else if (!next.isBusy && prev?.type == CloudBackupOpType.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored')),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      } else if (!next.isBusy && prev?.type == CloudBackupOpType.deleting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup deleted')),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      }
    });

    return backupsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => Text(
        isOfflineError(e)
            ? "You're offline — backups unavailable."
            : 'Could not load backups',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
      data: (backups) {
        if (backups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 16, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No cloud backups yet',
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                ),
              ],
            ),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Container(
            decoration: BoxDecoration(
              color: palette.featureCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.featureCardBorder),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: backups.length,
              separatorBuilder: (ctx, i) => Divider(height: 1, color: palette.featureCardBorder),
              itemBuilder: (ctx, i) =>
                  _BackupRow(meta: backups[i], palette: palette, busy: opState.isBusy),
            ),
          ),
        );
      },
    );
  }
}

class _BackupRow extends ConsumerWidget {
  final CloudBackupMeta meta;
  final DmToolColors palette;
  final bool busy;
  const _BackupRow({required this.meta, required this.palette, required this.busy});

  IconData get _typeIcon => switch (meta.type) {
        'world' => Icons.public,
        'template' => Icons.description_outlined,
        'package' => Icons.inventory_2_outlined,
        _ => Icons.backup,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat.yMMMd().add_Hm().format(meta.createdAt.toLocal());
    final sizeKb = (meta.sizeBytes / 1024).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(_typeIcon, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
                Text(
                  '$date · $sizeKb KB',
                  style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download, size: 16, color: palette.featureCardAccent),
            tooltip: 'Restore',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: Text('Restore "${meta.itemName}"?'),
                        content: const Text('This overwrites the local copy.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              child: const Text('Restore')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref.read(cloudBackupOperationProvider.notifier).restoreBackup(meta);
                    }
                  },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: palette.dangerBtnBg),
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Delete backup?'),
                        content: Text('Permanently delete "${meta.itemName}" from cloud.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(dctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.dangerBtnBg,
                              foregroundColor: palette.dangerBtnText,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref.read(cloudBackupOperationProvider.notifier).deleteBackup(meta.id);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
