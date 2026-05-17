import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/beta_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/outbox_status_provider.dart';
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
  // Unified across types: surface only the "last cloud touch" timestamp.
  //  - world  → `worlds.updated_at`
  //  - other  → `cloud_backups.created_at` via fetchByItem
  Future<DateTime?>? _cloudFuture;

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
    setState(() {
      _cloudFuture = _fetchCloudTimestamp();
    });
  }

  Future<DateTime?> _fetchCloudTimestamp() async {
    if (widget.type == 'world') {
      try {
        final row = await Supabase.instance.client
            .from('worlds')
            .select('updated_at')
            .eq('id', widget.itemId)
            .maybeSingle();
        final raw = row?['updated_at'];
        if (raw is String) return DateTime.tryParse(raw);
        return null;
      } catch (_) {
        return null;
      }
    }
    final meta = await CloudBackupRemoteDataSource()
        .fetchByItem(widget.itemId, widget.type);
    return meta?.createdAt;
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
    // F6 follow-up: row-level cloud pushes (world_entities, world_settings,
    // world_map_data) drain via outbox. After drain → `worlds.updated_at`
    // ticked → re-fetch so the cloud timestamp shows the fresh value.
    ref.listen<AsyncValue<OutboxStatus>>(outboxStatusProvider, (prev, next) {
      final prevPending = prev?.valueOrNull?.pending ?? 0;
      final nextPending = next.valueOrNull?.pending ?? 0;
      if (prevPending > 0 && nextPending == 0) {
        _refreshCloud();
      }
    });

    final mirrorRow = _offlineMirrorRow(palette, l10n);

    return FutureBuilder<DateTime?>(
      future: _cloudFuture,
      builder: (context, snapshot) {
        final loading = hasCloud &&
            isAuthed &&
            snapshot.connectionState != ConnectionState.done;
        final cloudAt = snapshot.data;
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
                        : cloudAt == null
                            ? l10n.saveInfoNoCloud
                            : _formatDate(cloudAt, l10n),
                palette: palette,
              ),
            ],
          ],
        );
      },
    );
  }

  /// Replaces the cloud timestamp row only for the offline branches where the
  /// item isn't actually syncing. Online worlds + chars in online worlds fall
  /// through to the timestamp row so the user sees the last cloud touch.
  Widget? _offlineMirrorRow(DmToolColors palette, L10n l10n) {
    if (widget.type == 'world') {
      final online = ref.watch(onlineWorldIdsProvider).contains(widget.itemId);
      if (online) return null;
      return _row(
        icon: Icons.cloud_off,
        label: 'Online',
        value: 'World offline — local only',
        palette: palette,
      );
    }
    if (widget.type != 'character') return null;
    final list = ref.watch(characterListProvider).valueOrNull;
    if (list == null) return null;
    final c = list.where((x) => x.id == widget.itemId).firstOrNull;
    if (c == null) return null;
    final wid = c.worldId;
    if (wid == null) return null;
    final online = ref.watch(onlineWorldIdsProvider).contains(wid);
    if (!online) return null;
    // World-bound + online world: char rides the world_characters mirror.
    return _row(
      icon: Icons.cloud_done,
      label: 'Online',
      value: 'Synced live via world',
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

  /// Items that may carry a cloud timestamp row.
  ///   - World: only when published (`worlds` row exists, i.e. online).
  ///   - Character: signed-in + beta covers either world-mirror or
  ///     `cloud_backups` snapshot, so always reachable.
  ///   - Package: always.
  bool _itemOnCloud() {
    if (widget.type == 'world') {
      return ref.watch(onlineWorldIdsProvider).contains(widget.itemId);
    }
    if (widget.type == 'character') {
      return ref.watch(isBetaActiveProvider);
    }
    return true;
  }

  String _formatDate(DateTime? dt, L10n l10n) {
    if (dt == null) return l10n.saveInfoNever;
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

}
