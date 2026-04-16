import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/error_format.dart';
import '../../../domain/entities/conversation.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'group_settings_screen.dart';
import 'new_chat_picker_screen.dart';
import 'social_shell.dart';

const double _kListMaxWidth = 640;
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

bool _isDifferentDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year != lb.year || la.month != lb.month || la.day != lb.day;
}

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  void _openCompose(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.featureCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: palette.featureCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _ComposeAction(
                icon: Icons.person_outline,
                label: l10n.messagesComposeNewDirect,
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const NewChatPickerScreen(mode: NewChatMode.direct),
                    ),
                  );
                },
              ),
              _ComposeAction(
                icon: Icons.group_outlined,
                label: l10n.messagesComposeNewGroup,
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const NewChatPickerScreen(mode: NewChatMode.group),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          onRefresh: () async => ref.invalidate(myConversationsProvider),
          child: convsAsync.when(
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                        itemCount: convs.length,
                        separatorBuilder: (_, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 66),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: palette.featureCardBorder.withValues(alpha: 0.5),
                          ),
                        ),
                        itemBuilder: (_, i) => _ConvTile(conversation: convs[i]),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            tooltip: l10n.messagesComposeTooltip,
            backgroundColor: palette.featureCardAccent,
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: () => _openCompose(context),
            child: const Icon(Icons.edit_outlined),
          ),
        ),
      ],
    );
  }
}

class _ComposeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ComposeAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.featureCardAccent),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
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
        : conversation.memberUsernames.join(', ');
    final displayTitle = title.isEmpty ? '(empty)' : title;
    final fallback = title.isEmpty ? '?' : title;
    final preview = conversation.lastMessageBody ?? l10n.messagesNoMessagesYet;
    final previewIsPlaceholder = conversation.lastMessageBody == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                              fontWeight: FontWeight.w600,
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
                              color: palette.sidebarLabelSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.sidebarLabelSecondary,
                        fontStyle: previewIsPlaceholder
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(messagesRemoteDsProvider).deleteMessage(messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(formatError(e))));
      }
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
        : widget.conversation.memberUsernames.join(', ');
    final fallback = title.isEmpty ? '?' : title;

    return Scaffold(
      backgroundColor: palette.canvasBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
        actions: [
          if (widget.conversation.isGroup)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Group settings',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(
                      conversation: widget.conversation,
                      myUserId: widget.myUserId,
                    ),
                  ),
                );
              },
            ),
        ],
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
                              onDelete:
                                  mine ? () => _deleteMessage(m.id) : null,
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.featureCardBorder),
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
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
    required this.topTight,
    required this.bottomTight,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    const bigR = Radius.circular(16);
    const smallR = Radius.circular(4);
    const tailR = Radius.zero;

    // WhatsApp-style border radius:
    // First in group (!topTight) gets tail → tail-side top corner is zero
    // Middle messages get small radius on the author's side
    // Last in group (!bottomTight) gets big radius everywhere except author's side top
    final BorderRadius borderRadius;
    if (mine) {
      borderRadius = BorderRadius.only(
        topLeft: bigR,
        topRight: !topTight ? tailR : smallR,
        bottomLeft: bigR,
        bottomRight: !bottomTight ? bigR : smallR,
      );
    } else {
      borderRadius = BorderRadius.only(
        topLeft: !topTight ? tailR : smallR,
        topRight: bigR,
        bottomLeft: !bottomTight ? bigR : smallR,
        bottomRight: bigR,
      );
    }

    final bubbleColor =
        mine ? palette.featureCardAccent : palette.featureCardBg;
    final timeStr = DateFormat.Hm().format(message.createdAt.toLocal());

    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: mine
              ? null
              : Border.all(color: palette.featureCardBorder),
          borderRadius: borderRadius,
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

    // Bubble with optional tail
    final bool showTail = !topTight;
    final Widget bubbleRow;
    if (showTail) {
      if (mine) {
        bubbleRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bubble,
            _BubbleTail(color: bubbleColor, mine: true),
          ],
        );
      } else {
        bubbleRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BubbleTail(color: bubbleColor, mine: false),
            bubble,
          ],
        );
      }
    } else {
      // Indent to align with tailed messages
      bubbleRow = Padding(
        padding: EdgeInsets.only(
          left: mine ? 0 : 8,
          right: mine ? 8 : 0,
        ),
        child: bubble,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: topTight ? 1 : 6,
        bottom: bottomTight ? 1 : 6,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPressStart: onDelete != null
              ? (details) {
                  showMenu<String>(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx + 1,
                      details.globalPosition.dy + 1,
                    ),
                    items: [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade300),
                            const SizedBox(width: 8),
                            Text('Delete',
                                style:
                                    TextStyle(color: Colors.red.shade300)),
                          ],
                        ),
                      ),
                    ],
                  ).then((value) {
                    if (value == 'delete') onDelete!();
                  });
                }
              : null,
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
              bubbleRow,
            ],
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style bubble tail triangle
class _BubbleTail extends StatelessWidget {
  final Color color;
  final bool mine;
  const _BubbleTail({required this.color, required this.mine});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(8, 12),
      painter: _TailPainter(color: color, mine: mine),
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final bool mine;
  _TailPainter({required this.color, required this.mine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (mine) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) =>
      color != old.color || mine != old.mine;
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
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.featureCardBorder),
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
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
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
