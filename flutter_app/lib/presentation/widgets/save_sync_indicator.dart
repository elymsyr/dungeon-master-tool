import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/cloud_sync_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
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
                      label: 'Auto cloud backup before exit',
                      value: uiState.autoCloudBackupBeforeExit,
                      onChanged: (v) => ref.read(uiStateProvider.notifier).update(
                          (s) => s.copyWith(autoCloudBackupBeforeExit: v)),
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
                            : () => ref.read(saveStateProvider.notifier).saveNow(),
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
                              : () => ref.read(cloudSyncProvider.notifier).syncNow(),
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

                // ── Storage ──
                if (hasCloud) ...[
                  if (!compact) const SizedBox(height: 16),
                  if (!compact) _SectionLabel('Storage', palette),
                  if (!compact) const SizedBox(height: 8),
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

  Future<void> _syncFromCloud(BuildContext context, WidgetRef ref) async {
    final backups = await ref.read(cloudBackupListProvider.future);
    if (backups.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cloud backups to sync.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync from Cloud'),
        content: Text(
          'This will download ${backups.length} backup(s) from cloud and restore them locally. '
          'Existing items with the same name will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final opNotifier = ref.read(cloudBackupOperationProvider.notifier);
    var restored = 0;
    for (final backup in backups) {
      final ok = await opNotifier.restoreBackup(backup);
      if (ok) restored++;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored $restored/${backups.length} items from cloud.')),
      );
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

    return storageAsync.when(
      data: (bytes) {
        final usedMb = bytes / (1024 * 1024);
        final totalMb = cloudBackupUserQuotaLimit / (1024 * 1024);
        final itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / cloudBackupUserQuotaLimit).clamp(0.0, 1.0);
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
                    'These limits are temporary and will increase in the future.',
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
        'Could not load storage info',
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
