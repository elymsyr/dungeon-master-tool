import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../domain/entities/conversation.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../../l10n/app_localizations.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final String? myUserId;

  const GroupSettingsScreen({
    super.key,
    required this.conversation,
    required this.myUserId,
  });

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late final TextEditingController _titleCtrl;
  bool _saving = false;
  bool _leaving = false;
  bool _deleting = false;

  bool get _isAdmin => widget.conversation.createdBy == widget.myUserId;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.conversation.title ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty || newTitle == widget.conversation.title) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(messagesRemoteDsProvider)
          .renameConversation(widget.conversation.id, newTitle);
      invalidateCache('conversations');
      ref.invalidate(myConversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.groupNameUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(formatError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.groupSettingsLeaveTitle),
        content: Text(
          _isAdmin
              ? L10n.of(context)!.groupLeaveAdminBody
              : L10n.of(context)!.groupLeaveBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.of(context)!.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.worldsBtnLeave,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _leaving = true);
    try {
      await ref
          .read(messagesRemoteDsProvider)
          .leaveConversation(widget.conversation.id);
      invalidateCache('conversations');
      ref.invalidate(myConversationsProvider);
      if (mounted) {
        // Pop back to conversation list
        Navigator.of(context)
          ..pop() // settings screen
          ..pop(); // chat screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(formatError(e))));
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.groupSettingsDeleteTitle),
        content: Text(
          L10n.of(context)!.groupSettingsDeleteBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.of(context)!.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.btnDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(messagesRemoteDsProvider)
          .deleteConversation(widget.conversation.id);
      invalidateCache('conversations');
      ref.invalidate(myConversationsProvider);
      if (mounted) {
        Navigator.of(context)
          ..pop() // settings screen
          ..pop(); // chat screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(formatError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final conv = widget.conversation;
    final adminId = conv.createdBy;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context)!.groupSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Group name ──
          Text(
            L10n.of(context)!.groupSettingsName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  enabled: _isAdmin && !_saving,
                  maxLength: 100,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    counterText: '',
                    hintText: L10n.of(context)!.chatRenameHint,
                    suffixIcon: !_isAdmin
                        ? const Icon(Icons.lock_outline, size: 18)
                        : null,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _saveTitle,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(L10n.of(context)!.btnSave),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // ── Members ──
          Text(
            L10n.of(context)!.groupSettingsMembers(conv.memberUsernames.length),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(conv.memberIds.length, (i) {
            final memberId = conv.memberIds[i];
            final username = i < conv.memberUsernames.length
                ? conv.memberUsernames[i]
                : memberId;
            final isMemberAdmin = memberId == adminId;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: ProfileAvatar(fallbackText: username, size: 36),
              title: Text(
                username,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.tabActiveText,
                ),
              ),
              trailing: isMemberAdmin
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: palette.featureCardAccent
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        L10n.of(context)!.groupSettingsAdmin,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: palette.featureCardAccent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  : null,
            );
          }),

          const SizedBox(height: 32),

          // ── Leave group ──
          OutlinedButton.icon(
            onPressed: _leaving ? null : _leaveGroup,
            icon: _leaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.exit_to_app,
                    color: Theme.of(context).colorScheme.error),
            label: Text(
              L10n.of(context)!.groupSettingsLeave,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
            ),
          ),

          // ── Delete group (admin only) ──
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _deleting ? null : _deleteGroup,
              icon: _deleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(L10n.of(context)!.groupSettingsDelete),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
