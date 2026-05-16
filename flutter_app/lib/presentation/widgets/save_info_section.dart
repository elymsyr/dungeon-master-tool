import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../domain/entities/cloud_backup_meta.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Reusable section showing local save timestamp and cloud backup
/// timestamp. Read-only — no download/restore action. Restoration is
/// offered globally via the "Sync from Cloud" action in the
/// SaveSyncIndicator dialog.
class SaveInfoSection extends ConsumerStatefulWidget {
  final String itemName;
  final String itemId;
  final String type;
  final DateTime? localUpdatedAt;

  const SaveInfoSection({
    super.key,
    required this.itemName,
    required this.itemId,
    required this.type,
    required this.localUpdatedAt,
  });

  @override
  ConsumerState<SaveInfoSection> createState() => _SaveInfoSectionState();
}

class _SaveInfoSectionState extends ConsumerState<SaveInfoSection> {
  Future<CloudBackupMeta?>? _cloudFuture;

  @override
  void initState() {
    super.initState();
    _refreshCloud();
  }

  void _refreshCloud() {
    if (!SupabaseConfig.isConfigured || ref.read(authProvider) == null) {
      _cloudFuture = Future.value(null);
      return;
    }
    // Use the raw remote DS for a direct query by itemId+type.
    setState(() {
      _cloudFuture = CloudBackupRemoteDataSource()
          .fetchByItem(widget.itemId, widget.type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final hasCloud = SupabaseConfig.isConfigured;
    final isAuthed = ref.watch(authProvider) != null;

    // Re-fetch whenever cloud backup list is invalidated (e.g. after a
    // successful syncNow). Without this, the section is stuck on the
    // snapshot from first open and keeps saying "No cloud backup yet"
    // even after the user just pushed a backup.
    ref.listen<AsyncValue<List<CloudBackupMeta>>>(
      cloudBackupListProvider,
      (_, _) => _refreshCloud(),
    );

    final mirrorRow = _characterMirrorRow(palette, l10n);

    return FutureBuilder<CloudBackupMeta?>(
      future: _cloudFuture,
      builder: (context, snapshot) {
        final loading = hasCloud &&
            isAuthed &&
            snapshot.connectionState != ConnectionState.done;
        final cloudMeta = snapshot.data;
        final hasError = snapshot.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(
              icon: Icons.save_outlined,
              label: l10n.saveInfoLocalLabel,
              value: _formatDate(widget.localUpdatedAt, l10n),
              palette: palette,
            ),
            if (mirrorRow != null) ...[
              const SizedBox(height: 6),
              mirrorRow,
            ] else if (hasCloud && isAuthed && _itemOnCloud()) ...[
              const SizedBox(height: 6),
              _row(
                icon: Icons.cloud_outlined,
                label: l10n.saveInfoCloudLabel,
                value: loading
                    ? l10n.saveInfoLoadingCloud
                    : hasError
                        ? 'Error: ${snapshot.error}'
                        : cloudMeta == null
                            ? l10n.saveInfoNoCloud
                            : _formatDate(cloudMeta.createdAt, l10n),
                palette: palette,
              ),
            ],
          ],
        );
      },
    );
  }

  /// World-bound characters sync via the `world_characters` mirror, not
  /// `cloud_backups`. Surface that path explicitly so the cloud row stops
  /// claiming "No cloud backup yet" for chars that are actually syncing
  /// live through the world.
  Widget? _characterMirrorRow(DmToolColors palette, L10n l10n) {
    if (widget.type != 'character') return null;
    final list = ref.watch(characterListProvider).valueOrNull;
    if (list == null) return null;
    final c = list.where((x) => x.id == widget.itemId).firstOrNull;
    if (c == null) return null;
    final wid = c.worldId;
    if (wid == null) return null;
    final online = ref.watch(onlineWorldIdsProvider).contains(wid);
    final value = online
        ? 'Synced live via world'
        : 'World offline — local only';
    return _row(
      icon: online ? Icons.cloud_done : Icons.cloud_off,
      label: 'Online',
      value: value,
      palette: palette,
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    required DmToolColors palette,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: palette.sidebarLabelSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// World items only "on cloud" once Made Online; packages always are.
  bool _itemOnCloud() {
    if (widget.type == 'world') {
      return ref.watch(onlineWorldIdsProvider).contains(widget.itemId);
    }
    return true;
  }

  String _formatDate(DateTime? dt, L10n l10n) {
    if (dt == null) return l10n.saveInfoNever;
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

}
