import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/marketplace_listing_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/utils/screen_type.dart';
import '../../../data/datasources/remote/posts_remote_ds.dart' show FeedScope;
import '../../../domain/entities/game_listing.dart';
import '../../../domain/entities/marketplace_listing.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/apply_listing_dialog.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/listing_banner_card.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

// ── Sealed type for attached listings ───────────────────────────────

sealed class AttachedListing {
  String get title;
}

class AttachedMarketplace extends AttachedListing {
  final MarketplaceListing listing;
  AttachedMarketplace(this.listing);
  @override
  String get title => listing.title;
}

class AttachedGameListing extends AttachedListing {
  final GameListing listing;
  AttachedGameListing(this.listing);
  @override
  String get title => listing.title;
}

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});
  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final _bodyCtrl = TextEditingController();
  bool _composerFocused = false;
  AttachedListing? _attached;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _bodyCtrl.text;
    if (raw.trim().isEmpty && _attached == null) return;
    final l10n = L10n.of(context)!;
    final ok = await ref.read(postComposerProvider.notifier).submit(
          body: raw,
          marketplaceItemId: switch (_attached) {
            AttachedMarketplace(listing: final l) => l.id,
            _ => null,
          },
          gameListingId: switch (_attached) {
            AttachedGameListing(listing: final l) => l.id,
            _ => null,
          },
        );
    if (ok) {
      _bodyCtrl.clear();
      setState(() => _attached = null);
    }
    if (!mounted) return;
    final state = ref.read(postComposerProvider);
    if (state is AsyncError) {
      if (state.error is ProfanityRejectedException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.feedProfanityRejected)),
        );
      } else if (state.error is PostRateLimitedException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.feedPostRateLimited)),
        );
      }
    }
    setState(() {});
  }

  Future<void> _pickListing() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    final l10n = L10n.of(context)!;

    final results = await Future.wait([
      ref.read(userMarketplaceListingsProvider(uid).future),
      ref.read(myGameListingsProvider.future),
    ]);
    final marketplaceItems = results[0] as List<MarketplaceListing>;
    final gameItems = results[1] as List<GameListing>;

    if (!mounted) return;
    if (marketplaceItems.isEmpty && gameItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedAttachNoListings)),
      );
      return;
    }

    final picked = await showDialog<AttachedListing>(
      context: context,
      builder: (ctx) => _ListingPickerDialog(
        marketplaceItems: marketplaceItems,
        gameItems: gameItems,
      ),
    );
    if (picked != null) setState(() => _attached = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final scope = ref.watch(feedScopeProvider);
    final hPad = isPhone(context) ? 12.0 : 24.0;

    if (scope == FeedScope.discover) {
      return RefreshIndicator(
        onRefresh: () async {
          invalidateCachePrefix('discover:');
          ref.invalidate(discoverPeopleProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
          children: [
            _FeedScopeTabs(scope: scope, palette: palette),
            const SizedBox(height: 16),
            const _DiscoverBody(),
          ],
        ),
      );
    }

    final feedAsync = ref.watch(feedProvider);
    final composerState = ref.watch(postComposerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        invalidateCachePrefix('feed:');
        ref.invalidate(feedProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: [
          _FeedScopeTabs(scope: scope, palette: palette),
          const SizedBox(height: 16),
          // Composer
          SocialCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _bodyCtrl,
                  maxLines: _composerFocused ? 4 : 2,
                  minLines: 1,
                  maxLength: 2000,
                  onTap: () => setState(() => _composerFocused = true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.feedComposerHint,
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
                if (_attached != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.featureCardAccent.withValues(alpha: 0.1),
                      borderRadius: palette.cbr,
                      border: Border.all(color: palette.featureCardAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          switch (_attached!) {
                            AttachedMarketplace(listing: final l) =>
                              iconForListingType(l.itemType),
                            AttachedGameListing() => Icons.groups_outlined,
                          },
                          size: 16, color: palette.featureCardAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _attached!.title,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.tabActiveText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _attached = null),
                          child: Icon(Icons.close, size: 16, color: palette.sidebarLabelSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.image_outlined, size: 20, color: palette.sidebarLabelSecondary),
                          tooltip: l10n.feedComposerImageTooltip,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.feedImageUploadComingSoon)),
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.storefront_outlined, size: 20,
                              color: _attached != null ? palette.featureCardAccent : palette.sidebarLabelSecondary),
                          tooltip: l10n.feedComposerAttachListing,
                          onPressed: _pickListing,
                        ),
                      ],
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.featureCardAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: palette.br),
                      ),
                      onPressed: composerState is AsyncLoading || (_bodyCtrl.text.trim().isEmpty && _attached == null)
                          ? null
                          : _submit,
                      child: composerState is AsyncLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.feedBtnPost, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          feedAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SocialCard(
              child: Text(formatError(e), style: TextStyle(color: palette.dangerBtnBg)),
            ),
            data: (posts) => posts.isEmpty
                ? SocialEmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: l10n.feedEmptyTitle,
                    subtitle: l10n.feedEmptySubtitle,
                  )
                : Column(
                    children: [
                      for (final p in posts) _PostCard(post: p),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedScopeTabs extends ConsumerWidget {
  final FeedScope scope;
  final DmToolColors palette;
  const _FeedScopeTabs({required this.scope, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final items = <(FeedScope, String)>[
      (FeedScope.all, l10n.feedScopeAll),
      (FeedScope.following, l10n.feedScopeFollowing),
      (FeedScope.discover, l10n.feedScopeDiscover),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((t) {
          final isActive = t.$1 == scope;
          return InkWell(
            borderRadius: palette.br,
            onTap: () =>
                ref.read(feedScopeProvider.notifier).state = t.$1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? palette.featureCardAccent : Colors.transparent,
                borderRadius: palette.br,
                border: Border.all(
                  color: isActive ? palette.featureCardAccent : palette.featureCardBorder,
                ),
              ),
              child: Text(
                t.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : palette.tabText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Discover body (inline; eski DiscoverTab'ın basitleştirilmiş hali) ──

class _DiscoverBody extends ConsumerStatefulWidget {
  const _DiscoverBody();

  @override
  ConsumerState<_DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends ConsumerState<_DiscoverBody> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(discoverSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final peopleAsync = ref.watch(discoverPeopleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => ref.read(discoverSearchQueryProvider.notifier).state = v.trim(),
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
                for (final p in people) _DiscoverUserTile(profile: p),
              ],
            );
          },
        ),
      ],
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
                      style: TextStyle(fontSize: 11, color: palette.tabText),
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
                  foregroundColor: isFollowing ? palette.tabText : Colors.white,
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

// ── Listing picker dialog ───────────────────────────────────────────

class _ListingPickerDialog extends StatefulWidget {
  final List<MarketplaceListing> marketplaceItems;
  final List<GameListing> gameItems;
  const _ListingPickerDialog({required this.marketplaceItems, required this.gameItems});

  @override
  State<_ListingPickerDialog> createState() => _ListingPickerDialogState();
}

class _ListingPickerDialogState extends State<_ListingPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MarketplaceListing> get _filteredMarketplace => _query.isEmpty
      ? widget.marketplaceItems
      : widget.marketplaceItems.where((l) => l.title.toLowerCase().contains(_query)).toList();

  List<GameListing> get _filteredGame => _query.isEmpty
      ? widget.gameItems
      : widget.gameItems.where((l) => l.title.toLowerCase().contains(_query)).toList();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final mItems = _filteredMarketplace;
    final gItems = _filteredGame;
    final empty = mItems.isEmpty && gItems.isEmpty;

    return Dialog(
      backgroundColor: palette.canvasBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.feedComposerAttachListing,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.feedPickerSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: palette.featureCardBg,
                  border: OutlineInputBorder(
                    borderRadius: palette.br,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: empty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.feedPickerEmpty,
                          style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (mItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              l10n.feedPickerMarketplaceSection,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.sidebarLabelSecondary,
                              ),
                            ),
                          ),
                          for (final item in mItems)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                iconForListingType(item.itemType),
                                size: 20,
                                color: palette.featureCardAccent,
                              ),
                              title: Text(item.title, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(item.itemType, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                              onTap: () => Navigator.pop(context, AttachedMarketplace(item)),
                            ),
                        ],
                        if (gItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              l10n.feedPickerGameListingSection,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.sidebarLabelSecondary,
                              ),
                            ),
                          ),
                          for (final item in gItems)
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.groups_outlined, size: 20, color: palette.featureCardAccent),
                              title: Text(item.title, style: const TextStyle(fontSize: 13)),
                              subtitle: item.system != null
                                  ? Text(item.system!, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary))
                                  : null,
                              onTap: () => Navigator.pop(context, AttachedGameListing(item)),
                            ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final override = ref.watch(postLikeOverrideProvider(post.id));
    final liked = override?.likedByMe ?? post.likedByMe;
    final likeCount = override?.likeCount ?? post.likeCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/profile/${post.authorId}'),
                child: ProfileAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  fallbackText: post.authorUsername ?? '?',
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${post.authorUsername ?? 'unknown'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().add_Hm().format(post.createdAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.body!,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: palette.tabText),
            ),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: palette.cbr,
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],
          if (post.marketplaceItemId != null && post.marketplaceItemTitle != null) ...[
            const SizedBox(height: 12),
            ListingBannerCard.compact(
              title: post.marketplaceItemTitle!,
              itemType: post.marketplaceItemType ?? 'world',
              onTap: () async {
                final listings = await ref
                    .read(marketplaceListingsRemoteDsProvider)
                    .fetchListingsByIds([post.marketplaceItemId!]);
                if (!context.mounted || listings.isEmpty) return;
                MarketplacePreviewDialog.show(context, listing: listings.first);
              },
            ),
          ],
          if (post.gameListingId != null && post.gameListingTitle != null) ...[
            const SizedBox(height: 12),
            ListingBannerCard.compact(
              title: post.gameListingTitle!,
              itemType: 'gameListing',
              system: post.gameListingSystem,
              onTap: () async {
                final listing = await ref
                    .read(gameListingsRemoteDsProvider)
                    .fetchById(post.gameListingId!);
                if (!context.mounted || listing == null) return;
                ApplyListingDialog.show(context, listing: listing);
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => ref
                    .read(postLikeProvider.notifier)
                    .toggle(post.id, currentPost: post),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: liked ? palette.dangerBtnBg : palette.sidebarLabelSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likeCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: liked ? palette.dangerBtnBg : palette.sidebarLabelSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

