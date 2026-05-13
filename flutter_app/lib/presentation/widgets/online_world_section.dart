import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/providers/world_online_status_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import '../theme/dm_tool_colors.dart';
import 'online_world_widgets.dart';

/// Campaign settings dialog'unda yer alan "Online" bölümü.
///   - Worldu publish/unpublish etmek için toggle (DM).
///   - Aktif invite kodlarını listelemek + yenisini üretmek.
///   - Üyeleri listelemek + kovmak.
///   - Player için: rol göstergesi + "Leave World" butonu.
class OnlineWorldSection extends ConsumerStatefulWidget {
  /// Bu setting dialog'unun açıldığı campaign'in id (UUID).
  final String campaignId;
  /// Campaign display adı.
  final String campaignName;

  const OnlineWorldSection({
    super.key,
    required this.campaignId,
    required this.campaignName,
  });

  @override
  ConsumerState<OnlineWorldSection> createState() =>
      _OnlineWorldSectionState();
}

class _OnlineWorldSectionState extends ConsumerState<OnlineWorldSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final offline = !SupabaseConfig.isConfigured ||
        ref.watch(authProvider) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 16, color: palette.tabActiveText),
            const SizedBox(width: 6),
            Text('Online',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                )),
          ],
        ),
        const SizedBox(height: 8),
        if (offline)
          Text(
            'Sign in and configure Supabase to enable online play.',
            style: TextStyle(
                fontSize: 12, color: palette.sidebarLabelSecondary),
          )
        else
          _onlineBody(palette),
      ],
    );
  }

  Widget _onlineBody(DmToolColors palette) {
    final onlineStatusAsync =
        ref.watch(worldOnlineStatusProvider(widget.campaignId));
    final roleAsync = ref.watch(worldRoleProvider(widget.campaignId));

    return onlineStatusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error: $e',
          style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
      data: (isOnline) {
        final role = roleAsync.valueOrNull ?? WorldRole.none;
        if (!isOnline) return _offlineToggle(palette);
        if (role == WorldRole.dm) return _dmManageOnline(palette);
        if (role == WorldRole.player) return _playerInfo(palette);
        // online ama henüz üyelik bilgisi gelmedi: yumuşak bekleme.
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Resolving membership...',
              style: TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _offlineToggle(DmToolColors palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This world is local-only.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Making it online uploads world data to the cloud and lets you '
            'invite players. You stay the DM.',
            style: TextStyle(
                fontSize: 12, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 16),
            label: const Text('Make Online'),
          ),
        ],
      ),
    );
  }

  Widget _dmManageOnline(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, size: 14, color: palette.successBtnBg),
            const SizedBox(width: 6),
            const Text('World is online',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _unpublish,
              icon: const Icon(Icons.cloud_off, size: 14),
              label: const Text('Make Offline'),
              style: TextButton.styleFrom(
                foregroundColor: palette.dangerBtnBg,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnlineSectionLabel('Invite Code', palette),
        const SizedBox(height: 8),
        InviteCodeRow(palette: palette, worldId: widget.campaignId),
        const SizedBox(height: 16),
        OnlineSectionLabel('Members', palette),
        const SizedBox(height: 8),
        MembersList(
          worldId: widget.campaignId,
          palette: palette,
          onRemoveMember: _busy ? null : _removeMember,
        ),
      ],
    );
  }

  Widget _playerInfo(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 14, color: palette.tabActiveText),
            const SizedBox(width: 6),
            const Text('Joined as Player',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _leave,
              icon: const Icon(Icons.exit_to_app, size: 14),
              label: const Text('Leave World'),
              style: TextButton.styleFrom(
                foregroundColor: palette.dangerBtnBg,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnlineSectionLabel('Members', palette),
        const SizedBox(height: 8),
        MembersList(worldId: widget.campaignId, palette: palette),
      ],
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      final data = await repo.load(widget.campaignName);
      final stateJson = jsonEncode(data);
      final templateId =
          (data['world_schema'] as Map?)?['schemaId'] as String?;
      final templateHash = data['template_hash'] as String?;
      await ref.read(worldMembershipServiceProvider).publishWorld(
            worldId: widget.campaignId,
            worldName: widget.campaignName,
            templateId: templateId,
            templateHash: templateHash,
            stateJson: stateJson,
          );
      ref.read(onlineWorldIdsProvider.notifier).add(widget.campaignId);
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('World is now online')),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpublish() async {
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
          .unpublishWorld(widget.campaignId);
      ref.read(onlineWorldIdsProvider.notifier).remove(widget.campaignId);
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      ref.invalidate(worldMembersProvider(widget.campaignId));
      ref.invalidate(worldInvitesProvider(widget.campaignId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(WorldMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
            'Remove ${m.displayName ?? m.username ?? 'this player'} from the world?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(worldMembershipServiceProvider).removeMember(
            worldId: widget.campaignId,
            userId: m.userId,
          );
      ref.invalidate(worldMembersProvider(widget.campaignId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave world'),
        content: const Text(
            'You will lose access to this world until the DM invites you again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .leaveWorld(widget.campaignId);
      ref.read(onlineWorldIdsProvider.notifier).remove(widget.campaignId);
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$e'),
        backgroundColor: palette.dangerBtnBg,
      ),
    );
  }
}

