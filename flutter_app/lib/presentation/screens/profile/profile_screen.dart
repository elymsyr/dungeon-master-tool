import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/profile_edit_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';

/// Kullanıcı profili ekranı. `userId` "me" olursa şu anki auth user.
/// Başka bir kullanıcının profiliyse Follow / Message butonları gösterilir.
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool openEditOnLoad;
  const ProfileScreen({super.key, required this.userId, this.openEditOnLoad = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editTriggered = false;

  String _resolveUid(WidgetRef ref) {
    if (widget.userId == 'me') {
      final auth = ref.read(authProvider);
      return auth?.uid ?? '';
    }
    return widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final auth = ref.watch(authProvider);
    final uid = _resolveUid(ref);
    final isMe = uid == auth?.uid;

    final profileAsync = isMe
        ? ref.watch(currentProfileProvider)
        : ref.watch(profileByIdProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            // Henüz profil oluşturulmamış. Kendiyse edit dialog tetikle.
            if (isMe && !_editTriggered) {
              _editTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) ProfileEditDialog.show(context);
              });
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 64, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 12),
                  const Text('No profile yet'),
                  if (isMe) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ProfileEditDialog.show(context),
                      child: const Text('Create profile'),
                    ),
                  ],
                ],
              ),
            );
          }
          // Auto-trigger edit if requested via query string
          if (isMe && widget.openEditOnLoad && !_editTriggered) {
            _editTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ProfileEditDialog.show(context, existing: profile);
            });
          }
          return _ProfileBody(profile: profile, isMe: isMe);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final UserProfile profile;
  final bool isMe;
  const _ProfileBody({required this.profile, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              ProfileAvatar(
                avatarUrl: profile.avatarUrl,
                fallbackText: profile.username,
                size: 96,
              ),
              const SizedBox(height: 12),
              Text(
                profile.displayName ?? profile.username,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: palette.tabActiveText),
              ),
              Text('@${profile.username}',
                  style: TextStyle(fontSize: 14, color: palette.sidebarLabelSecondary)),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(profile.bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: palette.tabText)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CountTile(label: 'Followers', value: profile.followers),
                  const SizedBox(width: 32),
                  _CountTile(label: 'Following', value: profile.following),
                ],
              ),
              const SizedBox(height: 20),
              if (isMe)
                FilledButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit profile'),
                  onPressed: () => ProfileEditDialog.show(context, existing: profile),
                )
              else
                _FollowButton(targetUserId: profile.userId),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // Public items + recent posts placeholders — Phase 2/3'te dolacak
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  border: Border.all(color: palette.featureCardBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 24, color: palette.featureCardAccent),
                    const SizedBox(height: 8),
                    Text('Posts and public items will appear here',
                        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
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

class _CountTile extends StatelessWidget {
  final String label;
  final int value;
  const _CountTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Column(
      children: [
        Text('$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
        Text(label, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(isFollowingProvider(targetUserId));
    final toggleState = ref.watch(followToggleProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return following.when(
      loading: () => const SizedBox(width: 120, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, st) => const Text('Error loading follow state'),
      data: (isFollowing) {
        final busy = toggleState is AsyncLoading;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              icon: Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
              label: Text(isFollowing ? 'Following' : 'Follow'),
              style: FilledButton.styleFrom(
                backgroundColor: isFollowing ? palette.featureCardBg : palette.featureCardAccent,
                foregroundColor: isFollowing ? palette.tabActiveText : Colors.white,
                side: isFollowing ? BorderSide(color: palette.featureCardBorder) : null,
              ),
              onPressed: busy
                  ? null
                  : () => ref.read(followToggleProvider.notifier).toggle(targetUserId),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('DM coming in next update')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
