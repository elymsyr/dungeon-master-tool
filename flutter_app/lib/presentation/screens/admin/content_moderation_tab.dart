import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../theme/dm_tool_colors.dart';

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
            segments: const [
              ButtonSegment(
                value: _ContentKind.posts,
                icon: Icon(Icons.forum_outlined, size: 16),
                label: Text('Posts'),
              ),
              ButtonSegment(
                value: _ContentKind.marketplace,
                icon: Icon(Icons.storefront_outlined, size: 16),
                label: Text('Market'),
              ),
              ButtonSegment(
                value: _ContentKind.gameListings,
                icon: Icon(Icons.casino_outlined, size: 16),
                label: Text('Games'),
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
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text('No posts.',
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
            tooltip: 'Delete post',
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
        title: const Text('Delete post?'),
        content: Text('This will remove the post permanently.\n\n"${row.body ?? '(image)'}"',
            maxLines: 6, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
            .showSnackBar(const SnackBar(content: Text('Post deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text('No marketplace listings.',
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
                Row(
                  children: [
                    Flexible(
                      child: Text(row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.tabActiveText)),
                    ),
                    if (row.isBuiltin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: palette.featureCardAccent.withValues(alpha: 0.18),
                          border: Border.all(
                              color: palette.featureCardAccent.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('BUILTIN',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ],
                ),
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
            icon: Icon(
              row.isBuiltin ? Icons.star : Icons.star_border,
              size: 18,
              color: row.isBuiltin
                  ? palette.featureCardAccent
                  : palette.sidebarLabelSecondary,
            ),
            tooltip: row.isBuiltin ? 'Unmark built-in' : 'Mark built-in',
            onPressed: () => _toggleBuiltin(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: palette.dangerBtnBg),
            tooltip: 'Delete listing',
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

  Future<void> _toggleBuiltin(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(adminUsersDataSourceProvider)
          .setListingBuiltin(row.id, !row.isBuiltin);
      ref.invalidate(adminAllMarketplaceListingsProvider);
      ref.invalidate(adminAuditLogProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('"${row.title}" by ${row.ownerName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
            .showSnackBar(const SnackBar(content: Text('Listing deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text('No game listings.',
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
            tooltip: 'Delete game listing',
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
        title: const Text('Delete game listing?'),
        content: Text('"${row.title}" by ${row.ownerName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
            .showSnackBar(const SnackBar(content: Text('Game listing deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
