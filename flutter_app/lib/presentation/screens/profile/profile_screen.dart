import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/marketplace_listing_provider.dart';
import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../domain/entities/game_listing.dart';
import '../../../domain/entities/marketplace_listing.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/create_listing_dialog.dart';
import '../../dialogs/follow_list_dialog.dart';
import '../../dialogs/listing_applicants_dialog.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../dialogs/profile_edit_dialog.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../l10n/app_localizations.dart';
import '../social/messages_tab.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/listing_banner_card.dart';
import '../../widgets/pill_tab_bar.dart';
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
        error: (e, st) => Center(child: Text(formatError(e))),
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

class _ProfileBody extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isMe;
  const _ProfileBody({required this.profile, required this.isMe});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  String _tab = 'posts';

  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    final l10n = L10n.of(context)!;
    final tabs = <PillTab<String>>[
      const PillTab(id: 'posts', icon: Icons.article_outlined, label: 'Posts'),
      const PillTab(id: 'items', icon: Icons.storefront_outlined, label: 'Items'),
      PillTab(
        id: 'listings',
        icon: Icons.groups_outlined,
        label: l10n.profileTabListings,
      ),
    ];
    final bar = PillTabBar<String>(
      tabs: tabs,
      currentTab: _tab,
      onTabChanged: (id) => setState(() => _tab = id),
      phone: phone,
      showBorderTop: phone,
      showBorderBottom: !phone,
    );
    final content = IndexedStack(
      index: switch (_tab) { 'items' => 1, 'listings' => 2, _ => 0 },
      children: [
        _UserPostsTab(userId: widget.profile.userId, isMe: widget.isMe),
        _UserItemsTab(userId: widget.profile.userId, isMe: widget.isMe),
        _UserListingsTab(userId: widget.profile.userId, isMe: widget.isMe),
      ],
    );
    return Column(
      children: phone
          ? [
              _ProfileHeader(profile: widget.profile, isMe: widget.isMe),
              Expanded(child: content),
              bar,
            ]
          : [
              _ProfileHeader(profile: widget.profile, isMe: widget.isMe),
              bar,
              Expanded(child: content),
            ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isMe;
  const _ProfileHeader({required this.profile, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                  _CountTile(
                    label: L10n.of(context)!.profileFollowersDialog,
                    value: profile.followers,
                    onTap: () => FollowListDialog.show(
                      context,
                      userId: profile.userId,
                      mode: FollowListMode.followers,
                    ),
                  ),
                  const SizedBox(width: 32),
                  _CountTile(
                    label: L10n.of(context)!.profileFollowingDialog,
                    value: profile.following,
                    onTap: () => FollowListDialog.show(
                      context,
                      userId: profile.userId,
                      mode: FollowListMode.following,
                    ),
                  ),
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
  final VoidCallback? onTap;
  const _CountTile({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: palette.br,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
            Text(label, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final following = ref.watch(isFollowingProvider(targetUserId));
    final override = ref.watch(followOverrideProvider(targetUserId));
    final toggleState = ref.watch(followToggleProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Optimistic: override varsa onu, yoksa async değeri kullan.
    final isFollowing = override ?? following.value ?? false;
    final busy = toggleState is AsyncLoading;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          icon: Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
          label: Text(isFollowing ? l10n.btnUnfollow : l10n.btnFollow),
          style: FilledButton.styleFrom(
            backgroundColor:
                isFollowing ? palette.featureCardBg : palette.featureCardAccent,
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
          label: Text(l10n.listingMessageApplicant),
          onPressed: () => _openDm(context, ref, targetUserId),
        ),
      ],
    );
  }

  Future<void> _openDm(BuildContext context, WidgetRef ref, String otherUserId) async {
    try {
      final conv = await ref.read(messagesRemoteDsProvider).openDirect(otherUserId);
      if (!context.mounted) return;
      final myUid = ref.read(authProvider)?.uid ?? '';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv, myUserId: myUid),
        ),
      );
      invalidateCache('conversations');
      ref.invalidate(myConversationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = L10n.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileDmError('$e'))),
      );
    }
  }
}

// ── Posts tab ──────────────────────────────────────────────────────────

class _UserPostsTab extends ConsumerWidget {
  final String userId;
  final bool isMe;
  const _UserPostsTab({required this.userId, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final postsAsync = ref.watch(userPostsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        invalidateCache('userPosts:$userId');
        ref.invalidate(userPostsProvider(userId));
      },
      child: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(formatError(e),
                  style: TextStyle(color: palette.dangerBtnBg)),
            ),
          ],
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.article_outlined,
                            size: 36, color: palette.sidebarLabelSecondary),
                        const SizedBox(height: 8),
                        Text('No posts yet',
                            style: TextStyle(
                                fontSize: 13, color: palette.sidebarLabelSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: posts.length,
            itemBuilder: (_, i) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _UserPostCard(
                  post: posts[i],
                  canDelete: isMe,
                  onDelete: () => _confirmAndDeletePost(context, ref, posts[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeletePost(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(postsRemoteDsProvider).delete(post.id);
      invalidateCache('userPosts:$userId');
      invalidateCachePrefix('feed:');
      ref.invalidate(userPostsProvider(userId));
      ref.invalidate(feedProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

class _UserPostCard extends StatelessWidget {
  final Post post;
  final bool canDelete;
  final VoidCallback onDelete;
  const _UserPostCard({
    required this.post,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMd().add_Hm().format(post.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ),
              if (canDelete)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: palette.dangerBtnBg),
                  ),
                ),
            ],
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.body!,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: palette.tabText),
            ),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: palette.cbr,
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_border,
                  size: 14, color: palette.sidebarLabelSecondary),
              const SizedBox(width: 4),
              Text('${post.likeCount}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Items tab — marketplace listings ───────────────────────────────────

class _UserItemsTab extends ConsumerWidget {
  final String userId;
  final bool isMe;
  const _UserItemsTab({required this.userId, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final itemsAsync = ref.watch(userMarketplaceListingsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        invalidateCache('userListings:$userId');
        ref.invalidate(userMarketplaceListingsProvider(userId));
      },
      child: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(formatError(e),
                  style: TextStyle(color: palette.dangerBtnBg)),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 36, color: palette.sidebarLabelSecondary),
                        const SizedBox(height: 8),
                        Text('No marketplace items yet',
                            style: TextStyle(
                                fontSize: 13, color: palette.sidebarLabelSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            itemBuilder: (_, i) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListingBannerCard.marketplace(
                    listing: items[i],
                    onTap: () => MarketplacePreviewDialog.show(
                      context,
                      listing: items[i],
                    ),
                    onDelete: isMe
                        ? () => _confirmAndDeleteListing(context, ref, items[i])
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteListing(
    BuildContext context,
    WidgetRef ref,
    MarketplaceListing listing,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${listing.title}"?'),
        content: const Text(
            'This will remove the current snapshot. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(marketplaceListingNotifierProvider.notifier)
          .deleteListing(listing: listing);
      invalidateCache('userListings:$userId');
      invalidateCachePrefix('marketplace:');
      ref.invalidate(userMarketplaceListingsProvider(userId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

// ── Listings tab — game listings ──────────────────────────────────────

class _UserListingsTab extends ConsumerWidget {
  final String userId;
  final bool isMe;
  const _UserListingsTab({required this.userId, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final listingsAsync = isMe
        ? ref.watch(myGameListingsProvider)
        : ref.watch(userGameListingsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        if (isMe) {
          invalidateCache('myGameListings');
          ref.invalidate(myGameListingsProvider);
        } else {
          invalidateCache('userGameListings:$userId');
          ref.invalidate(userGameListingsProvider(userId));
        }
      },
      child: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(formatError(e),
                  style: TextStyle(color: palette.dangerBtnBg)),
            ),
          ],
        ),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (isMe) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.btnNewListing),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.featureCardAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: palette.br),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => CreateListingDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.groups_outlined,
                            size: 36,
                            color: palette.sidebarLabelSecondary),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profileListingsEmpty,
                          style: TextStyle(
                              fontSize: 13,
                              color: palette.sidebarLabelSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final listing in items)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListingBannerCard.game(
                          listing: listing,
                          onTap: () => ListingApplicantsDialog.show(
                            context,
                            listing: listing,
                          ),
                          onEdit: isMe
                              ? () => CreateListingDialog.show(
                                    context,
                                    existing: listing,
                                  )
                              : null,
                          onClose: isMe
                              ? () => _close(context, ref, listing)
                              : null,
                          onDelete: isMe
                              ? () => _confirmAndDelete(context, ref, listing)
                              : null,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    GameListing listing,
  ) async {
    await ref.read(gameListingsRemoteDsProvider).close(listing.id);
    invalidateCache('myGameListings');
    invalidateCachePrefix('gameListings:');
    ref.invalidate(myGameListingsProvider);
    ref.invalidate(openGameListingsProvider);
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    GameListing listing,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${listing.title}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(gameListingsRemoteDsProvider).delete(listing.id);
      invalidateCache('myGameListings');
      invalidateCachePrefix('gameListings:');
      ref.invalidate(myGameListingsProvider);
      ref.invalidate(openGameListingsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}
