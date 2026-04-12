import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/cloud_backup_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/cloud_backup_remote_ds.dart';
import '../../domain/entities/cloud_backup_meta.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Reusable section showing local save timestamp, cloud backup timestamp,
/// and a download-from-cloud button.
///
/// Used inside item settings dialogs (world/template/package) and inside
/// the SaveSyncIndicator full-mode dialog.
///
/// Caller provides [localUpdatedAt] (already resolved — file mtime, DB
/// column, or in-memory value). The cloud meta is fetched lazily via
/// [cloudBackupRepositoryProvider] using ([itemId], [type]).
///
/// When [onDownloaded] is provided it is called after a successful restore
/// so the caller can refresh its lists / reload the item.
class SaveInfoSection extends ConsumerStatefulWidget {
  final String itemName;
  final String itemId;
  final String type;
  final DateTime? localUpdatedAt;
  final Future<void> Function()? onDownloaded;

  const SaveInfoSection({
    super.key,
    required this.itemName,
    required this.itemId,
    required this.type,
    required this.localUpdatedAt,
    this.onDownloaded,
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
    _cloudFuture =
        CloudBackupRemoteDataSource().fetchByItem(widget.itemId, widget.type);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final hasCloud = SupabaseConfig.isConfigured;
    final isAuthed = ref.watch(authProvider) != null;

    return FutureBuilder<CloudBackupMeta?>(
      future: _cloudFuture,
      builder: (context, snapshot) {
        final loading = hasCloud &&
            isAuthed &&
            snapshot.connectionState != ConnectionState.done;
        final cloudMeta = snapshot.data;

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
            if (hasCloud && isAuthed) ...[
              const SizedBox(height: 6),
              _row(
                icon: Icons.cloud_outlined,
                label: l10n.saveInfoCloudLabel,
                value: loading
                    ? l10n.saveInfoLoadingCloud
                    : cloudMeta == null
                        ? l10n.saveInfoNoCloud
                        : _formatDate(cloudMeta.createdAt, l10n),
                palette: palette,
              ),
              if (!loading && cloudMeta != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download_outlined, size: 16),
                    label: Text(l10n.saveInfoDownload),
                    onPressed: () => _downloadFromCloud(cloudMeta),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      side: BorderSide(color: palette.featureCardBorder),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
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

  String _formatDate(DateTime? dt, L10n l10n) {
    if (dt == null) return l10n.saveInfoNever;
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

  Future<void> _downloadFromCloud(CloudBackupMeta meta) async {
    final l10n = L10n.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveInfoDownloadConfirmTitle),
        content: Text(l10n.saveInfoDownloadConfirmBody(widget.itemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveInfoDownload),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final opNotifier = ref.read(cloudBackupOperationProvider.notifier);
    final ok = await opNotifier.restoreBackup(meta, restoreName: widget.itemName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.saveInfoDownloadSuccess
              : l10n.saveInfoDownloadError('restore failed'),
        ),
      ),
    );

    if (ok && widget.onDownloaded != null) {
      await widget.onDownloaded!();
    }
  }
}
