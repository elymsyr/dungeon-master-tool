import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/marketplace_listing_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/utils/screen_type.dart';
import '../../../core/utils/world_languages.dart';
import '../../../data/datasources/remote/posts_remote_ds.dart' show FeedScope;
import '../../../domain/entities/game_listing.dart';
import '../../../domain/entities/marketplace_listing.dart';
import '../../../domain/entities/post.dart';
import '../../dialogs/apply_listing_dialog.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

IconData _listingTypeIcon(String itemType) => switch (itemType) {
      'world' => Icons.public,
      'template' => Icons.description_outlined,
      'package' => Icons.inventory_2_outlined,
      _ => Icons.folder_outlined,
    };

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

    if (scope == FeedScope.gameLists) {
      return RefreshIndicator(
        onRefresh: () async {
          invalidateCachePrefix('gameListings:');
          ref.invalidate(openGameListingsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
          children: [
            _FeedScopeTabs(scope: scope, palette: palette),
            const SizedBox(height: 16),
            const _GameListingFilterBar(),
            const SizedBox(height: 16),
            const _FeedGameListings(),
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
                            AttachedMarketplace(listing: final l) => _listingTypeIcon(l.itemType),
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
      (FeedScope.gameLists, l10n.feedScopeGameLists),
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
                              leading: Icon(_listingTypeIcon(item.itemType), size: 20, color: palette.featureCardAccent),
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
            InkWell(
              borderRadius: palette.cbr,
              onTap: () async {
                final listings = await ref.read(marketplaceListingsRemoteDsProvider).fetchListingsByIds([post.marketplaceItemId!]);
                if (!context.mounted || listings.isEmpty) return;
                MarketplacePreviewDialog.show(context, listing: listings.first);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: palette.cbr,
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent.withValues(alpha: 0.12),
                        borderRadius: palette.cbr,
                      ),
                      child: Icon(
                        _listingTypeIcon(post.marketplaceItemType ?? ''),
                        size: 18,
                        color: palette.featureCardAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        post.marketplaceItemTitle!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: palette.sidebarLabelSecondary),
                  ],
                ),
              ),
            ),
          ],
          if (post.gameListingId != null && post.gameListingTitle != null) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: palette.cbr,
              onTap: () async {
                final listing = await ref.read(gameListingsRemoteDsProvider).fetchById(post.gameListingId!);
                if (!context.mounted || listing == null) return;
                ApplyListingDialog.show(context, listing: listing);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: palette.cbr,
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent.withValues(alpha: 0.12),
                        borderRadius: palette.cbr,
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.gameListingTitle!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.tabActiveText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post.gameListingSystem != null)
                            Text(
                              post.gameListingSystem!,
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.sidebarLabelSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: palette.sidebarLabelSecondary),
                  ],
                ),
              ),
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

class _GameListingFilterBar extends ConsumerStatefulWidget {
  const _GameListingFilterBar();

  @override
  ConsumerState<_GameListingFilterBar> createState() => _GameListingFilterBarState();
}

class _GameListingFilterBarState extends ConsumerState<_GameListingFilterBar> {
  late final TextEditingController _systemCtrl;
  late final TextEditingController _tagCtrl;

  @override
  void initState() {
    super.initState();
    final f = ref.read(gameListingFiltersProvider);
    _systemCtrl = TextEditingController(text: f.system ?? '');
    _tagCtrl = TextEditingController(text: f.tag ?? '');
  }

  @override
  void dispose() {
    _systemCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final filters = ref.watch(gameListingFiltersProvider);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: filters.gameLanguage,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.listingFilterLanguage,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.marketplaceFilterAny, style: const TextStyle(fontSize: 12)),
                  ),
                  ...worldLanguages.map((lang) => DropdownMenuItem(
                        value: lang.code,
                        child: Text(lang.native,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) {
                  ref.read(gameListingFiltersProvider.notifier).state =
                      filters.copyWith(gameLanguage: v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _systemCtrl,
                decoration: InputDecoration(
                  labelText: l10n.listingFilterSystem,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: const TextStyle(fontSize: 12),
                onSubmitted: (v) {
                  ref.read(gameListingFiltersProvider.notifier).state =
                      filters.copyWith(system: v.trim().isEmpty ? null : v.trim());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                decoration: InputDecoration(
                  labelText: l10n.listingFilterTag,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                style: const TextStyle(fontSize: 12),
                onSubmitted: (v) {
                  ref.read(gameListingFiltersProvider.notifier).state =
                      filters.copyWith(tag: v.trim().isEmpty ? null : v.trim().toLowerCase());
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: l10n.listingFilterClear,
              icon: Icon(Icons.filter_alt_off_outlined, size: 18, color: palette.sidebarLabelSecondary),
              onPressed: () {
                _systemCtrl.clear();
                _tagCtrl.clear();
                ref.read(gameListingFiltersProvider.notifier).state =
                    const GameListingFilters();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FeedGameListings extends ConsumerWidget {
  const _FeedGameListings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final listingsAsync = ref.watch(openGameListingsProvider);
    return listingsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SocialCard(
        child: Text(formatError(e), style: TextStyle(color: palette.dangerBtnBg, fontSize: 12)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SocialEmptyState(
            icon: Icons.groups_outlined,
            title: l10n.feedGameListsEmpty,
          );
        }
        return Column(
          children: [
            for (final l in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeedListingCard(listing: l),
              ),
          ],
        );
      },
    );
  }
}

class _FeedListingCard extends ConsumerWidget {
  final GameListing listing;
  const _FeedListingCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hasApplied = ref.watch(hasAppliedProvider(listing.id)).value ?? false;
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => context.push('/profile/${listing.ownerId}'),
                      child: Text(
                        '@${listing.ownerUsername ?? 'unknown'}',
                        style: TextStyle(fontSize: 11, color: palette.featureCardAccent),
                      ),
                    ),
                  ],
                ),
              ),
              if (listing.system != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.featureCardAccent.withValues(alpha: 0.15),
                    borderRadius: palette.br,
                  ),
                  child: Text(
                    listing.system!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: palette.featureCardAccent,
                    ),
                  ),
                ),
            ],
          ),
          if (listing.description != null && listing.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              listing.description!,
              style: TextStyle(fontSize: 13, height: 1.4, color: palette.tabText),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (listing.gameLanguage != null || listing.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (listing.gameLanguage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.featureCardBg,
                      borderRadius: palette.cbr,
                      border: Border.all(color: palette.featureCardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language, size: 11, color: palette.sidebarLabelSecondary),
                        const SizedBox(width: 3),
                        Text(worldLanguageNative(listing.gameLanguage!),
                            style: TextStyle(fontSize: 10, color: palette.tabText)),
                      ],
                    ),
                  ),
                for (final t in listing.tags.take(5))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.featureCardBg,
                      borderRadius: palette.cbr,
                      border: Border.all(color: palette.featureCardBorder),
                    ),
                    child: Text('#$t',
                        style: TextStyle(fontSize: 10, color: palette.tabText)),
                  ),
              ],
            ),
          ],
          if (listing.seatsTotal != null || listing.schedule != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (listing.seatsTotal != null) ...[
                  Icon(Icons.event_seat_outlined,
                      size: 13, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 4),
                  Text('${listing.seatsFilled}/${listing.seatsTotal}',
                      style: TextStyle(
                          fontSize: 11,
                          color: palette.sidebarLabelSecondary)),
                  const SizedBox(width: 14),
                ],
                if (listing.schedule != null) ...[
                  Icon(Icons.schedule,
                      size: 13, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(listing.schedule!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: palette.sidebarLabelSecondary)),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: hasApplied
                ? TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check, size: 14),
                    label: Text(l10n.listingApplied,
                        style: const TextStyle(fontSize: 11)),
                  )
                : FilledButton(
                    onPressed: () async {
                      await ApplyListingDialog.show(context, listing: listing);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.featureCardAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: palette.br),
                    ),
                    child: Text(l10n.listingApply,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
    );
  }
}
