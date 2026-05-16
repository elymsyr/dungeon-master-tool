import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/beta_provider.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/connectivity_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/outbox_status_provider.dart';
import '../../application/providers/package_provider.dart' show activePackageProvider;
import '../../application/providers/personal_sync_provider.dart';
import '../../application/providers/save_state_provider.dart';
import '../../application/providers/sync_engine_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_mirror_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/providers/world_online_status_provider.dart';
import '../../domain/entities/online/world_role.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/database_provider.dart';
import '../../data/network/network_providers.dart';
import '../../data/repositories/cloud_backup_repository_impl.dart';
import '../../application/services/cloud_catchup_service.dart';
import '../../application/services/media_bundler.dart';
import '../../application/services/world_reconciler.dart';
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

    // Full (inside item) mode: reflects the active item's save + outbox.
    final saveStatus = ref.watch(saveStateProvider);
    // Active-item cloud eligibility: world only counts when "Made Online",
    // package always counts (packages cloud-back automatically). When no
    // item active → fall back to global hasCloud.
    final activeCampaign = ref.watch(activeCampaignProvider);
    final activePackage = ref.watch(activePackageProvider);
    bool itemOnCloud;
    if (activeCampaign != null) {
      final data = ref.read(activeCampaignProvider.notifier).data;
      final worldId = (data?['world_id'] as String?) ?? activeCampaign;
      itemOnCloud =
          hasCloud && ref.watch(onlineWorldIdsProvider).contains(worldId);
    } else if (activePackage != null) {
      itemOnCloud = hasCloud;
    } else {
      itemOnCloud = hasCloud;
    }
    final outbox = itemOnCloud
        ? (ref.watch(outboxStatusProvider).valueOrNull ?? OutboxStatus.empty)
        : null;
    final localSaving = saveStatus == SaveStatus.saving;
    final cloudSyncing = outbox != null && outbox.isSyncing;

    final (IconData icon, Color color) = _resolveIcon(
      saveStatus, outbox, palette, itemOnCloud,
      localSaving: localSaving, cloudSyncing: cloudSyncing,
      context: context,
    );

    return Stack(
      children: [
        IconButton(
          icon: (localSaving || cloudSyncing)
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 20, color: color),
          tooltip: _tooltip(saveStatus, outbox),
          onPressed: () => _showSaveSyncDialog(context, ref, compact: false),
        ),
        if (outbox != null && outbox.hasIssue)
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
              child: const Icon(
                Icons.priority_high,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  (IconData, Color) _resolveIcon(
    SaveStatus save,
    OutboxStatus? sync,
    DmToolColors palette,
    bool hasCloud, {
    required bool localSaving,
    required bool cloudSyncing,
    required BuildContext context,
  }) {
    // Color rules (single indicator):
    //   - Cloud sync in progress (with or without local) → success/green.
    //   - Local-only save in progress → theme primary.
    //   - Idle: cloud-status driven (synced / dirty / queue) or local-only
    //     dirty/save icon when there's no cloud.
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (cloudSyncing) {
      return (Icons.cloud_sync, palette.successBtnBg);
    }
    if (localSaving) {
      return (Icons.save, themePrimary);
    }
    if (!hasCloud) {
      return switch (save) {
        SaveStatus.saving => (Icons.save, themePrimary),
        SaveStatus.dirty => (Icons.save_outlined, themePrimary),
        SaveStatus.saved => (Icons.save, palette.sidebarLabelSecondary),
      };
    }
    if (sync == null) {
      return (Icons.cloud_queue, palette.sidebarLabelSecondary);
    }
    if (sync.hasIssue) return (Icons.cloud_off, palette.dangerBtnBg);
    return save == SaveStatus.dirty
        ? (Icons.cloud_upload_outlined, palette.featureCardAccent)
        : (Icons.cloud_done, palette.successBtnBg);
  }

  String _tooltip(SaveStatus save, OutboxStatus? sync) {
    if (sync != null) {
      if (sync.hasIssue) {
        return 'Sync stuck (${sync.maxAttempts} attempts)';
      }
      if (sync.pending > 0) {
        return 'Syncing ${sync.pending} item${sync.pending == 1 ? '' : 's'}...';
      }
      return save == SaveStatus.dirty ? 'Unsaved changes' : 'Cloud synced';
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
    final saveStatus = ref.watch(saveStateProvider);
    final hasCloud = SupabaseConfig.isConfigured;
    final outbox = hasCloud
        ? (ref.watch(outboxStatusProvider).valueOrNull ?? OutboxStatus.empty)
        : null;

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

                // ── Actions (full mode only) ──
                if (!compact) ...[
                  _SectionLabel('Actions', palette),
                  const SizedBox(height: 8),
                  _ActionsRow(
                    palette: palette,
                    saveStatus: saveStatus,
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

                // ── Outbox status (full mode only) ──
                if (!compact && outbox != null && outbox.pending > 0) ...[
                  const SizedBox(height: 16),
                  _SectionLabel('Sync Queue', palette),
                  const SizedBox(height: 8),
                  _OutboxStatusRow(outbox: outbox, palette: palette),
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

/// Actions panel — active world/package için manuel Save (disk) + Sync
/// (push + pull) + Make Online toggle (sadece world). Auto-save tamamen
/// kaldırıldı; bu butonlar tek tetik noktası.
class _ActionsRow extends ConsumerWidget {
  final DmToolColors palette;
  final SaveStatus saveStatus;
  final bool hasCloud;

  const _ActionsRow({
    required this.palette,
    required this.saveStatus,
    required this.hasCloud,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignName = ref.watch(activeCampaignProvider);
    final packageName = ref.watch(activePackageProvider);
    final hasActive = campaignName != null || packageName != null;
    if (!hasActive) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SaveButton(palette: palette, saveStatus: saveStatus),
        if (hasCloud) _SyncButton(palette: palette),
        if (campaignName != null && hasCloud)
          _MakeOnlineButton(palette: palette),
      ],
    );
  }
}

class _SaveButton extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final SaveStatus saveStatus;
  const _SaveButton({required this.palette, required this.saveStatus});

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton> {
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(saveStateProvider.notifier).saveNow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = _busy || widget.saveStatus == SaveStatus.saving;
    return _ActionButton(
      icon: Icons.save,
      label: saving ? 'Saving...' : 'Save',
      onPressed: saving ? null : _save,
      palette: widget.palette,
    );
  }
}

class _SyncButton extends ConsumerStatefulWidget {
  final DmToolColors palette;
  const _SyncButton({required this.palette});

  @override
  ConsumerState<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<_SyncButton> {
  bool _busy = false;

  Future<void> _sync() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Manuel sync: realtime subscribe + bidirectional world reconcile +
      // outbox drain + character/package catchup. Tek tetik noktası.
      await runManualPersonalSync(ref);
      await runManualWorldSync(ref);
      await ref.read(worldReconcilerProvider).reconcile();
      await ref.read(syncEngineProvider).forceTick();
      await ref.read(cloudCatchupServiceProvider).runAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignName = ref.watch(activeCampaignProvider);
    final packageName = ref.watch(activePackageProvider);
    bool online = false;
    if (campaignName != null) {
      final data = ref.read(activeCampaignProvider.notifier).data;
      final worldId = (data?['world_id'] as String?) ?? campaignName;
      online = ref.watch(onlineWorldIdsProvider).contains(worldId);
    } else if (packageName != null) {
      final signedIn = ref.watch(authProvider) != null;
      final betaActive = ref.watch(betaProvider).isActive;
      online = signedIn && betaActive;
    }
    final tooltip = online
        ? 'Sync now (push + pull)'
        : campaignName != null
            ? 'Make this world online first'
            : 'Sign in + join beta to sync';
    return Tooltip(
      message: tooltip,
      child: _ActionButton(
        icon: Icons.cloud_sync,
        label: _busy ? 'Syncing...' : 'Sync',
        onPressed: (online && !_busy) ? _sync : null,
        palette: widget.palette,
      ),
    );
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
      final label = isDm ? 'Online · DM' : 'Online · Player';
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
    // Make Online publishWorld cloud yazımı yapar — internet zorunlu.
    final online = ref.read(connectivityStreamProvider).valueOrNull ?? true;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İnternet bağlantısı gerekli. Çevrimiçi olunca tekrar deneyin.'),
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
    // Make Offline cloud'dan dünyayı siler — internet zorunlu. Aksi halde
    // unpublishWorld başarısız olur, lokal "online" bayrağı düşer ama cloud
    // hâlâ açık kalır (state divergence). Bunu önle.
    final online = ref.read(connectivityStreamProvider).valueOrNull ?? true;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İnternet bağlantısı gerekli — offline yapmak için önce bağlanın.',
          ),
        ),
      );
      return;
    }
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

/// PR-SYNC-6: dialog row showing the persistent outbox depth. When rows are
/// stuck (>3 attempts) we surface the most-recent error and a "Retry now"
/// button that calls `SyncEngine.forceTick()`.
class _OutboxStatusRow extends ConsumerWidget {
  final OutboxStatus outbox;
  final DmToolColors palette;
  const _OutboxStatusRow({required this.outbox, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stuck = outbox.hasIssue;
    final color = stuck ? palette.dangerBtnBg : palette.featureCardAccent;
    final icon = stuck ? Icons.cloud_off : Icons.cloud_sync;
    final label = stuck
        ? 'Stuck (${outbox.maxAttempts} attempts)'
        : '${outbox.pending} pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: color)),
                if (stuck && outbox.lastError != null)
                  Text(
                    outbox.lastError!,
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref.read(syncEngineProvider).forceTick(),
            child: const Text('Retry now', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

