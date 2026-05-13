import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_share_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../domain/entities/online/entity_share.dart';
import '../../domain/entities/online/world_role.dart';
import '../theme/dm_tool_colors.dart';

/// DM'in entity'i hangi oyuncularla paylaştığını yönetmesini sağlar.
/// "Share with all" tek seçenek; her üye için ayrı toggle.
class ShareEntityDialog extends ConsumerStatefulWidget {
  final String entityId;
  final String entityName;
  final String worldId;

  const ShareEntityDialog({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.worldId,
  });

  static Future<void> show(
    BuildContext context, {
    required String entityId,
    required String entityName,
    required String worldId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShareEntityDialog(
        entityId: entityId,
        entityName: entityName,
        worldId: worldId,
      ),
    );
  }

  @override
  ConsumerState<ShareEntityDialog> createState() => _ShareEntityDialogState();
}

class _ShareEntityDialogState extends ConsumerState<ShareEntityDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final membersAsync =
        ref.watch(worldMembersProvider(widget.worldId));
    final sharesAsync =
        ref.watch(worldEntitySharesProvider(widget.worldId));

    return AlertDialog(
      title: Text('Share "${widget.entityName}"'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sharesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e',
                  style: TextStyle(color: palette.dangerBtnBg)),
              data: (allShares) {
                final shares = allShares
                    .where((s) => s.entityId == widget.entityId)
                    .toList();
                final worldWide =
                    shares.any((s) => s.isWorldWide);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: const Text('Share with all players'),
                      subtitle: Text(
                        'Every member sees this entity.',
                        style: TextStyle(
                            fontSize: 12,
                            color: palette.sidebarLabelSecondary),
                      ),
                      value: worldWide,
                      onChanged: _busy
                          ? null
                          : (v) => _toggleWorldWide(v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text('Individual players',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.tabActiveText)),
                    ),
                    membersAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => Text('Error: $e',
                          style: TextStyle(color: palette.dangerBtnBg)),
                      data: (members) {
                        final players = members
                            .where((m) => m.role == WorldRole.player)
                            .toList();
                        if (players.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('No players have joined yet.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: palette.sidebarLabelSecondary)),
                          );
                        }
                        return Column(
                          children: players.map((m) {
                            final shared = shares.any(
                                (s) => s.sharedWith == m.userId);
                            return CheckboxListTile(
                              title: Text(m.displayName ??
                                  m.username ??
                                  m.userId.substring(0, 8)),
                              value: shared || worldWide,
                              onChanged: (_busy || worldWide)
                                  ? null
                                  : (v) =>
                                      _toggleUser(m.userId, v ?? false),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _toggleWorldWide(bool on) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(entityShareServiceProvider);
      if (svc == null) return;
      if (on) {
        await svc.shareWithAll(
            entityId: widget.entityId, worldId: widget.worldId);
      } else {
        await svc.unshareAll(
            entityId: widget.entityId, worldId: widget.worldId);
      }
      ref.invalidate(worldEntitySharesProvider(widget.worldId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleUser(String userId, bool on) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(entityShareServiceProvider);
      if (svc == null) return;
      if (on) {
        await svc.shareWithUser(
          entityId: widget.entityId,
          worldId: widget.worldId,
          userId: userId,
        );
      } else {
        await svc.unshareUser(
          entityId: widget.entityId,
          worldId: widget.worldId,
          userId: userId,
        );
      }
      ref.invalidate(worldEntitySharesProvider(widget.worldId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

/// Convenience: aktif world id + entity id ile dialog'u açar.
class ShareEntityHelpers {
  static EntityShare? findShareForUser(
    List<EntityShare> shares,
    String entityId,
    String userId,
  ) {
    for (final s in shares) {
      if (s.entityId == entityId &&
          (s.sharedWith == userId || s.sharedWith == null)) {
        return s;
      }
    }
    return null;
  }
}
