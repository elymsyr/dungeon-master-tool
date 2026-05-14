import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/world_membership_provider.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import '../theme/dm_tool_colors.dart';

/// Compact uppercase-style section heading shared by save&sync indicator
/// and the world-settings online panel. Keeps the two surfaces visually
/// in sync.
class OnlineSectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const OnlineSectionLabel(this.text, this.palette, {super.key});

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

/// Aktif tek davet kodunu büyük puntolu gösterir + copy / regenerate.
class InviteCodeRow extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final String worldId;
  const InviteCodeRow({
    super.key,
    required this.palette,
    required this.worldId,
  });

  @override
  ConsumerState<InviteCodeRow> createState() => _InviteCodeRowState();
}

class _InviteCodeRowState extends ConsumerState<InviteCodeRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final codeAsync =
        ref.watch(worldActiveInviteCodeProvider(widget.worldId));
    return codeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        'Could not load invite: $e',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
      data: (code) {
        if (code == null) {
          return Text(
            'No invite available.',
            style:
                TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
          );
        }
        return Row(
          children: [
            Expanded(
              child: SelectableText(
                code,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              },
            ),
            IconButton(
              tooltip: 'Regenerate (invalidates old code)',
              icon: const Icon(Icons.refresh, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _busy ? null : _regenerate,
            ),
          ],
        );
      },
    );
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate invite?'),
        content: const Text(
            'This invalidates the current code. Anyone using the old code '
            'will need the new one to join.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .regenerateInvite(widget.worldId);
      ref.invalidate(worldActiveInviteCodeProvider(widget.worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code regenerated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerate failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Tek üye satırı — avatar + display name + DM/PLAYER badge.
/// [onRemove] non-null ise sağda silme butonu render edilir (DM yetkisi).
class MemberRow extends StatelessWidget {
  final WorldMember member;
  final DmToolColors palette;
  final VoidCallback? onRemove;

  const MemberRow({
    super.key,
    required this.member,
    required this.palette,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : (member.username?.isNotEmpty == true
            ? '@${member.username}'
            : member.userId.substring(0, 8));
    final isDm = member.role == WorldRole.dm;
    return InkWell(
      onTap: () => context.push('/profile/${member.userId}'),
      borderRadius: palette.br,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: palette.featureCardAccent.withValues(alpha: 0.2),
            backgroundImage: (member.avatarUrl?.isNotEmpty == true)
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: (member.avatarUrl?.isEmpty ?? true)
                ? Icon(Icons.person, size: 12, color: palette.tabActiveText)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDm
                  ? palette.featureCardAccent.withValues(alpha: 0.2)
                  : palette.sidebarDivider,
              borderRadius: palette.br,
            ),
            child: Text(
              isDm ? 'DM' : 'PLAYER',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDm ? palette.tabIndicator : palette.tabActiveText,
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove from world',
              icon: Icon(Icons.delete_outline,
                  size: 14, color: palette.dangerBtnBg),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Player hub'ı / party tab için kompakt yatay roster çubuğu. Avatar +
/// initials + DM rozeti. `worldMembersProvider` ile granular reactive —
/// join/leave CDC anında çubuğa yansır.
class MembersStrip extends ConsumerWidget {
  final String worldId;
  final DmToolColors palette;
  const MembersStrip({
    super.key,
    required this.worldId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(worldMembersProvider(worldId));
    return membersAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (_, _) => const SizedBox(height: 36),
      data: (members) {
        if (members.isEmpty) {
          return SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No members yet',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
            ),
          );
        }
        final sorted = [...members]..sort((a, b) {
            if (a.role == WorldRole.dm && b.role != WorldRole.dm) return -1;
            if (a.role != WorldRole.dm && b.role == WorldRole.dm) return 1;
            return a.joinedAt.compareTo(b.joinedAt);
          });
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _MemberChip(member: sorted[i], palette: palette),
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  final WorldMember member;
  final DmToolColors palette;
  const _MemberChip({required this.member, required this.palette});

  String _initials() {
    final src = (member.displayName?.isNotEmpty == true
            ? member.displayName!
            : (member.username?.isNotEmpty == true
                ? member.username!
                : member.userId))
        .trim();
    if (src.isEmpty) return '?';
    final parts = src.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return src.substring(0, src.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDm = member.role == WorldRole.dm;
    final label = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : (member.username?.isNotEmpty == true
            ? '@${member.username}'
            : member.userId.substring(0, 8));
    return Tooltip(
      message: '$label · ${isDm ? 'DM' : 'PLAYER'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDm
              ? palette.featureCardAccent.withValues(alpha: 0.18)
              : palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(
            color: isDm
                ? palette.featureCardAccent.withValues(alpha: 0.6)
                : palette.featureCardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor:
                  palette.featureCardAccent.withValues(alpha: 0.25),
              backgroundImage: (member.avatarUrl?.isNotEmpty == true)
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: (member.avatarUrl?.isEmpty ?? true)
                  ? Text(
                      _initials(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: palette.tabActiveText,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            if (isDm) ...[
              const SizedBox(width: 4),
              Text(
                'DM',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.tabIndicator,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `worldMembersProvider` watch eden hazır liste; loading/error/empty
/// durumlarını save&sync paneliyle aynı şekilde gösterir.
class MembersList extends ConsumerWidget {
  final String worldId;
  final DmToolColors palette;
  final void Function(WorldMember)? onRemoveMember;

  const MembersList({
    super.key,
    required this.worldId,
    required this.palette,
    this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(worldMembersProvider(worldId));
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        'Could not load members: $e',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            'No members yet.',
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
            ),
          );
        }
        return Column(
          children: [
            for (final m in members)
              MemberRow(
                member: m,
                palette: palette,
                onRemove: onRemoveMember == null || m.role == WorldRole.dm
                    ? null
                    : () => onRemoveMember!(m),
              ),
          ],
        );
      },
    );
  }
}
