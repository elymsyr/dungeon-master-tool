import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/cloud_backup_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../domain/entities/cloud_backup_meta.dart';
import '../../dialogs/confirm_sign_out_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

class SocialTab extends ConsumerStatefulWidget {
  const SocialTab({super.key});

  @override
  ConsumerState<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends ConsumerState<SocialTab> {
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    if (!SupabaseConfig.isConfigured) {
      return _buildNotConfigured(palette);
    }

    final authState = ref.watch(authProvider);

    return authState != null
        ? _buildProfile(context, ref, palette, authState)
        : _buildNotLoggedIn(context, palette);
  }

  // ── Not configured ──────────────────────────────────────────────

  Widget _buildNotConfigured(DmToolColors palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text(
            'Social',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(fontSize: 14, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Online sessions, player connections,\nand community features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.tabText),
          ),
        ],
      ),
    );
  }

  // ── Not logged in ───────────────────────────────────────────────

  Widget _buildNotLoggedIn(BuildContext context, DmToolColors palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_circle_outlined, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text(
            'Not Signed In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to access social features.',
            style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: Icon(Icons.login, size: 18, color: palette.featureCardAccent),
            label: Text('Sign In', style: TextStyle(color: palette.featureCardAccent)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.featureCardAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Signed-in profile ───────────────────────────────────────────

  Widget _buildProfile(BuildContext context, WidgetRef ref, DmToolColors palette, AuthState authState) {
    final l10n = L10n.of(context)!;
    final initial = authState.email.isNotEmpty ? authState.email[0].toUpperCase() : '?';
    final providerLabel = switch (authState.provider) {
      'google' => 'Google',
      'facebook' => 'Facebook',
      'github' => 'GitHub',
      _ => 'Email',
    };
    final providerIcon = switch (authState.provider) {
      'google' => Icons.g_mobiledata,
      'facebook' => Icons.facebook,
      'github' => Icons.code,
      _ => Icons.email_outlined,
    };
    final joinDate = authState.createdAt != null ? DateFormat.yMMMd().format(authState.createdAt!) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Avatar ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.featureCardAccent,
                      palette.featureCardAccent.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Email ──
              Text(
                authState.email,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: palette.tabActiveText),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(providerIcon, size: 14, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Signed in with $providerLabel',
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Account Info Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.fingerprint, 'User ID', authState.uid, palette, selectable: true),
                    if (joinDate != null) ...[
                      Divider(height: 24, color: palette.featureCardBorder),
                      _infoRow(Icons.calendar_today, 'Joined', joinDate, palette),
                    ],
                    Divider(height: 24, color: palette.featureCardBorder),
                    _infoRow(Icons.verified_user_outlined, 'Status', 'Active', palette,
                        valueColor: palette.successBtnBg),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Cloud Backup ──
              _buildCloudBackupSection(ref, palette),

              const SizedBox(height: 16),

              // ── Coming Soon Features ──
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: palette.featureCardAccent),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: palette.featureCardAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Coming Soon',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _featureItem(Icons.groups, 'Co-op Sessions', 'Invite players to your table', palette),
                              const SizedBox(height: 8),
                              _featureItem(Icons.store, 'Community Market', 'Share and discover .dmt packages', palette),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign Out ──
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => confirmAndSignOut(context, ref),
                  icon: Icon(Icons.logout, size: 18, color: palette.dangerBtnBg),
                  label: Text(l10n.signOut, style: TextStyle(color: palette.dangerBtnBg)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.dangerBtnBg.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cloud Backup Section ─────────────────────────────────────────

  Widget _buildCloudBackupSection(WidgetRef ref, DmToolColors palette) {
    final l10n = L10n.of(context)!;
    final backupsAsync = ref.watch(cloudBackupListProvider);
    final opState = ref.watch(cloudBackupOperationProvider);

    // Show snackbar on operation completion
    ref.listen<CloudBackupOperationState>(cloudBackupOperationProvider, (prev, next) {
      if (prev?.isBusy != true) return;
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloudBackupError(next.errorMessage!))),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      } else if (!next.isBusy && next.result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloudBackupSuccess)),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      } else if (!next.isBusy && prev?.type == CloudBackupOpType.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloudBackupRestoreSuccess)),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      } else if (!next.isBusy && prev?.type == CloudBackupOpType.deleting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloudBackupDeleteSuccess)),
        );
        ref.read(cloudBackupOperationProvider.notifier).reset();
      }
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.featureCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 3, color: palette.featureCardAccent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 16, color: palette.featureCardAccent),
              const SizedBox(width: 8),
              Text(
                l10n.cloudBackupTitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Operation progress
          if (opState.isBusy) ...[
            Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(
                  switch (opState.type) {
                    CloudBackupOpType.uploading => l10n.cloudBackupUploading,
                    CloudBackupOpType.downloading => l10n.cloudBackupDownloading,
                    CloudBackupOpType.deleting => l10n.cloudBackupDeleting,
                    _ => '',
                  },
                  style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Backup list
          backupsAsync.when(
            data: (backups) => backups.isEmpty
                ? Text(l10n.cloudBackupEmpty,
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary))
                : Column(
                    children: backups.map((meta) => _buildBackupCard(ref, meta, palette, l10n, opState.isBusy)).toList(),
                  ),
            loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text(
              l10n.cloudBackupError(e.toString()),
              style: TextStyle(fontSize: 12, color: palette.dangerBtnBg),
            ),
          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard(WidgetRef ref, CloudBackupMeta meta, DmToolColors palette, L10n l10n, bool busy) {
    final date = DateFormat.yMMMd().add_Hm().format(meta.createdAt.toLocal());
    final sizeKb = (meta.sizeBytes / 1024).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.backup, size: 18, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.itemName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.tabActiveText)),
                  const SizedBox(height: 2),
                  Text(
                    '$date  \u2022  ${l10n.cloudBackupEntities(meta.entityCount)}  \u2022  ${l10n.cloudBackupSize(sizeKb)}',
                    style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                  ),
                  if (meta.notes != null && meta.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(meta.notes!, style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: palette.sidebarLabelSecondary)),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.download, size: 16, color: palette.featureCardAccent),
              tooltip: l10n.cloudBackupRestore,
              onPressed: busy ? null : () => _confirmRestore(ref, meta, palette, l10n),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: palette.dangerBtnBg),
              tooltip: l10n.cloudBackupDelete,
              onPressed: busy ? null : () => _confirmDelete(ref, meta, palette, l10n),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRestore(WidgetRef ref, CloudBackupMeta meta, DmToolColors palette, L10n l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudBackupRestoreConfirmTitle(meta.itemName)),
        content: Text(l10n.cloudBackupRestoreConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cloudBackupRestore)),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cloudBackupOperationProvider.notifier).restoreBackup(meta);
    }
  }

  Future<void> _confirmDelete(WidgetRef ref, CloudBackupMeta meta, DmToolColors palette, L10n l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudBackupDeleteConfirmTitle),
        content: Text(l10n.cloudBackupDeleteConfirmBody(meta.itemName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cloudBackupOperationProvider.notifier).deleteBackup(meta.id);
    }
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    DmToolColors palette, {
    bool selectable = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
        ),
        Expanded(
          child: selectable
              ? SelectableText(
                  value,
                  style: TextStyle(fontSize: 12, color: valueColor ?? palette.tabActiveText, fontFamily: 'monospace'),
                )
              : Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor ?? palette.tabActiveText),
                ),
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle, DmToolColors palette) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.tabActiveText)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
