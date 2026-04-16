import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'new_chat_picker_screen.dart';
import 'social_shell.dart';

const double _kListMaxWidth = 640;

// ── Shared conversation context menu ─────────────────────────────────

/// Shows the conversation context menu.
/// For groups: members, add/kick, rename, leave, delete.
/// For DMs: delete only.
/// Used from both [_ConvTile] (messages list) and [ChatScreen] title.
void _showConversationContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  required String? myUserId,
  required Offset globalPosition,
  /// Called after a destructive action (leave/delete) so the caller can pop.
  VoidCallback? onLeft,
}) {
  if (!conversation.isGroup) {
    _showDmContextMenu(
      context: context,
      ref: ref,
      conversation: conversation,
      globalPosition: globalPosition,
      onLeft: onLeft,
    );
    return;
  }

  final palette = Theme.of(context).extension<DmToolColors>()!;
  final l10n = L10n.of(context)!;
  final isAdmin = conversation.createdBy == myUserId;
  final errorColor = Theme.of(context).colorScheme.error;

  final items = <PopupMenuEntry<String>>[];

  // Members header
  items.add(PopupMenuItem(
    enabled: false,
    height: 32,
    child: Text(
      l10n.chatMenuMembers,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: palette.sidebarLabelSecondary,
      ),
    ),
  ));

  for (var i = 0; i < conversation.memberIds.length; i++) {
    final memberId = conversation.memberIds[i];
    final username = i < conversation.memberUsernames.length
        ? conversation.memberUsernames[i]
        : memberId;
    final isMemberAdmin = memberId == conversation.createdBy;
    final canKick = isAdmin && !isMemberAdmin && memberId != myUserId;

    items.add(PopupMenuItem(
      enabled: canKick,
      value: 'kick:$memberId',
      child: Row(
        children: [
          ProfileAvatar(fallbackText: username, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '@$username',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMemberAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: palette.featureCardAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: palette.featureCardAccent,
                ),
              ),
            ),
          if (canKick)
            Icon(Icons.person_remove_outlined, size: 16, color: errorColor),
        ],
      ),
    ));
  }

  items.add(const PopupMenuDivider());

  // Add member (admin only)
  if (isAdmin) {
    items.add(PopupMenuItem(
      value: 'add_member',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined, size: 18, color: palette.featureCardAccent),
          const SizedBox(width: 8),
          Text(l10n.chatMenuAddMember, style: TextStyle(color: palette.featureCardAccent)),
        ],
      ),
    ));
  }

  // Rename (admin only)
  if (isAdmin) {
    items.add(PopupMenuItem(
      value: 'rename',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 18, color: palette.tabText),
          const SizedBox(width: 8),
          Text(l10n.chatMenuRenameGroup),
        ],
      ),
    ));
  }

  // Leave
  items.add(PopupMenuItem(
    value: 'leave',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.exit_to_app, size: 18, color: errorColor),
        const SizedBox(width: 8),
        Text(l10n.chatMenuLeaveGroup, style: TextStyle(color: errorColor)),
      ],
    ),
  ));

  // Delete group (admin only)
  if (isAdmin) {
    items.add(PopupMenuItem(
      value: 'delete_group',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_forever, size: 18, color: errorColor),
          const SizedBox(width: 8),
          Text(l10n.chatMenuDeleteGroup, style: TextStyle(color: errorColor)),
        ],
      ),
    ));
  }

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    ),
    items: items,
  ).then((value) {
    if (value == null) return;
    if (value == 'add_member') _addMemberFlow(context: context, ref: ref, conversation: conversation);
    if (value == 'rename') _renameGroupFlow(context: context, ref: ref, conversation: conversation);
    if (value == 'leave') _leaveGroupFlow(context: context, ref: ref, conversation: conversation, myUserId: myUserId, onLeft: onLeft);
    if (value == 'delete_group') _deleteGroupFlow(context: context, ref: ref, conversation: conversation, onLeft: onLeft);
    if (value.startsWith('kick:')) _kickMemberFlow(context: context, ref: ref, conversation: conversation, targetUserId: value.substring(5));
  });
}

/// Context menu for non-group (DM) conversations — delete only.
void _showDmContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  required Offset globalPosition,
  VoidCallback? onLeft,
}) {
  final l10n = L10n.of(context)!;
  final errorColor = Theme.of(context).colorScheme.error;

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    ),
    items: [
      PopupMenuItem(
        value: 'delete_dm',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 18, color: errorColor),
            const SizedBox(width: 8),
            Text(l10n.dmDeleteChat, style: TextStyle(color: errorColor)),
          ],
        ),
      ),
    ],
  ).then((value) {
    if (value == 'delete_dm') {
      _deleteDmFlow(
        context: context,
        ref: ref,
        conversation: conversation,
        onLeft: onLeft,
      );
    }
  });
}

Future<void> _deleteDmFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  VoidCallback? onLeft,
}) async {
  final l10n = L10n.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.dmDeleteTitle),
      content: Text(l10n.dmDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.dmDeleteConfirm, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(messagesRemoteDsProvider).deleteConversation(conversation.id);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    onLeft?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}

Future<void> _addMemberFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
}) async {
  final l10n = L10n.of(context)!;
  final uid = ref.read(authProvider)?.uid;
  if (uid == null) return;

  final existingIds = conversation.memberIds.toSet();
  final following = await ref.read(followingProvider(uid).future);
  final followers = await ref.read(followersProvider(uid).future);
  final seen = <String>{};
  final candidates = <UserProfile>[];
  for (final p in [...following, ...followers]) {
    if (!existingIds.contains(p.userId) && seen.add(p.userId)) {
      candidates.add(p);
    }
  }

  if (!context.mounted) return;

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.discoverEmptyState)),
    );
    return;
  }

  final picked = await showDialog<UserProfile>(
    context: context,
    builder: (ctx) => _SearchableUserPickerDialog(
      title: l10n.chatAddMemberTitle,
      candidates: candidates,
    ),
  );

  if (picked == null || !context.mounted) return;

  try {
    await ref.read(messagesRemoteDsProvider).addMember(conversation.id, picked.userId);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatMemberAdded)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}

Future<void> _renameGroupFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
}) async {
  final l10n = L10n.of(context)!;
  final ctrl = TextEditingController(text: conversation.title ?? '');
  final newTitle = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.chatRenameTitle),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          hintText: l10n.chatRenameHint,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
  ctrl.dispose();
  if (newTitle == null || newTitle.isEmpty || newTitle == conversation.title) return;
  try {
    await ref.read(messagesRemoteDsProvider).renameConversation(conversation.id, newTitle);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}

Future<void> _leaveGroupFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  required String? myUserId,
  VoidCallback? onLeft,
}) async {
  final l10n = L10n.of(context)!;
  final isAdmin = conversation.createdBy == myUserId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.groupSettingsLeaveTitle),
      content: Text(isAdmin ? l10n.groupSettingsLeaveBodyAdmin : l10n.groupSettingsLeaveBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.groupSettingsLeave, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(messagesRemoteDsProvider).leaveConversation(conversation.id);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    onLeft?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}

Future<void> _deleteGroupFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  VoidCallback? onLeft,
}) async {
  final l10n = L10n.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.groupSettingsDeleteTitle),
      content: Text(l10n.groupSettingsDeleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.groupSettingsDelete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(messagesRemoteDsProvider).deleteConversation(conversation.id);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    onLeft?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}

Future<void> _kickMemberFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Conversation conversation,
  required String targetUserId,
}) async {
  final l10n = L10n.of(context)!;
  try {
    await ref.read(messagesRemoteDsProvider).kickMember(conversation.id, targetUserId);
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatMemberKicked)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }
}
const double _kChatMaxWidth = 760;

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 45) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat.MMMd().format(dt.toLocal());
}

String _dateSeparatorLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(date.year, date.month, date.day);
  final diff = today.difference(msgDate).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.EEEE().format(date);
  return DateFormat.yMMMd().format(date);
}

/// For a DM conversation, returns the other person's username (excluding [myId]).
String _dmOtherName(Conversation conv, String? myId) {
  final idx = conv.memberIds.indexOf(myId ?? '');
  if (idx >= 0 && idx < conv.memberUsernames.length) {
    // Remove current user, return the other
    final others = <String>[];
    for (var i = 0; i < conv.memberUsernames.length; i++) {
      if (i != idx) others.add(conv.memberUsernames[i]);
    }
    if (others.isNotEmpty) return others.join(', ');
  }
  return conv.memberUsernames.join(', ');
}

bool _isDifferentDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year != lb.year || la.month != lb.month || la.day != lb.day;
}

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  void _openCompose(BuildContext context, Offset fabPosition) {
    final l10n = L10n.of(context)!;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        fabPosition.dx - 180,
        fabPosition.dy - 100,
        fabPosition.dx,
        fabPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'direct',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 10),
              Text(l10n.messagesComposeNewDirect),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'group',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_outlined, size: 18),
              const SizedBox(width: 10),
              Text(l10n.messagesComposeNewGroup),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewChatPickerScreen(
            mode: value == 'direct' ? NewChatMode.direct : NewChatMode.group,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(conversationListRealtimeProvider);

    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final convsAsync = ref.watch(myConversationsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            invalidateCache('conversations');
            ref.invalidate(myConversationsProvider);
          },
          child: convsAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(formatError(e))),
            data: (convs) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kListMaxWidth),
                child: convs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SocialEmptyState(
                            icon: Icons.forum_outlined,
                            title: l10n.messagesEmptyTitle,
                            subtitle: l10n.messagesEmptySubtitle,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                        itemCount: convs.length,
                        itemBuilder: (_, i) => _ConvTile(conversation: convs[i]),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Builder(
            builder: (fabCtx) => FloatingActionButton(
              tooltip: l10n.messagesComposeTooltip,
              backgroundColor: palette.featureCardAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                final box = fabCtx.findRenderObject() as RenderBox;
                final pos = box.localToGlobal(Offset.zero);
                _openCompose(context, pos);
              },
              child: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable in-app dialog with search for picking a user from a list.
class _SearchableUserPickerDialog extends StatefulWidget {
  final String title;
  final List<UserProfile> candidates;
  const _SearchableUserPickerDialog({required this.title, required this.candidates});

  @override
  State<_SearchableUserPickerDialog> createState() => _SearchableUserPickerDialogState();
}

class _SearchableUserPickerDialogState extends State<_SearchableUserPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<UserProfile> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.candidates;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.candidates;
      } else {
        _filtered = widget.candidates
            .where((p) =>
                p.username.toLowerCase().contains(q) ||
                (p.displayName?.toLowerCase().contains(q) ?? false))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return Dialog(
      backgroundColor: palette.canvasBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.discoverSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: palette.featureCardBg,
                  border: OutlineInputBorder(
                    borderRadius: palette.br,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.discoverEmptySearch,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.sidebarLabelSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          dense: true,
                          leading: ProfileAvatar(
                            avatarUrl: p.avatarUrl,
                            fallbackText: p.username,
                            size: 32,
                          ),
                          title: Text(
                            p.displayName ?? p.username,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '@${p.username}',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ConvTile extends ConsumerWidget {
  final Conversation conversation;
  const _ConvTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final auth = ref.read(authProvider);
    final myId = auth?.uid;

    final title = conversation.isGroup
        ? (conversation.title ?? 'Group')
        : _dmOtherName(conversation, myId);
    final displayTitle = title.isEmpty ? '(empty)' : title;
    final fallback = title.isEmpty ? '?' : title;
    final preview = conversation.lastMessageBody ?? l10n.messagesNoMessagesYet;
    final previewIsPlaceholder = conversation.lastMessageBody == null;
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onLongPressStart: (details) => _showConversationContextMenu(
            context: context, ref: ref,
            conversation: conversation,
            myUserId: myId,
            globalPosition: details.globalPosition,
          ),
      onSecondaryTapDown: (details) => _showConversationContextMenu(
            context: context, ref: ref,
            conversation: conversation,
            myUserId: myId,
            globalPosition: details.globalPosition,
          ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: palette.cbr,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(conversation: conversation, myUserId: myId),
            ),
          ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(fallbackText: fallback, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: palette.tabActiveText,
                            ),
                          ),
                        ),
                        if (conversation.lastMessageAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(conversation.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread ? palette.featureCardAccent : palette.sidebarLabelSecondary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasUnread ? palette.tabActiveText : palette.sidebarLabelSecondary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              fontStyle: previewIsPlaceholder
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.featureCardAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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

class ChatScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final String? myUserId;
  const ChatScreen({super.key, required this.conversation, required this.myUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    // Mark conversation as read on open.
    _markRead();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(messagesRemoteDsProvider).markRead(widget.conversation.id);
      invalidateCache('totalUnread');
      invalidateCache('conversations');
      ref.invalidate(totalUnreadCountProvider);
      ref.invalidate(myConversationsProvider);
    } catch (_) {
      // Non-critical — don't block chat.
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesRemoteDsProvider).send(widget.conversation.id, text);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversation.id));
    final title = widget.conversation.isGroup
        ? (widget.conversation.title ?? 'Group')
        : _dmOtherName(widget.conversation, widget.myUserId);
    final fallback = title.isEmpty ? '?' : title;

    return Scaffold(
      backgroundColor: palette.canvasBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: (widget.conversation.isGroup)
              ? () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box?.localToGlobal(Offset(box.size.width / 2, box.size.height)) ?? Offset.zero;
                  _showConversationContextMenu(
                    context: context, ref: ref,
                    conversation: widget.conversation,
                    myUserId: widget.myUserId,
                    globalPosition: pos,
                    onLeft: () { if (mounted) Navigator.of(context).pop(); },
                  );
                }
              : null,
          onSecondaryTapDown: (widget.conversation.isGroup)
              ? (details) => _showConversationContextMenu(
                    context: context, ref: ref,
                    conversation: widget.conversation,
                    myUserId: widget.myUserId,
                    globalPosition: details.globalPosition,
                    onLeft: () { if (mounted) Navigator.of(context).pop(); },
                  )
              : null,
          child: Row(
            children: [
              ProfileAvatar(fallbackText: fallback, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '(empty)' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (widget.conversation.isGroup &&
                        widget.conversation.memberUsernames.isNotEmpty)
                      Text(
                        widget.conversation.memberUsernames.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.sidebarLabelSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: const [],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(formatError(e))),
                  data: (msgs) {
                    if (msgs.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.messagesNoMessagesYet,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: palette.sidebarLabelSecondary,
                          ),
                        ),
                      );
                    }
                    // Reverse for bottom-anchored display
                    final reversed = msgs.reversed.toList();
                    return ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: reversed.length,
                      itemBuilder: (ctx, i) {
                        final m = reversed[i];
                        final mine = m.authorId == widget.myUserId;
                        // In reversed list: visually above = i+1, below = i-1
                        final above =
                            i < reversed.length - 1 ? reversed[i + 1] : null;
                        final below = i > 0 ? reversed[i - 1] : null;
                        final sameAbove = above != null &&
                            above.authorId == m.authorId &&
                            m.createdAt
                                    .difference(above.createdAt)
                                    .inMinutes <
                                3;
                        final sameBelow = below != null &&
                            below.authorId == m.authorId &&
                            below.createdAt
                                    .difference(m.createdAt)
                                    .inMinutes <
                                3;

                        // Date separator: show below this message if it's a
                        // different day than the message visually above it
                        final showDateSeparator = above == null ||
                            _isDifferentDay(m.createdAt, above.createdAt);

                        return Column(
                          children: [
                            if (showDateSeparator)
                              _DateSeparator(
                                label: _dateSeparatorLabel(
                                    m.createdAt.toLocal()),
                                palette: palette,
                              ),
                            _MessageBubble(
                              message: m,
                              mine: mine,
                              showAuthor: !mine &&
                                  widget.conversation.isGroup &&
                                  !sameAbove,
                              topTight: sameAbove,
                              bottomTight: sameBelow,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _ctrl,
                sending: _sending,
                hasText: _hasText,
                onSend: _send,
                hint: l10n.messagesInputHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  const _DateSeparator({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.cbr,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: palette.sidebarLabelSecondary,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showAuthor;
  final bool topTight;
  final bool bottomTight;
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
    required this.topTight,
    required this.bottomTight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final bubbleRadius = palette.cbr;

    final bubbleColor =
        mine ? palette.featureCardAccent : palette.featureCardBg;
    final timeStr = DateFormat.Hm().format(message.createdAt.toLocal());

    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: bubbleRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  color: mine ? Colors.white : palette.tabActiveText,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.7)
                      : palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: topTight ? 1 : 6,
        bottom: bottomTight ? 1 : 6,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showAuthor && message.authorUsername != null)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 3),
                child: Text(
                  '@${message.authorUsername}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
            bubble,
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool hasText;
  final VoidCallback onSend;
  final String hint;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.hasText,
    required this.onSend,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final canSend = hasText && !sending;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 140),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: palette.cbr,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedScale(
              scale: canSend ? 1.0 : 0.86,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: canSend ? 1.0 : 0.55,
                duration: const Duration(milliseconds: 140),
                child: Material(
                  color: palette.featureCardAccent,
                  borderRadius: palette.cbr,
                  child: InkWell(
                    borderRadius: palette.cbr,
                    onTap: canSend ? onSend : null,
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
