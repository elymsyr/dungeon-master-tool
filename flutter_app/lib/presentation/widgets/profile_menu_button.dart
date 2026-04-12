import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/admin_provider.dart';
import '../../application/providers/auth_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../core/config/supabase_config.dart';
import '../dialogs/confirm_sign_out_dialog.dart';
import '../theme/dm_tool_colors.dart';
import 'profile_avatar.dart';

/// Top-right'taki sign in/out icon'unun yerini alan menü.
/// Auth varsa: avatar + username + admin badge + popup menu (View Profile,
/// Edit Profile, Admin Panel?, Sign Out).
/// Auth yoksa: küçük "Sign In" ghost butonu.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();

    final auth = ref.watch(authProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    if (auth == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton.icon(
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Sign In'),
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(foregroundColor: palette.featureCardAccent),
        ),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider);
    final isAdminAsync = ref.watch(isAdminProvider);

    final username = profileAsync.maybeWhen(
      data: (p) => p?.username ?? auth.email.split('@').first,
      orElse: () => auth.email.split('@').first,
    );
    final avatarUrl = profileAsync.maybeWhen(
      data: (p) => p?.avatarUrl,
      orElse: () => null,
    );
    final isAdmin = isAdminAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        switch (value) {
          case 'view':
            context.push('/profile/me');
          case 'edit':
            context.push('/profile/me?edit=1');
          case 'admin':
            context.push('/admin');
          case 'signout':
            confirmAndSignOut(context, ref);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'view',
          child: Row(children: [
            const Icon(Icons.person_outline, size: 18),
            const SizedBox(width: 12),
            Text('View Profile', style: TextStyle(color: palette.tabActiveText)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 12),
            Text('Edit Profile', style: TextStyle(color: palette.tabActiveText)),
          ]),
        ),
        if (isAdmin)
          PopupMenuItem<String>(
            value: 'admin',
            child: Row(children: [
              Icon(Icons.shield_outlined, size: 18, color: palette.featureCardAccent),
              const SizedBox(width: 12),
              Text('Admin Panel',
                  style: TextStyle(color: palette.featureCardAccent, fontWeight: FontWeight.w600)),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: palette.dangerBtnBg),
            const SizedBox(width: 12),
            Text('Sign Out', style: TextStyle(color: palette.dangerBtnBg)),
          ]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(avatarUrl: avatarUrl, fallbackText: username, size: 28),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                username,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 4),
              Icon(Icons.shield, size: 14, color: palette.featureCardAccent),
            ],
            Icon(Icons.arrow_drop_down, size: 18, color: palette.sidebarLabelSecondary),
          ],
        ),
      ),
    );
  }
}
