import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/profile_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../domain/entities/game_listing.dart';
import '../../../domain/entities/user_profile.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

class PlayersTab extends ConsumerStatefulWidget {
  const PlayersTab({super.key});
  @override
  ConsumerState<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends ConsumerState<PlayersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateListingDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final systemCtrl = TextEditingController(text: 'D&D 5e');
    final seatsCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Game Listing'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(controller: systemCtrl, decoration: const InputDecoration(labelText: 'System')),
                const SizedBox(height: 10),
                TextField(controller: seatsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats total')),
                const SizedBox(height: 10),
                TextField(controller: scheduleCtrl, decoration: const InputDecoration(labelText: 'Schedule')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().length < 3) return;
              await ref.read(gameListingComposerProvider.notifier).create(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    system: systemCtrl.text.trim().isEmpty ? null : systemCtrl.text.trim(),
                    seatsTotal: int.tryParse(seatsCtrl.text.trim()),
                    schedule: scheduleCtrl.text.trim().isEmpty ? null : scheduleCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Post listing'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final listingsAsync = ref.watch(openGameListingsProvider);
    final searchAsync = _query.length >= 2
        ? ref.watch(profileSearchProvider(_query))
        : const AsyncValue<List<UserProfile>>.data(<UserProfile>[]);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(openGameListingsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            palette: palette,
          ),
          if (_query.length >= 2) ...[
            const SizedBox(height: 12),
            searchAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e', style: TextStyle(color: palette.dangerBtnBg)),
              data: (results) => results.isEmpty
                  ? SocialCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('No matches for "$_query"',
                          style: TextStyle(color: palette.sidebarLabelSecondary, fontSize: 12)),
                    )
                  : SocialCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < results.length; i++) ...[
                            _UserResultTile(profile: results[i]),
                            if (i < results.length - 1)
                              Divider(height: 1, color: palette.featureCardBorder),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Game listings',
            actionLabel: 'New listing',
            onAction: _showCreateListingDialog,
            palette: palette,
          ),
          const SizedBox(height: 12),
          listingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SocialCard(
              child: Text('Error: $e', style: TextStyle(color: palette.dangerBtnBg)),
            ),
            data: (items) => items.isEmpty
                ? const SocialEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No open listings yet',
                    subtitle: "Post a listing to find players for your campaign.",
                  )
                : Column(
                    children: [
                      for (final l in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ListingCard(listing: l),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final DmToolColors palette;
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 18, color: palette.sidebarLabelSecondary),
          hintText: 'Search players by username',
          hintStyle: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DmToolColors palette;
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.tabActiveText),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(actionLabel!),
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: palette.featureCardAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _UserResultTile extends StatelessWidget {
  final UserProfile profile;
  const _UserResultTile({required this.profile});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return ListTile(
      leading: ProfileAvatar(avatarUrl: profile.avatarUrl, fallbackText: profile.username, size: 36),
      title: Text(profile.displayName ?? profile.username,
          style: TextStyle(fontSize: 13, color: palette.tabActiveText)),
      subtitle: Text('@${profile.username}',
          style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
      trailing: Icon(Icons.chevron_right, color: palette.sidebarLabelSecondary),
      onTap: () => context.push('/profile/${profile.userId}'),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final GameListing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.tabActiveText),
                ),
              ),
              if (listing.system != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.featureCardAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(listing.system!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: palette.featureCardAccent,
                      )),
                ),
            ],
          ),
          if (listing.description != null && listing.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(listing.description!,
                style: TextStyle(fontSize: 13, height: 1.4, color: palette.tabText)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (listing.seatsTotal != null) ...[
                Icon(Icons.event_seat_outlined, size: 13, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Text('${listing.seatsFilled}/${listing.seatsTotal}',
                    style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                const SizedBox(width: 14),
              ],
              if (listing.schedule != null) ...[
                Icon(Icons.schedule, size: 13, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(listing.schedule!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                ),
                const SizedBox(width: 14),
              ],
              const Spacer(),
              Text('@${listing.ownerUsername ?? 'unknown'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.featureCardAccent,
                  )),
              Text(' · ',
                  style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
              Text(DateFormat.yMMMd().format(listing.createdAt.toLocal()),
                  style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
