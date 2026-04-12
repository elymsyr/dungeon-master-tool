import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/conversation.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(myConversationsProvider);
    final hPad = isPhone(context) ? 12.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myConversationsProvider),
      child: convsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (convs) => convs.isEmpty
            ? ListView(
                children: const [
                  SocialEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations yet',
                    subtitle: 'Open a player profile and tap Message to start chatting.',
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                children: [
                  SocialCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < convs.length; i++) ...[
                          _ConvTile(conversation: convs[i]),
                          if (i < convs.length - 1)
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .extension<DmToolColors>()!
                                  .featureCardBorder,
                            ),
                        ],
                      ],
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
    final auth = ref.read(authProvider);
    final myId = auth?.uid;

    final title = conversation.isGroup
        ? (conversation.title ?? 'Group')
        : conversation.memberUsernames.join(', ');
    final fallback = title.isEmpty ? '?' : title;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ProfileAvatar(fallbackText: fallback, size: 42),
      title: Text(
        title.isEmpty ? '(empty)' : title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText),
      ),
      subtitle: conversation.lastMessageBody != null
          ? Text(
              conversation.lastMessageBody!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
            )
          : Text('No messages yet',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: palette.sidebarLabelSecondary)),
      trailing: conversation.lastMessageAt != null
          ? Text(
              DateFormat.Hm().format(conversation.lastMessageAt!.toLocal()),
              style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conversation, myUserId: myId),
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
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
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
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversation.id));
    final title = widget.conversation.isGroup
        ? (widget.conversation.title ?? 'Group')
        : widget.conversation.memberUsernames.join(', ');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (msgs) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final m = msgs[i];
                  final mine = m.authorId == widget.myUserId;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: mine ? palette.featureCardAccent : palette.featureCardBg,
                        border: Border.all(
                          color: mine ? palette.featureCardAccent : palette.featureCardBorder,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(mine ? 14 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!mine && m.authorUsername != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '@${m.authorUsername}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: palette.sidebarLabelSecondary,
                                ),
                              ),
                            ),
                          Text(
                            m.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: mine ? Colors.white : palette.tabActiveText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.Hm().format(m.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 9,
                              color: mine
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : palette.sidebarLabelSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.featureCardBg,
                        borderRadius: palette.cbr,
                        border: Border.all(color: palette.featureCardBorder),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: palette.featureCardAccent,
                    borderRadius: palette.cbr,
                    child: InkWell(
                      borderRadius: palette.cbr,
                      onTap: _sending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
