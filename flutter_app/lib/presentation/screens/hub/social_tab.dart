import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/config/supabase_config.dart';
import '../../theme/dm_tool_colors.dart';
import '../social/discover_tab.dart';
import '../social/feed_tab.dart';
import '../social/marketplace_tab.dart';
import '../social/messages_tab.dart';
import '../social/players_tab.dart';
import '../social/social_shell.dart';

/// Aktif Social sub-tab'ı — hub_screen help button'u hangi yardım metnini
/// göstereceğini buradan okur (Marketplace için ayrı metin göstermek için).
final socialSubTabProvider = StateProvider<String>((ref) => 'feed');

/// Social hub shell — 4 alt sekme: Feed, Players, Messages, Marketplace.
/// Cloud backup ARTIK burada değil — top-right cloud icon'da.
class SocialTab extends ConsumerStatefulWidget {
  const SocialTab({super.key});

  @override
  ConsumerState<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends ConsumerState<SocialTab> {
  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) return const _NotConfigured();

    final auth = ref.watch(authProvider);
    if (auth == null) return const _NotSignedIn();

    final currentTab = ref.watch(socialSubTabProvider);
    final messageUnread = ref.watch(totalUnreadCountProvider).value ?? 0;
    return SocialShell(
      currentTab: currentTab,
      messagesBadgeCount: messageUnread,
      onTabChanged: (t) =>
          ref.read(socialSubTabProvider.notifier).state = t,
      child: switch (currentTab) {
        'feed' => const FeedTab(),
        'players' => const PlayersTab(),
        'messages' => const MessagesTab(),
        'marketplace' => const MarketplaceTab(),
        'discover' => const DiscoverTab(),
        _ => const FeedTab(),
      },
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text('Social features unavailable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
          const SizedBox(height: 8),
          Text('Supabase backend is not configured.',
              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
        ],
      ),
    );
  }
}

class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_circle_outlined, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text('Not Signed In',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
          const SizedBox(height: 8),
          Text('Sign in to access social features.',
              style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: Icon(Icons.login, size: 18, color: palette.featureCardAccent),
            label: Text('Sign In', style: TextStyle(color: palette.featureCardAccent)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.featureCardAccent),
              shape: RoundedRectangleBorder(borderRadius: palette.br),
            ),
          ),
        ],
      ),
    );
  }
}
