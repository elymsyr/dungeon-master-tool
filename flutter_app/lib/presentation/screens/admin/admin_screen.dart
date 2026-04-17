import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/utils/screen_type.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../dialogs/admin_compose_dm_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/pill_tab_bar.dart';
import 'audit_log_tab.dart';
import 'bug_reports_tab.dart';
import 'builtins_tab.dart';
import 'content_moderation_tab.dart';
import 'restricted_users_tab.dart';

/// Admin paneli — PillTabBar ile 4 sekme: Dashboard / Users / Banned / Storage.
/// Erişim Supabase `is_admin()` RPC'si ile korunur; admin olmayan kullanıcı
/// route'a erişse bile "Access denied" görür.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _tab = 'dashboard';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final phone = isPhone(context);
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Panel')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 64, color: palette.dangerBtnBg),
                  const SizedBox(height: 12),
                  Text('Access denied',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  const SizedBox(height: 4),
                  Text('Admin privileges required.',
                      style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                ],
              ),
            ),
          );
        }

        final tabs = <PillTab<String>>[
          const PillTab(id: 'dashboard', icon: Icons.dashboard_outlined, label: 'Dashboard'),
          const PillTab(id: 'users', icon: Icons.people_outline, label: 'Users'),
          const PillTab(id: 'content', icon: Icons.forum_outlined, label: 'Content'),
          const PillTab(id: 'builtins', icon: Icons.star_border, label: 'Built-ins'),
          const PillTab(id: 'reports', icon: Icons.bug_report_outlined, label: 'Reports'),
          const PillTab(id: 'banned', icon: Icons.block_outlined, label: 'Banned'),
          const PillTab(id: 'restricted', icon: Icons.lock_outline, label: 'Restricted'),
          const PillTab(id: 'audit', icon: Icons.fact_check_outlined, label: 'Audit'),
          const PillTab(id: 'storage', icon: Icons.storage_outlined, label: 'Storage'),
        ];
        final bar = PillTabBar<String>(
          tabs: tabs,
          currentTab: _tab,
          onTabChanged: (id) => setState(() => _tab = id),
          phone: phone,
          showBorderTop: phone,
          showBorderBottom: !phone,
        );

        final Widget content;
        switch (_tab) {
          case 'users':
            content = const _UsersTab();
            break;
          case 'content':
            content = const ContentModerationTab();
            break;
          case 'builtins':
            content = const BuiltinsTab();
            break;
          case 'reports':
            content = const BugReportsTab();
            break;
          case 'banned':
            content = const _BannedTab();
            break;
          case 'restricted':
            content = const RestrictedUsersTab();
            break;
          case 'audit':
            content = const AuditLogTab();
            break;
          case 'storage':
            content = const _StorageTab();
            break;
          default:
            content = const _DashboardTab();
        }

        final constrained = phone
            ? content
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: content,
                ),
              );

        return Scaffold(
          appBar: AppBar(title: const Text('Admin Panel')),
          body: Column(
            children: phone
                ? [Expanded(child: constrained), bar]
                : [bar, Expanded(child: constrained)],
          ),
        );
      },
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border.all(color: palette.featureCardBorder),
            borderRadius: palette.cbr,
          ),
          child: Row(
            children: [
              Icon(Icons.shield, size: 24, color: palette.featureCardAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin mode active',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                    Text('You can publish updates to built-in templates.',
                        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border.all(color: palette.featureCardBorder),
            borderRadius: palette.cbr,
          ),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Built-in template editor'),
            subtitle: const Text('Edit and publish updates to the built-in D&D 5e template'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open via Templates tab → built-in template card')),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Shared card container ───────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _AdminCard({required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return _AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: palette.br,
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: palette.sidebarLabelSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Users ───────────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final usersAsync = ref.watch(adminUserListProvider);
    final statsAsync = ref.watch(adminUserStatsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_outline,
                  label: 'TOTAL USERS',
                  value: statsAsync.maybeWhen(
                    data: (s) => s.total.toString(),
                    orElse: () => '…',
                  ),
                  accent: palette.featureCardAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.science_outlined,
                  label: 'BETA USERS',
                  value: statsAsync.maybeWhen(
                    data: (s) => s.beta.toString(),
                    orElse: () => '…',
                  ),
                  accent: palette.featureCardAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Search by email or username…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      ref.read(adminUserSearchQueryProvider.notifier).state = v;
                      setState(() {});
                    },
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      ref.read(adminUserSearchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(adminUserListProvider);
                    ref.invalidate(adminUserStatsProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text('No users found.',
                        style: TextStyle(color: palette.sidebarLabelSecondary)),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _UserRow(user: users[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final AdminUserSummary user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final title = user.username ?? '(no username)';
    final versionPart = user.appVersion == null
        ? null
        : 'v${user.appVersion}${user.platform != null ? " · ${user.platform}" : ""}';
    final subtitleParts = <String>[
      user.email ?? user.userId,
      formatBytes(user.storageBytes),
      formatRelative(user.lastActiveAt),
      ?versionPart,
    ];
    final subtitle = subtitleParts.join(' · ');

    return _AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: user.isBanned
                ? palette.dangerBtnBg.withValues(alpha: 0.15)
                : user.onlineRestricted
                    ? palette.dangerBtnBg.withValues(alpha: 0.10)
                    : palette.featureCardAccent.withValues(alpha: 0.15),
            child: Icon(
              user.isBanned
                  ? Icons.block
                  : user.onlineRestricted
                      ? Icons.lock_outline
                      : Icons.person_outline,
              color: user.isBanned || user.onlineRestricted
                  ? palette.dangerBtnBg
                  : palette.featureCardAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    _Chip(label: user.provider.toUpperCase(), color: palette.featureCardBorder),
                    if (user.isBeta)
                      _Chip(label: 'BETA', color: palette.featureCardAccent),
                    if (user.isBanned)
                      _Chip(label: 'BANNED', color: palette.dangerBtnBg),
                    if (user.onlineRestricted && !user.isBanned)
                      _Chip(label: 'RESTRICTED', color: palette.dangerBtnBg),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            tooltip: 'Message',
            onPressed: () => AdminComposeDmDialog.show(
              context,
              targetUserId: user.userId,
              targetName: user.username ?? user.email ?? 'user',
            ),
          ),
          if (!user.isBanned)
            IconButton(
              icon: Icon(
                user.onlineRestricted ? Icons.lock_open : Icons.lock_outline,
                size: 18,
                color: user.onlineRestricted
                    ? palette.featureCardAccent
                    : palette.dangerBtnBg,
              ),
              tooltip:
                  user.onlineRestricted ? 'Remove online restriction' : 'Restrict online',
              onPressed: () => _toggleRestriction(context, ref),
            ),
          user.isBanned
              ? TextButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Unban'),
                  onPressed: () => _unban(context, ref),
                )
              : TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: palette.dangerBtnBg),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Ban'),
                  onPressed: () => _banDialog(context, ref),
                ),
        ],
      ),
    );
  }

  Future<void> _toggleRestriction(BuildContext context, WidgetRef ref) async {
    if (user.onlineRestricted) {
      try {
        await ref.read(adminUsersDataSourceProvider).setOnlineRestriction(
              userId: user.userId,
              restricted: false,
            );
        ref.invalidate(adminUserListProvider);
        ref.invalidate(adminRestrictedUsersProvider);
        ref.invalidate(adminAuditLogProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Online restriction removed.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Unrestrict failed: $e')));
        }
      }
      return;
    }
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restrict ${user.username ?? user.email ?? "user"}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User can sign in and browse, but cannot post, like, message, publish to marketplace, or apply to games. Marketplace downloads still work.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restrict'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminUsersDataSourceProvider).setOnlineRestriction(
            userId: user.userId,
            restricted: true,
            reason: controller.text.trim().isEmpty ? null : controller.text.trim(),
          );
      ref.invalidate(adminUserListProvider);
      ref.invalidate(adminRestrictedUsersProvider);
      ref.invalidate(adminAuditLogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User restricted online.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restrict failed: $e')));
      }
    }
  }

  Future<void> _banDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ban ${user.username ?? user.email ?? "user"}?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminUsersDataSourceProvider).banUser(user.userId, controller.text);
      ref.invalidate(adminUserListProvider);
      ref.invalidate(adminBannedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ban failed: $e')));
      }
    }
  }

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminUsersDataSourceProvider).unbanUser(user.userId);
      ref.invalidate(adminUserListProvider);
      ref.invalidate(adminBannedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unbanned.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unban failed: $e')));
      }
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    );
  }
}

// ─── Banned ──────────────────────────────────────────────────────────────────

class _BannedTab extends ConsumerWidget {
  const _BannedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final bannedAsync = ref.watch(adminBannedUsersProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: bannedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 8),
                  Text('No banned users.',
                      style: TextStyle(color: palette.sidebarLabelSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminBannedUsersProvider),
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = entries[i];
                return _AdminCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: palette.dangerBtnBg.withValues(alpha: 0.15),
                        child: Icon(Icons.block, color: palette.dangerBtnBg, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.username ?? e.email ?? e.userId,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.tabActiveText)),
                            const SizedBox(height: 2),
                            if (e.email != null)
                              Text(e.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: palette.sidebarLabelSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${e.reason ?? "No reason provided"} · ${_fmt(e.bannedAt)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: palette.tabText,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        tooltip: 'Message',
                        onPressed: () => AdminComposeDmDialog.show(
                          context,
                          targetUserId: e.userId,
                          targetName: e.username ?? e.email ?? 'user',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Unban'),
                        onPressed: () async {
                          try {
                            await ref
                                .read(adminUsersDataSourceProvider)
                                .unbanUser(e.userId);
                            ref.invalidate(adminBannedUsersProvider);
                            ref.invalidate(adminUserListProvider);
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Unban failed: $err')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Storage ─────────────────────────────────────────────────────────────────

class _StorageTab extends ConsumerWidget {
  const _StorageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final statsAsync = ref.watch(adminStorageStatsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) {
          final total = stats.fold<int>(0, (acc, s) => acc + s.usedBytes);
          final totalObjects = stats.fold<int>(0, (acc, s) => acc + s.objectCount);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminStorageStatsProvider),
            child: ListView(
              children: [
                _AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.featureCardAccent.withValues(alpha: 0.15),
                          borderRadius: palette.br,
                        ),
                        child: Icon(Icons.cloud_outlined,
                            size: 28, color: palette.featureCardAccent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Supabase Storage',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: palette.sidebarLabelSecondary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4)),
                            const SizedBox(height: 2),
                            Text(formatBytes(total),
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: palette.tabActiveText)),
                            Text('$totalObjects objects across ${stats.length} buckets',
                                style: TextStyle(
                                    fontSize: 11, color: palette.sidebarLabelSecondary)),
                            const SizedBox(height: 4),
                            Text('Quota limit not available',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: palette.sidebarLabelSecondary,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('BY BUCKET',
                    style: TextStyle(
                        fontSize: 10,
                        color: palette.sidebarLabelSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (stats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No storage objects.',
                          style: TextStyle(color: palette.sidebarLabelSecondary)),
                    ),
                  )
                else
                  ...stats.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AdminCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined,
                                  color: palette.featureCardAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.bucketId,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: palette.tabActiveText)),
                                    Text('${s.objectCount} objects',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: palette.sidebarLabelSecondary)),
                                  ],
                                ),
                              ),
                              Text(formatBytes(s.usedBytes),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: palette.tabActiveText)),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

}
