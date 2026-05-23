import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_beta_requests_provider.dart';
import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_beta_requests_remote_ds.dart';
import '../../dialogs/admin_compose_dm_dialog.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin beta yönetim sekmesi: üstte bekleyen istekler (approve/reject/message),
/// altta aktif beta üyeleri (storage/last-active/device/version + revoke).
class BetaRequestsTab extends ConsumerWidget {
  const BetaRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final requestsAsync = ref.watch(adminBetaRequestsProvider);
    final participantsAsync = ref.watch(adminBetaParticipantsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminBetaRequestsProvider);
        ref.invalidate(adminBetaParticipantsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Pending requests',
            count: requestsAsync.maybeWhen(
              data: (r) => r.length,
              orElse: () => null,
            ),
            palette: palette,
          ),
          const SizedBox(height: 8),
          requestsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: palette.dangerBtnBg)),
            data: (entries) => entries.isEmpty
                ? _EmptyBox(
                    palette: palette,
                    icon: Icons.inbox_outlined,
                    label: 'No pending beta requests.',
                  )
                : Column(
                    children: [
                      for (final e in entries) ...[
                        _RequestRow(entry: e),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Active beta members',
            count: participantsAsync.maybeWhen(
              data: (p) => p.length,
              orElse: () => null,
            ),
            palette: palette,
          ),
          const SizedBox(height: 8),
          participantsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: palette.dangerBtnBg)),
            data: (entries) => entries.isEmpty
                ? _EmptyBox(
                    palette: palette,
                    icon: Icons.people_outline,
                    label: 'No active beta members.',
                  )
                : Column(
                    children: [
                      for (final p in entries) ...[
                        _ParticipantRow(entry: p),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final DmToolColors palette;
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.tabActiveText)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette.featureCardAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.featureCardAccent)),
          ),
        ],
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final DmToolColors palette;
  final IconData icon;
  final String label;
  const _EmptyBox({
    required this.palette,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: palette.sidebarLabelSecondary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends ConsumerWidget {
  final BetaRequestEntry entry;
  const _RequestRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final title = entry.username ?? entry.email ?? entry.userId;
    final subtitleParts = <String>[
      if (entry.username != null && entry.email != null) entry.email!,
      formatRelative(entry.requestedAt),
    ];
    final subtitle = subtitleParts.join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    palette.featureCardAccent.withValues(alpha: 0.15),
                child: Icon(Icons.science_outlined,
                    color: palette.featureCardAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                tooltip: 'Message',
                onPressed: () => AdminComposeDmDialog.show(
                  context,
                  targetUserId: entry.userId,
                  targetName: entry.username ?? entry.email ?? 'user',
                ),
              ),
            ],
          ),
          if (entry.message != null && entry.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.featureCardBorder.withValues(alpha: 0.25),
                borderRadius: palette.br,
              ),
              child: Text(
                entry.message!,
                style: TextStyle(
                    fontSize: 12,
                    color: palette.tabActiveText,
                    height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: palette.dangerBtnBg),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                onPressed: () => _reject(context, ref),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                onPressed: () => _approve(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ds = ref.read(adminBetaRequestsDataSourceProvider);
    try {
      final res = await ds.approve(entry.userId);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      switch (res.status) {
        case BetaApproveStatus.granted:
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Approved — slot #${res.assignedSlot ?? "?"} (${res.slotsRemaining} remaining)'),
          ));
        case BetaApproveStatus.already:
          messenger.showSnackBar(
            const SnackBar(content: Text('User is already in the beta.')),
          );
        case BetaApproveStatus.full:
          messenger.showSnackBar(
            const SnackBar(
                content: Text(
                    'No slots available — wait for an existing user to leave or be swept.')),
          );
        case BetaApproveStatus.notPending:
          messenger.showSnackBar(
            const SnackBar(content: Text('Request no longer pending.')),
          );
        case BetaApproveStatus.invalidUser:
        case BetaApproveStatus.error:
          messenger.showSnackBar(
            const SnackBar(content: Text('Approval failed.')),
          );
      }
      ref.invalidate(adminBetaRequestsProvider);
      ref.invalidate(adminBetaParticipantsProvider);
      ref.invalidate(adminUserStatsProvider);
      ref.invalidate(adminUserListProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Approve failed: $e')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${entry.username ?? entry.email ?? "user"}?'),
        content: const Text(
            'Request will be removed. The user can submit a new request later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final ds = ref.read(adminBetaRequestsDataSourceProvider);
    try {
      await ds.reject(entry.userId);
      ref.invalidate(adminBetaRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reject failed: $e')));
    }
  }
}

class _ParticipantRow extends ConsumerWidget {
  final BetaParticipantEntry entry;
  const _ParticipantRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final title = entry.username ?? entry.email ?? entry.userId;
    final subtitle = [
      if (entry.slotNumber != null) '#${entry.slotNumber}',
      if (entry.username != null && entry.email != null) entry.email!,
    ].join(' · ');
    final lastSeen = entry.profileLastActiveAt ?? entry.lastActiveAt;
    final usageRatio = entry.quotaBytes <= 0
        ? 0.0
        : (entry.usedBytes / entry.quotaBytes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    palette.featureCardAccent.withValues(alpha: 0.15),
                child: Icon(Icons.verified_user_outlined,
                    color: palette.featureCardAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                tooltip: 'Message',
                onPressed: () => AdminComposeDmDialog.show(
                  context,
                  targetUserId: entry.userId,
                  targetName: entry.username ?? entry.email ?? 'user',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatBytes(entry.usedBytes)} / ${formatBytes(entry.quotaBytes)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: usageRatio,
                        minHeight: 5,
                        backgroundColor:
                            palette.featureCardBorder.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation(
                            usageRatio > 0.9
                                ? palette.dangerBtnBg
                                : palette.featureCardAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                  palette: palette,
                  icon: Icons.login,
                  label: 'Joined ${formatRelative(entry.joinedAt)}'),
              _MetaChip(
                  palette: palette,
                  icon: Icons.access_time,
                  label: 'Active ${formatRelative(lastSeen)}'),
              if (entry.appVersion != null && entry.appVersion!.isNotEmpty)
                _MetaChip(
                    palette: palette,
                    icon: Icons.tag,
                    label: 'v${entry.appVersion}'),
              if (entry.platform != null && entry.platform!.isNotEmpty)
                _MetaChip(
                    palette: palette,
                    icon: _platformIcon(entry.platform!),
                    label: entry.platform!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style:
                    TextButton.styleFrom(foregroundColor: palette.dangerBtnBg),
                icon: const Icon(Icons.no_accounts_outlined, size: 16),
                label: const Text('Revoke'),
                onPressed: () => _revoke(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String p) {
    final s = p.toLowerCase();
    if (s.contains('android')) return Icons.android;
    if (s.contains('ios')) return Icons.phone_iphone;
    if (s.contains('mac')) return Icons.laptop_mac;
    if (s.contains('win')) return Icons.laptop_windows;
    if (s.contains('linux')) return Icons.laptop;
    if (s.contains('web')) return Icons.public;
    return Icons.devices_other;
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke beta from ${entry.username ?? entry.email ?? "user"}?'),
        content: const Text(
            'This permanently deletes all online content owned by the user — '
            'worlds, personal packages, marketplace listings, cloud backups '
            'and uploaded media. Local data on the user\'s device is not '
            'affected. Action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final ds = ref.read(adminBetaRequestsDataSourceProvider);
    try {
      final ok = await ds.revoke(entry.userId);
      ref.invalidate(adminBetaParticipantsProvider);
      ref.invalidate(adminUserStatsProvider);
      ref.invalidate(adminUserListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Beta revoked.' : 'User was not in beta.'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Revoke failed: $e')));
    }
  }
}

class _MetaChip extends StatelessWidget {
  final DmToolColors palette;
  final IconData icon;
  final String label;
  const _MetaChip({
    required this.palette,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.featureCardBorder.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: palette.sidebarLabelSecondary)),
        ],
      ),
    );
  }
}
