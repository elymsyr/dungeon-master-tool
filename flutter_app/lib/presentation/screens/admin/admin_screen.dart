import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/first_party_catalog_provider.dart';
import '../../../application/providers/global_loading_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/utils/screen_type.dart';
import '../../../application/services/bundled_worlds_installer.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../dialogs/admin_compose_dm_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/pill_tab_bar.dart';
import 'audit_log_tab.dart';
import 'bug_reports_tab.dart';
import 'content_moderation_tab.dart';
import 'notifications_admin_tab.dart';
import 'restricted_users_tab.dart';
import '../../l10n/app_localizations.dart';

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
      error: (e, st) => Scaffold(body: Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e')))),
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: Text(L10n.of(context)!.profileMenuAdminPanel)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 64, color: palette.dangerBtnBg),
                  const SizedBox(height: 12),
                  Text(L10n.of(context)!.adminAccessDenied,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  const SizedBox(height: 4),
                  Text(L10n.of(context)!.adminPrivilegesRequired,
                      style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                ],
              ),
            ),
          );
        }

        final tabs = <PillTab<String>>[
          PillTab(id: 'dashboard', icon: Icons.dashboard_outlined, label: L10n.of(context)!.adminTabDashboard),
          PillTab(id: 'users', icon: Icons.people_outline, label: L10n.of(context)!.adminTabUsers),
          PillTab(id: 'notifications', icon: Icons.campaign_outlined, label: L10n.of(context)!.notifAdminTab),
          PillTab(id: 'content', icon: Icons.forum_outlined, label: L10n.of(context)!.adminTabContent),
          PillTab(id: 'reports', icon: Icons.bug_report_outlined, label: L10n.of(context)!.adminTabReports),
          PillTab(id: 'banned', icon: Icons.block_outlined, label: L10n.of(context)!.adminTabBanned),
          PillTab(id: 'restricted', icon: Icons.lock_outline, label: L10n.of(context)!.adminTabRestricted),
          PillTab(id: 'audit', icon: Icons.fact_check_outlined, label: L10n.of(context)!.adminTabAudit),
          PillTab(id: 'storage', icon: Icons.storage_outlined, label: L10n.of(context)!.adminTabStorage),
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
          case 'notifications':
            content = const NotificationsAdminTab();
            break;
          case 'content':
            content = const ContentModerationTab();
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
          appBar: AppBar(title: Text(L10n.of(context)!.profileMenuAdminPanel)),
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

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final showAssetsPacks =
        ref.watch(uiStateProvider.select((s) => s.showAssetsPacks));
    final showBundledWorlds =
        ref.watch(uiStateProvider.select((s) => s.showBundledWorlds));
    // BB-1: only offer the bundled-assets installer when the (dev/admin-only)
    // Open5e packs actually ship in this build — hidden in normal prod builds.
    final assetsPacksAvailable =
        ref.watch(assetsPacksAvailableProvider).valueOrNull ?? false;
    final bundledWorldsAvailable =
        ref.watch(bundledWorldsAvailableProvider).valueOrNull ?? false;
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
                child: Text(L10n.of(context)!.adminModeActive,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText)),
              ),
            ],
          ),
        ),
        if (assetsPacksAvailable) ...[
          const SizedBox(height: 12),
          _AdminCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: showAssetsPacks,
              onChanged: (v) => _toggleAssetsPacks(context, ref, v),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(L10n.of(context)!.adminInstallAssetPacks,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              subtitle: Text(
                  L10n.of(context)!.adminInstallAssetPacksHint,
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
            ),
          ),
        ],
        if (!kIsWeb) ...[
          const SizedBox(height: 12),
          _AdminCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(L10n.of(context)!.adminImportWorldZip,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              subtitle: Text(
                  L10n.of(context)!.adminImportWorldZipHint,
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
              trailing: TextButton(
                onPressed: () => _importWorldZip(context, ref),
                child: Text(L10n.of(context)!.adminChooseZip),
              ),
            ),
          ),
        ],
        if (!kIsWeb &&
            defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ...[
          const SizedBox(height: 12),
          _AdminCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(L10n.of(context)!.adminImportWorldFolder,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              subtitle: Text(
                  L10n.of(context)!.adminImportWorldFolderHint,
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
              trailing: TextButton(
                onPressed: () => _importWorldFolder(context, ref),
                child: Text(L10n.of(context)!.adminChooseFolder),
              ),
            ),
          ),
        ],
        if (bundledWorldsAvailable) ...[
          const SizedBox(height: 12),
          _AdminCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: showBundledWorlds,
              onChanged: (v) => _toggleBundledWorlds(context, ref, v),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(L10n.of(context)!.adminInstallBundledWorlds,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
              subtitle: Text(
                  L10n.of(context)!.adminInstallBundledWorldsHint,
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleAssetsPacks(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    // Flip the persisted flag first so the switch reflects the new state.
    ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
          showAssetsPacks: on,
        ));
    final installer = ref.read(assetsPackInstallerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context)!;
    try {
      final count = await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'assets-packs-toggle',
        on ? 'Installing asset packs…' : 'Removing asset packs…',
        () => on ? installer.installAll() : installer.uninstallAll(),
      );
      ref.invalidate(packageListProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(on
            ? 'Installed $count asset pack(s).'
            : 'Removed $count asset pack(s).'),
      ));
    } catch (e) {
      // Roll the flag back so it doesn't claim a state we failed to reach.
      ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
            showAssetsPacks: !on,
          ));
      messenger.showSnackBar(SnackBar(content: Text(l10n.failedGeneric('$e'))));
    }
  }

  Future<void> _importWorldZip(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select a world zip', type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return;
    await _runWorldImport(
        context, ref, (i) => i.installFromZip(path));
  }

  Future<void> _importWorldFolder(BuildContext context, WidgetRef ref) async {
    final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select a world folder');
    if (dir == null || !context.mounted) return;
    await _runWorldImport(
        context, ref, (i) => i.installFromDirectory(dir));
  }

  Future<void> _runWorldImport(
    BuildContext context,
    WidgetRef ref,
    Future<InstallReport> Function(BundledWorldsInstaller) install,
  ) async {
    final installer = ref.read(bundledWorldsInstallerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context)!;
    try {
      final summary = await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'world-folder-import',
        'Importing world…',
        () async {
          final report = await install(installer);
          for (final issue in [...report.failures, ...report.issues]) {
            debugPrint('[world-import] $issue');
          }
          if (report.count == 0) {
            return 'Import failed — see logs.';
          }
          return report.isClean
              ? 'Installed ${report.installed.join(", ")}.'
              : 'Installed ${report.count} world(s) with '
                  '${report.issues.length + report.failures.length} '
                  'content issue(s) — see logs.';
        },
      );
      // Worlds sekmesi listeyi `campaignInfoListProvider`'dan, kartın
      // banner/açıklamasını `campaignMetadataProvider`'dan okuyor. Yalnız
      // campaignListProvider'ı tazelemek, üstüne kurulan dünyanın kartını
      // eski (çoğu zaman boş) metadata'yla bırakıyordu.
      ref.invalidate(campaignInfoListProvider);
      ref.invalidate(campaignMetadataProvider);
      ref.invalidate(packageListProvider);
      ref.invalidate(characterListProvider);
      messenger.showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.failedGeneric('$e'))));
    }
  }

  Future<void> _toggleBundledWorlds(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
          showBundledWorlds: on,
        ));
    final installer = ref.read(bundledWorldsInstallerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context)!;
    try {
      final summary = await withLoading(
        ref.read(globalLoadingProvider.notifier),
        'bundled-worlds-toggle',
        on ? 'Installing bundled worlds…' : 'Removing bundled worlds…',
        () async {
          if (!on) {
            return 'Removed ${await installer.uninstallAll()} bundled world(s).';
          }
          final report = await installer.installAll();
          // Kısmi kurulumu sessizce başarı gibi gösterme: çözülemeyen ref
          // okuma anında sessizce düşer, kullanıcı eksik listeyi göremez.
          for (final issue in [...report.failures, ...report.issues]) {
            debugPrint('[bundled-worlds] $issue');
          }
          return report.isClean
              ? 'Installed ${report.count} bundled world(s).'
              : 'Installed ${report.count} world(s) with '
                  '${report.issues.length + report.failures.length} '
                  'content issue(s) — see logs.';
        },
      );
      // Dünyalar Worlds sekmesinde listeleniyor — paket listesini tazelemek
      // yetmiyor, yeni kurulan dünya yenilenene kadar görünmüyordu.
      ref.invalidate(packageListProvider);
      // PC'ler artık world_characters'a yazılıyor — liste tazelenmezse
      // Characters sekmesi kurulumdan sonra boş görünüyor.
      ref.invalidate(characterListProvider);
      messenger.showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      ref.read(uiStateProvider.notifier).update((s) => s.copyWith(
            showBundledWorlds: !on,
          ));
      messenger.showSnackBar(SnackBar(content: Text(l10n.failedGeneric('$e'))));
    }
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
    final usersAsync = ref.watch(adminUserSortedListProvider);
    final statsAsync = ref.watch(adminUserStatsProvider);
    final sortMode = ref.watch(adminUserSortModeProvider);
    final sortReversed = ref.watch(adminUserSortReversedProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.people_outline,
                  label: L10n.of(context)!.adminTotalUsers,
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
                  icon: Icons.access_time,
                  label: L10n.of(context)!.adminActive30d,
                  value: usersAsync.maybeWhen(
                    data: (users) {
                      final cutoff = DateTime.now().subtract(const Duration(days: 30));
                      return users
                          .where((u) => u.lastActiveAt != null && u.lastActiveAt!.isAfter(cutoff))
                          .length
                          .toString();
                    },
                    orElse: () => '…',
                  ),
                  accent: palette.successBtnBg,
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
                    decoration: InputDecoration(
                      hintText: L10n.of(context)!.adminSearchUsers,
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
                  tooltip: L10n.of(context)!.btnRefresh,
                  onPressed: () {
                    ref.invalidate(adminUserListProvider);
                    ref.invalidate(adminUserStatsProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.sort, size: 16, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 8),
                Text(L10n.of(context)!.adminSort,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.sidebarLabelSecondary)),
                const SizedBox(width: 6),
                _SortDropdown(
                  value: sortMode,
                  onChanged: (v) {
                    ref.read(adminUserSortModeProvider.notifier).state = v;
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    sortReversed ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                  ),
                  tooltip: sortReversed ? L10n.of(context)!.adminNewestFirst : L10n.of(context)!.adminOldestFirst,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(adminUserSortReversedProvider.notifier).state =
                        !sortReversed;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(L10n.of(context)!.discoverEmptySearch,
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
                    if (user.isBanned)
                      _Chip(label: L10n.of(context)!.adminChipBanned, color: palette.dangerBtnBg),
                    if (user.onlineRestricted && !user.isBanned)
                      _Chip(label: L10n.of(context)!.adminChipRestricted, color: palette.dangerBtnBg),
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
            tooltip: L10n.of(context)!.listingMessageApplicant,
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
                  user.onlineRestricted ? L10n.of(context)!.adminRemoveRestriction : L10n.of(context)!.adminRestrictOnline,
              onPressed: () => _toggleRestriction(context, ref),
            ),
          user.isBanned
              ? TextButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(L10n.of(context)!.adminUnban),
                  onPressed: () => _unban(context, ref),
                )
              : TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: palette.dangerBtnBg),
                  icon: const Icon(Icons.block, size: 16),
                  label: Text(L10n.of(context)!.adminBan),
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
              SnackBar(content: Text(L10n.of(context)!.adminRestrictionRemoved)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminUnrestrictFailed('$e'))));
        }
      }
      return;
    }
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.adminRestrictTitle(user.username ?? user.email ?? 'user')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context)!.adminRestrictBody,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: L10n.of(context)!.adminReasonOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.adminRestrict),
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
            SnackBar(content: Text(L10n.of(context)!.adminUserRestricted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminRestrictFailed('$e'))));
      }
    }
  }

  Future<void> _banDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.adminBanTitle(user.username ?? user.email ?? 'user')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: L10n.of(context)!.adminReasonOptional,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.adminBan),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminUserBanned)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminBanFailed('$e'))));
      }
    }
  }

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminUsersDataSourceProvider).unbanUser(user.userId);
      ref.invalidate(adminUserListProvider);
      ref.invalidate(adminBannedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminUserUnbanned)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminUnbanFailed('$e'))));
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

class _SortDropdown extends StatelessWidget {
  final AdminUserSortMode value;
  final ValueChanged<AdminUserSortMode> onChanged;
  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AdminUserSortMode>(
          value: value,
          isDense: true,
          isExpanded: false,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText),
          items: [
            DropdownMenuItem(
              value: AdminUserSortMode.registrationDate,
              child: Text(L10n.of(context)!.adminSortRegistered),
            ),
            DropdownMenuItem(
              value: AdminUserSortMode.lastSeen,
              child: Text(L10n.of(context)!.adminSortLastSeen),
            ),
            DropdownMenuItem(
              value: AdminUserSortMode.appVersion,
              child: Text(L10n.of(context)!.adminSortAppVersion),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
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
        error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 8),
                  Text(L10n.of(context)!.adminNoBanned,
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
                        tooltip: L10n.of(context)!.listingMessageApplicant,
                        onPressed: () => AdminComposeDmDialog.show(
                          context,
                          targetUserId: e.userId,
                          targetName: e.username ?? e.email ?? 'user',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(L10n.of(context)!.adminUnban),
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
                                  SnackBar(content: Text(L10n.of(context)!.adminUnbanFailed('$err'))));
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

/// R2 havuzu (10 GB, iki sınıf) — Supabase bucket'larından ayrı sayılır.
/// `pinned` dolarsa yeni marketplace yayını reddedilir, `transient` dolarsa
/// LRU en eskiyi atar; bu yüzden ikisi ayrı bar.
class _R2PoolSection extends ConsumerWidget {
  const _R2PoolSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final poolAsync = ref.watch(adminR2PoolStatsProvider);
    return poolAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(L10n.of(context)!.adminR2PoolError('$e'),
          style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
      data: (pool) {
        if (pool == null) return const SizedBox.shrink();
        final oldest = pool.oldestLastUsed;
        return _AdminCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L10n.of(context)!.adminR2Pool,
                  style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 12),
              _PoolBar(
                label: L10n.of(context)!.adminPoolPinned,
                used: pool.pinnedUsed,
                cap: pool.pinnedCap,
                subtitle: L10n.of(context)!.adminPoolPinnedSub('${pool.pinnedObjects}', formatBytes(pool.dedupSavedBytes)),
              ),
              const SizedBox(height: 12),
              _PoolBar(
                label: L10n.of(context)!.adminPoolTransient,
                used: pool.transientUsed,
                cap: pool.transientCap,
                subtitle: '${L10n.of(context)!.adminObjectCount('${pool.transientObjects}')}'
                    '${oldest == null ? '' : ' · ${L10n.of(context)!.adminOldest(oldest.toLocal().toString().split('.').first)}'}'
                    '${pool.evictQueueDepth == 0 ? '' : ' · ${pool.evictQueueDepth} queued for eviction'}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PoolBar extends StatelessWidget {
  const _PoolBar({
    required this.label,
    required this.used,
    required this.cap,
    required this.subtitle,
  });

  final String label;
  final int used;
  final int cap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ratio = cap <= 0 ? 0.0 : (used / cap).clamp(0.0, 1.0);
    final color = ratio >= 0.9
        ? Colors.redAccent
        : ratio >= 0.7
            ? Colors.orangeAccent
            : palette.featureCardAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText)),
            ),
            Text('${formatBytes(used)} / ${formatBytes(cap)}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: palette.sidebarLabelSecondary.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
      ],
    );
  }
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
        error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
        data: (stats) {
          final total = stats.fold<int>(0, (acc, s) => acc + s.usedBytes);
          final totalObjects = stats.fold<int>(0, (acc, s) => acc + s.objectCount);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminStorageStatsProvider);
              ref.invalidate(adminR2PoolStatsProvider);
            },
            child: ListView(
              children: [
                const _R2PoolSection(),
                const SizedBox(height: 16),
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
                            Text(L10n.of(context)!.adminStorageSummary('$totalObjects', '${stats.length}'),
                                style: TextStyle(
                                    fontSize: 11, color: palette.sidebarLabelSecondary)),
                            const SizedBox(height: 4),
                            Text(L10n.of(context)!.adminQuotaUnavailable,
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
                Text(L10n.of(context)!.adminByBucket,
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
                      child: Text(L10n.of(context)!.adminNoStorageObjects,
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
                                    Text(L10n.of(context)!.adminObjectCount('${s.objectCount}'),
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
