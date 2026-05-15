import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/beta_provider.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/cloud_sync_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/providers/world_online_status_provider.dart';
import '../../domain/entities/online/world_role.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/database_provider.dart';
import '../../data/network/network_providers.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../../application/services/media_bundler.dart';
import '../theme/dm_tool_colors.dart';
import 'online_world_widgets.dart';
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
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
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
                  const SizedBox(height: 16),

                  // ── Actions (full mode only) ──
                  _SectionLabel('Actions', palette),
                  const SizedBox(height: 8),
                  _ActionsRow(
                    palette: palette,
                    saveStatus: saveStatus,
                    syncState: syncState,
                    hasCloud: hasCloud,
                  ),

                  // ── Online world panel: invite code + members ──
                  _OnlineWorldPanel(palette: palette),
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
      borderRadius: palette.br,
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

/// Online world panel — invite code (copy + regenerate) ve member listesini
/// gösterir. World offline iken hiçbir şey render etmez.
class _OnlineWorldPanel extends ConsumerWidget {
  final DmToolColors palette;
  const _OnlineWorldPanel({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignName = ref.watch(activeCampaignProvider);
    if (campaignName == null) return const SizedBox.shrink();
    final data = ref.read(activeCampaignProvider.notifier).data;
    final worldId = (data?['world_id'] as String?) ?? campaignName;
    final onlineIds = ref.watch(onlineWorldIdsProvider);
    if (!onlineIds.contains(worldId)) return const SizedBox.shrink();
    final role =
        ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role == WorldRole.dm) ...[
            OnlineSectionLabel('Invite Code', palette),
            const SizedBox(height: 8),
            InviteCodeRow(palette: palette, worldId: worldId),
            const SizedBox(height: 16),
          ],
          OnlineSectionLabel('Members', palette),
          const SizedBox(height: 8),
          MembersList(worldId: worldId, palette: palette),
        ],
      ),
    );
  }
}

// _InviteCodeRow / _MemberRow extracted to online_world_widgets.dart so the
// world-settings online panel can render the same shape.

/// Actions panel — world açıkken "Save Locally" + "Make Online" (toggle);
/// World açıkken sadece "Make Online" toggle. Package açıkken eylem yok —
/// local + cloud kayıt auto-sync ile.
class _ActionsRow extends ConsumerWidget {
  final DmToolColors palette;
  final SaveStatus saveStatus;
  final CloudSyncState? syncState;
  final bool hasCloud;

  const _ActionsRow({
    required this.palette,
    required this.saveStatus,
    required this.syncState,
    required this.hasCloud,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignName = ref.watch(activeCampaignProvider);
    final isWorld = campaignName != null;
    if (!isWorld || !hasCloud) return const SizedBox.shrink();
    return _MakeOnlineButton(palette: palette);
  }
}

/// Active world için online toggle. Online ise yeşil "Online · Auto-sync"
/// pill + sağında "Make Offline" küçük ikon. Offline ise "Make Online" CTA.
class _MakeOnlineButton extends ConsumerStatefulWidget {
  final DmToolColors palette;
  const _MakeOnlineButton({required this.palette});

  @override
  ConsumerState<_MakeOnlineButton> createState() => _MakeOnlineButtonState();
}

class _MakeOnlineButtonState extends ConsumerState<_MakeOnlineButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final campaignName = ref.watch(activeCampaignProvider);
    if (campaignName == null) return const SizedBox.shrink();
    final data = ref.read(activeCampaignProvider.notifier).data;
    final worldId = (data?['world_id'] as String?) ?? campaignName;
    final onlineIds = ref.watch(onlineWorldIdsProvider);
    final isOnline = onlineIds.contains(worldId);
    final role =
        ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
    final isDm = role == WorldRole.dm;

    if (isOnline) {
      final label = isDm ? 'Online · Auto-sync' : 'Online · Player';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.successBtnBg.withValues(alpha: 0.15),
              borderRadius: palette.br,
              border: Border.all(color: palette.successBtnBg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done,
                    size: 14, color: palette.successBtnBg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.successBtnBg,
                  ),
                ),
              ],
            ),
          ),
          // Make Offline yalnızca DM'e açık — player unpublishing yapamaz
          // (RLS reddediyor). Buton player'a görünmüyor.
          if (isDm) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Make Offline',
              icon: const Icon(Icons.cloud_off, size: 16),
              onPressed: _busy ? null : () => _confirmOffline(worldId),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ],
      );
    }

    // Offline world → sadece DM "Make Online" yapabilir. Player rolündeki
    // user offline world görmemeli (joined world her zaman online'dır),
    // ama defansif olarak: sadece DM/none için butonu render et.
    if (role == WorldRole.player) return const SizedBox.shrink();

    return _ActionButton(
      icon: Icons.cloud_upload,
      label: _busy ? 'Publishing...' : 'Make Online',
      onPressed: _busy ? null : () => _makeOnline(campaignName, worldId),
      palette: palette,
    );
  }

  Future<void> _makeOnline(String campaignName, String worldId) async {
    // Beta-only: online multiplayer only for beta members.
    if (!ref.read(betaProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Online worlds are beta-only. Open Settings → Subscriptions to join the free beta.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      final data = await repo.load(campaignName);
      // Bundle media → R2 upload + rewrite local paths to `dmt-asset://` so
      // players (and re-opens on other devices) can fetch images.
      Map<String, dynamic> bundled = data;
      final assetSvc = ref.read(assetServiceProvider);
      if (assetSvc != null) {
        try {
          final res = await MediaBundler(assetSvc).bundleWorldMedia(
            worldName: campaignName,
            worldId: worldId,
            data: data,
          );
          bundled = res.data;
        } catch (e) {
          debugPrint('makeOnline media bundle error: $e');
        }
      }
      final stateJson = jsonEncode(bundled);
      final templateId =
          (bundled['world_schema'] as Map?)?['schemaId'] as String?;
      final templateHash = bundled['template_hash'] as String?;
      await ref.read(worldMembershipServiceProvider).publishWorld(
            worldId: worldId,
            worldName: campaignName,
            templateId: templateId,
            templateHash: templateHash,
            stateJson: stateJson,
          );
      ref.read(onlineWorldIdsProvider.notifier).add(worldId);
      ref.invalidate(worldOnlineStatusProvider(worldId));
      // First-publish path: the invite-code FutureProvider had already
      // resolved to null while the world was offline (NoOp branch /
      // ensureInvite RPC errored against the not-yet-created row). The
      // Riverpod cache held that null indefinitely so the panel showed
      // "members but no code" after the world flipped online. Force a
      // fresh ensure_world_invite RPC + invalidate so the panel surfaces
      // the code on the same screen tick the publish succeeds.
      try {
        await ref
            .read(worldMembershipServiceProvider)
            .ensureInvite(worldId);
      } catch (e) {
        debugPrint('makeOnline ensureInvite error: $e');
      }
      ref.invalidate(worldActiveInviteCodeProvider(worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('World is now online')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmOffline(String worldId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make Offline'),
        content: const Text(
            'This removes the world and all member data from the cloud. '
            'Local data is preserved. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Make Offline')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .unpublishWorld(worldId);
      ref.read(onlineWorldIdsProvider.notifier).remove(worldId);
      ref.invalidate(worldOnlineStatusProvider(worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('World is now offline')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unpublish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        const itemLimitMb = cloudBackupItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / quotaBytes).clamp(0.0, 1.0);
        final remainingMb = totalMb - usedMb;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: palette.br,
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
          borderRadius: palette.cbr,
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

