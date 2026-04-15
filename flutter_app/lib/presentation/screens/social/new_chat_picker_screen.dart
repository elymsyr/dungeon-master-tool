import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/error_format.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'messages_tab.dart';
import 'social_shell.dart';

enum NewChatMode { direct, group }

class NewChatPickerScreen extends ConsumerStatefulWidget {
  final NewChatMode mode;
  const NewChatPickerScreen({super.key, required this.mode});

  @override
  ConsumerState<NewChatPickerScreen> createState() => _NewChatPickerScreenState();
}

class _NewChatPickerScreenState extends ConsumerState<NewChatPickerScreen> {
  final _titleCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _isGroup => widget.mode == NewChatMode.group;

  bool get _canSubmit {
    if (_submitting) return false;
    if (_selectedIds.isEmpty) return false;
    if (_isGroup && _titleCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = L10n.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final myId = ref.read(authProvider)?.uid;

    setState(() => _submitting = true);
    try {
      final ds = ref.read(messagesRemoteDsProvider);
      Conversation conv;
      if (_isGroup) {
        conv = await ds.createGroup(
          title: _titleCtrl.text.trim(),
          memberIds: _selectedIds.toList(),
        );
      } else {
        conv = await ds.openDirect(_selectedIds.first);
      }
      ref.invalidate(myConversationsProvider);
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUserId: myId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.newChatPickerError(formatError(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final auth = ref.watch(authProvider);
    final uid = auth?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isGroup ? l10n.newChatPickerTitleGroup : l10n.newChatPickerTitleDirect),
        ),
        body: const SizedBox.shrink(),
      );
    }

    final followingAsync = ref.watch(followingProvider(uid));
    final followersAsync = ref.watch(followersProvider(uid));

    final merged = _mergePeople(
      followingAsync.asData?.value ?? const [],
      followersAsync.asData?.value ?? const [],
      excludeUid: uid,
    );
    final isLoading = followingAsync.isLoading || followersAsync.isLoading;
    final error = followingAsync.asError ?? followersAsync.asError;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isGroup ? l10n.newChatPickerTitleGroup : l10n.newChatPickerTitleDirect),
      ),
      body: Column(
        children: [
          if (_isGroup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _titleCtrl,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.newChatPickerGroupTitleLabel,
                  hintText: l10n.newChatPickerGroupTitleHint,
                  filled: true,
                  fillColor: palette.featureCardBg,
                  border: OutlineInputBorder(
                    borderRadius: palette.br,
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: palette.br,
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (isLoading && merged.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return Center(child: Text(formatError(error.error)));
                }
                if (merged.isEmpty) {
                  return ListView(
                    children: [
                      SocialEmptyState(
                        icon: Icons.people_outline,
                        title: l10n.newChatPickerEmpty,
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: merged.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: palette.featureCardBorder,
                  ),
                  itemBuilder: (_, i) {
                    final p = merged[i];
                    final selected = _selectedIds.contains(p.userId);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: ProfileAvatar(
                        avatarUrl: p.avatarUrl,
                        fallbackText: p.username,
                        size: 40,
                      ),
                      title: Text(
                        '@${p.username}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                      ),
                      subtitle: p.displayName != null && p.displayName!.isNotEmpty
                          ? Text(
                              p.displayName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.sidebarLabelSecondary,
                              ),
                            )
                          : null,
                      trailing: _isGroup
                          ? Checkbox(
                              value: selected,
                              onChanged: _submitting
                                  ? null
                                  : (v) => setState(() {
                                        if (v == true) {
                                          _selectedIds.add(p.userId);
                                        } else {
                                          _selectedIds.remove(p.userId);
                                        }
                                      }),
                            )
                          : Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? palette.featureCardAccent
                                  : palette.sidebarLabelSecondary,
                            ),
                      onTap: _submitting
                          ? null
                          : () => setState(() {
                                if (_isGroup) {
                                  if (selected) {
                                    _selectedIds.remove(p.userId);
                                  } else {
                                    _selectedIds.add(p.userId);
                                  }
                                } else {
                                  _selectedIds
                                    ..clear()
                                    ..add(p.userId);
                                }
                              }),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.featureCardAccent,
                    shape: RoundedRectangleBorder(borderRadius: palette.br),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isGroup
                              ? l10n.newChatPickerCreate
                              : l10n.newChatPickerStart,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<UserProfile> _mergePeople(
    List<UserProfile> following,
    List<UserProfile> followers, {
    required String excludeUid,
  }) {
    final byId = <String, UserProfile>{};
    for (final p in [...following, ...followers]) {
      if (p.userId == excludeUid) continue;
      byId[p.userId] = p;
    }
    final list = byId.values.toList()
      ..sort((a, b) =>
          a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return list;
  }
}
