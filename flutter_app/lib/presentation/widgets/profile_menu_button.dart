import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/account_gate.dart';
import '../../application/providers/admin_provider.dart';
import '../../application/providers/auth_provider.dart';
import '../../application/providers/hub_tab_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../dialogs/bug_report_dialog.dart';
import '../dialogs/lan_sync_dialog.dart';
import '../dialogs/confirm_sign_out_dialog.dart';
import '../dialogs/support_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'profile_avatar.dart';

/// Top-right'taki sign in/out icon'unun yerini alan menü.
///
/// Menü **her** [AccountAccess] durumunda açılır; değişen yalnızca içeriği:
/// hesap gerektirmeyen öğeler (Settings, LAN Sync, Support, Report Bug) herkese
/// açıktır — bir misafirin bunlara ulaşmak için giriş sayfasına atılması, O1/O2
/// ile ayrılan "yerel olan gate'lenmez" kuralının ihlaliydi. Profil / Admin /
/// Sign Out yalnızca [AccountAccess.signedIn] durumunda; misafir bunların
/// yerine landing'e götüren tek bir "Sign In" öğesi görür; offline build'de
/// hesap diye bir şey olmadığı için ikisi de yoktur.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final access = ref.watch(accountGateProvider);
    final auth = access == AccountAccess.signedIn ? ref.watch(authProvider) : null;

    final profileAsync =
        auth == null ? null : ref.watch(currentProfileProvider);
    final isAdmin = auth == null
        ? false
        : ref.watch(isAdminProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final username = auth == null
        ? null
        : profileAsync!.maybeWhen(
            data: (p) => p?.username ?? auth.email.split('@').first,
            orElse: () => auth.email.split('@').first,
          );
    final avatarUrl = auth == null
        ? null
        : profileAsync!.maybeWhen(data: (p) => p?.avatarUrl, orElse: () => null);

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      Color? color,
      FontWeight? weight,
    }) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color ?? palette.tabActiveText, fontWeight: weight)),
          ]),
        );

    return PopupMenuButton<String>(
      tooltip: auth == null ? l10n.hubSettingsTooltip : l10n.profileMenuTooltip,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      onSelected: (value) {
        switch (value) {
          case 'view':
            context.push('/profile/me');
          case 'edit':
            context.push('/profile/me?edit=1');
          case 'local_sync':
            LanSyncDialog.show(context);
          case 'settings':
            ref.read(hubTabIndexProvider.notifier).state = settingsTabIndex;
          case 'support':
            SupportDialog.show(context);
          case 'admin':
            context.push('/admin');
          case 'bug_report':
            BugReportDialog.show(context);
          case 'signin':
            context.go('/');
          case 'signout':
            confirmAndSignOut(context, ref);
        }
      },
      itemBuilder: (ctx) => [
        if (auth != null) ...[
          item('view', Icons.person_outline, l10n.profileMenuViewProfile),
          item('edit', Icons.edit_outlined, l10n.profileMenuEditProfile),
        ],
        item('local_sync', Icons.wifi_tethering, l10n.lanSyncOpen),
        item('settings', Icons.settings_outlined, l10n.profileMenuSettings),
        item('support', Icons.favorite_outline, l10n.profileMenuSupport),
        if (isAdmin)
          item('admin', Icons.shield_outlined, l10n.profileMenuAdminPanel,
              color: palette.featureCardAccent, weight: FontWeight.w600),
        const PopupMenuDivider(),
        item('bug_report', Icons.bug_report_outlined, l10n.profileMenuReportBug),
        if (auth != null)
          item('signout', Icons.logout, l10n.signOut, color: palette.dangerBtnBg)
        else if (access == AccountAccess.guest)
          item('signin', Icons.login, l10n.profileMenuSignIn,
              color: palette.featureCardAccent, weight: FontWeight.w600),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (auth == null)
              Icon(Icons.account_circle_outlined,
                  size: 24, color: palette.sidebarLabelSecondary)
            else ...[
              ProfileAvatar(
                  avatarUrl: avatarUrl, fallbackText: username!, size: 28),
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
            ],
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
