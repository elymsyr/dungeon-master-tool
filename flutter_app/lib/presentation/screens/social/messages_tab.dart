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
  int _lastMessageCount = 0;

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

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesRemoteDsProvider).send(widget.conversation.id, text);
      _ctrl.clear();
      _scrollToBottomSoon();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversation.id));
    final title = widget.conversation.isGroup
        ? (widget.conversation.title ?? 'Group')
        : widget.conversation.memberUsernames.join(', ');
    final fallback = title.isEmpty ? '?' : title;

    return Scaffold(
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(formatError(e))),
                  data: (msgs) {
                    if (msgs.length != _lastMessageCount) {
                      _lastMessageCount = msgs.length;
                      _scrollToBottomSoon();
                    }
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
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length,
                      itemBuilder: (ctx, i) {
                        final m = msgs[i];
                        final mine = m.authorId == widget.myUserId;
                        final prev = i > 0 ? msgs[i - 1] : null;
                        final next = i < msgs.length - 1 ? msgs[i + 1] : null;
                        final samePrev = prev != null &&
                            prev.authorId == m.authorId &&
                            m.createdAt.difference(prev.createdAt).inMinutes < 3;
                        final sameNext = next != null &&
                            next.authorId == m.authorId &&
                            next.createdAt.difference(m.createdAt).inMinutes < 3;
                        return _MessageBubble(
                          message: m,
                          mine: mine,
                          showAuthor: !mine &&
                              widget.conversation.isGroup &&
                              !samePrev,
                          showTimestamp: !sameNext,
                          topTight: samePrev,
                          bottomTight: sameNext,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showAuthor;
  final bool showTimestamp;
  final bool topTight;
  final bool bottomTight;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
    required this.showTimestamp,
    required this.topTight,
    required this.bottomTight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    const bigRadius = Radius.circular(16);
    const smallRadius = Radius.circular(4);
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: mine ? palette.featureCardAccent : palette.featureCardBg,
                  border: Border.all(
                    color:
                        mine ? palette.featureCardAccent : palette.featureCardBorder,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: (mine || !topTight) ? bigRadius : smallRadius,
                    topRight: (!mine || !topTight) ? bigRadius : smallRadius,
                    bottomLeft: mine
                        ? bigRadius
                        : (bottomTight ? smallRadius : smallRadius),
                    bottomRight: mine
                        ? (bottomTight ? smallRadius : smallRadius)
                        : bigRadius,
                  ),
                ),
                child: Text(
                  message.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: mine ? Colors.white : palette.tabActiveText,
                  ),
                ),
              ),
            ),
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 3),
                child: Text(
                  DateFormat.Hm().format(message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
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
