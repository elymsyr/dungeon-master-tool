import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/follows_provider.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/user_profile.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/profile_avatar.dart';

/// Profile ekranındaki Followers / Following count'larına tıklanınca açılan
/// dialog. İki mod: 'followers' (kullanıcının takipçileri) veya 'following'
/// (kullanıcının takip ettikleri).
enum FollowListMode { followers, following }

class FollowListDialog extends ConsumerWidget {
  final String userId;
  final FollowListMode mode;
  const FollowListDialog({super.key, required this.userId, required this.mode});

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required FollowListMode mode,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FollowListDialog(userId: userId, mode: mode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final async = mode == FollowListMode.followers
        ? ref.watch(followersProvider(userId))
        : ref.watch(followingProvider(userId));
    final title = mode == FollowListMode.followers
        ? l10n.profileFollowersDialog
        : l10n.profileFollowingDialog;
    final emptyText = mode == FollowListMode.followers
        ? l10n.profileNoFollowers
        : l10n.profileNoFollowing;

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(formatError(e),
                style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    emptyText,
                    style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
                  ),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.featureCardBorder),
                itemBuilder: (_, i) => _UserRow(profile: list[i], palette: palette),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserProfile profile;
  final DmToolColors palette;
  const _UserRow({required this.profile, required this.palette});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ProfileAvatar(
        avatarUrl: profile.avatarUrl,
        fallbackText: profile.username,
        size: 36,
      ),
      title: Text(
        profile.displayName ?? profile.username,
        style: TextStyle(fontSize: 13, color: palette.tabActiveText),
      ),
      subtitle: Text(
        '@${profile.username}',
        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
      ),
      trailing: Icon(Icons.chevron_right, color: palette.sidebarLabelSecondary),
      onTap: () {
        Navigator.pop(context);
        context.push('/profile/${profile.userId}');
      },
    );
  }
}
