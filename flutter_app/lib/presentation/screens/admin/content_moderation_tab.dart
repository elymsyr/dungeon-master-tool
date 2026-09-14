import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../theme/dm_tool_colors.dart';
import '../../l10n/app_localizations.dart';

/// Admin moderation — Posts / Marketplace / Game Listings arasında geçişli
/// tek sekme. Her satırda "Delete" butonu vardır ve silme başarılıysa
/// ilgili provider invalidate olur.
class ContentModerationTab extends ConsumerStatefulWidget {
  const ContentModerationTab({super.key});

  @override
  ConsumerState<ContentModerationTab> createState() =>
      _ContentModerationTabState();
}

enum _ContentKind { posts, marketplace, gameListings }

class _ContentModerationTabState extends ConsumerState<ContentModerationTab> {
  _ContentKind _kind = _ContentKind.posts;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_ContentKind>(
            segments: [
              ButtonSegment(
                value: _ContentKind.posts,
                icon: const Icon(Icons.forum_outlined, size: 16),
                label: Text(L10n.of(context)!.adminModPosts),
              ),
              ButtonSegment(
                value: _ContentKind.marketplace,
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: Text(L10n.of(context)!.adminModMarket),
              ),
              ButtonSegment(
                value: _ContentKind.gameListings,
                icon: const Icon(Icons.casino_outlined, size: 16),
                label: Text(L10n.of(context)!.adminModGames),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildList(palette)),
        ],
      ),
    );
  }

  Widget _buildList(DmToolColors palette) {
    switch (_kind) {
      case _ContentKind.posts:
        return _PostsList(palette: palette);
      case _ContentKind.marketplace:
        return const _MarketplaceList();
      case _ContentKind.gameListings:
        return _GameListingsList(palette: palette);
    }
  }
}

class _PostsList extends ConsumerWidget {
  const _PostsList({required this.palette});
  final DmToolColors palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAllPostsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(L10n.of(context)!.adminNoPosts,
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminAllPostsProvider),
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _PostCard(row: rows[i]),
          ),
        );
      },
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.row});
  final AdminPostRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row.authorName} · ${formatRelative(row.createdAt)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.sidebarLabelSecondary)),
                const SizedBox(height: 4),
                Text(
                  (row.body ?? '').trim().isEmpty
                      ? (row.imageUrl != null ? '[image]' : '(empty)')
                      : row.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 13, color: palette.tabActiveText),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: palette.dangerBtnBg),
            tooltip: L10n.of(context)!.adminDeletePost,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.deletePostTitle),
        content: Text(L10n.of(context)!.adminDeletePostBody(row.body ?? L10n.of(context)!.adminImagePost),
            maxLines: 6, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminUsersDataSourceProvider).adminDeletePost(row.id);
      ref.invalidate(adminAllPostsProvider);
      ref.invalidate(adminAuditLogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminPostDeleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.worldsDeleteFailed('$e'))));
      }
    }
  }
}

class _MarketplaceList extends ConsumerWidget {
  const _MarketplaceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final async = ref.watch(adminAllMarketplaceListingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(L10n.of(context)!.adminNoMarketListings,
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminAllMarketplaceListingsProvider),
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _MarketplaceCard(row: rows[i]),
          ),
        );
      },
    );
  }
}

class _MarketplaceCard extends ConsumerWidget {
  const _MarketplaceCard({required this.row});
  final AdminMarketplaceListingRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Row(
        children: [
          Icon(_iconForType(row.itemType),
              size: 20, color: palette.featureCardAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText)),
                const SizedBox(height: 2),
                Text(
                  '${row.itemType} · ${row.ownerName} · ${formatBytes(row.sizeBytes)} · ${formatRelative(row.createdAt)}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: palette.dangerBtnBg),
            tooltip: L10n.of(context)!.listingDeleteAction,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'world':
        return Icons.public;
      case 'template':
        return Icons.description_outlined;
      case 'package':
        return Icons.inventory_2_outlined;
      case 'character':
        return Icons.person_outline;
      default:
        return Icons.extension_outlined;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.adminDeleteListingTitle),
        content: Text(L10n.of(context)!.adminItemByOwner(row.title, row.ownerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(adminUsersDataSourceProvider)
          .adminDeleteMarketplaceListing(listingId: row.id);
      ref.invalidate(adminAllMarketplaceListingsProvider);
      ref.invalidate(adminAuditLogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminListingDeleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.worldsDeleteFailed('$e'))));
      }
    }
  }
}

class _GameListingsList extends ConsumerWidget {
  const _GameListingsList({required this.palette});
  final DmToolColors palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAllGameListingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(L10n.of(context)!.hubErrorGeneric('$e'))),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(L10n.of(context)!.adminNoGameListings,
                style: TextStyle(color: palette.sidebarLabelSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminAllGameListingsProvider),
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _GameListingCard(row: rows[i]),
          ),
        );
      },
    );
  }
}

class _GameListingCard extends ConsumerWidget {
  const _GameListingCard({required this.row});
  final AdminGameListingRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Row(
        children: [
          Icon(Icons.casino_outlined,
              size: 20, color: palette.featureCardAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText)),
                const SizedBox(height: 2),
                Text(
                  '${row.ownerName} · ${row.system ?? "?"} · ${row.isOpen ? "open" : "closed"} · ${formatRelative(row.createdAt)}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: palette.dangerBtnBg),
            tooltip: L10n.of(context)!.adminDeleteGameListing,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.adminDeleteGameListingTitle),
        content: Text(L10n.of(context)!.adminItemByOwner(row.title, row.ownerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.btnDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(adminUsersDataSourceProvider)
          .adminDeleteGameListing(row.id);
      ref.invalidate(adminAllGameListingsProvider);
      ref.invalidate(adminAuditLogProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.adminGameListingDeleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context)!.worldsDeleteFailed('$e'))));
      }
    }
  }
}
