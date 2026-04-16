import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(discoverSearchQueryProvider.notifier).state = value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final hPad = isPhone(context) ? 12.0 : 24.0;
    final peopleAsync = ref.watch(discoverPeopleProvider);

    return RefreshIndicator(
      onRefresh: () async {
        invalidateCachePrefix('discover:');
        ref.invalidate(discoverPeopleProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.discoverSearchHint,
              prefixIcon: Icon(Icons.search, size: 20, color: palette.sidebarLabelSecondary),
              isDense: true,
              border: OutlineInputBorder(borderRadius: palette.cbr),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Header
          Text(
            _searchCtrl.text.trim().isEmpty
                ? l10n.discoverSuggestedHeader
                : l10n.discoverSearchResults,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.sidebarLabelSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Results
          peopleAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SocialCard(
              child: Text(formatError(e), style: TextStyle(color: palette.dangerBtnBg)),
            ),
            data: (people) {
              if (people.isEmpty) {
                return SocialEmptyState(
                  icon: Icons.person_search_outlined,
                  title: _searchCtrl.text.trim().isEmpty
                      ? l10n.discoverEmptyState
                      : l10n.discoverEmptySearch,
                );
              }
              return Column(
                children: [
                  for (final profile in people)
                    _DiscoverUserTile(profile: profile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiscoverUserTile extends ConsumerWidget {
  final UserProfile profile;
  const _DiscoverUserTile({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final override = ref.watch(followOverrideProvider(profile.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(profile.userId));
    final isFollowing = override ?? isFollowingAsync.value ?? false;

    return InkWell(
      borderRadius: palette.cbr,
      onTap: () => context.push('/profile/${profile.userId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: profile.avatarUrl,
              fallbackText: profile.username,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName ?? profile.username,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${profile.username}',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.bio!,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.tabText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: () {
                  ref.read(followToggleProvider.notifier).toggle(profile.userId);
                },
                style: TextButton.styleFrom(
                  backgroundColor: isFollowing
                      ? palette.featureCardBg
                      : palette.featureCardAccent,
                  foregroundColor: isFollowing
                      ? palette.tabText
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: palette.br,
                    side: BorderSide(
                      color: isFollowing ? palette.featureCardBorder : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  isFollowing ? l10n.btnUnfollow : l10n.btnFollow,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
