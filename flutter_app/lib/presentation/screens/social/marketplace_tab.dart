import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/world_languages.dart';
import '../../../domain/entities/marketplace_listing.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

/// Marketplace — tüm kullanıcıların public shared_items'ları. Tip, dil ve
/// etiket ile filtrelenebilir; sağ panelde takip edilen ve önerilen
/// oyuncular listelenir.
class MarketplaceTab extends ConsumerWidget {
  const MarketplaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Geniş ekranlarda (>= 860 px) sağ panel göster.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final feed = _MarketplaceFeed(palette: palette);
        if (!wide) return feed;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: feed),
            Container(
              width: 1,
              color: palette.featureCardBorder,
              margin: const EdgeInsets.symmetric(vertical: 20),
            ),
            Expanded(
              flex: 2,
              child: _PlayersPanel(palette: palette),
            ),
          ],
        );
      },
    );
  }
}

class _MarketplaceFeed extends ConsumerWidget {
  final DmToolColors palette;
  const _MarketplaceFeed({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final entries = ref.watch(marketplaceProvider);
    final filters = ref.watch(marketplaceFiltersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(marketplaceProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _FilterBar(filters: filters, palette: palette),
          const SizedBox(height: 12),
          _SecondaryFilterRow(filters: filters, palette: palette),
          const SizedBox(height: 20),
          entries.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SocialCard(
              child: Text('Error: $e',
                  style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SocialEmptyState(
                  icon: Icons.storefront_outlined,
                  title: l10n.marketplaceEmpty,
                  subtitle: l10n.marketplaceEmptySub,
                );
              }
              return Column(
                children: [
                  for (final e in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MarketplaceCard(listing: e),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final MarketplaceFilters filters;
  final DmToolColors palette;
  const _FilterBar({required this.filters, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final types = [
      ('all', l10n.filterAll),
      ('world', l10n.filterWorlds),
      ('template', l10n.filterTemplates),
      ('package', l10n.filterPackages),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((f) {
        final isActive = f.$1 == filters.type;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(marketplaceFiltersProvider.notifier).state =
                filters.copyWith(type: f.$1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? palette.featureCardAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? palette.featureCardAccent : palette.featureCardBorder,
              ),
            ),
            child: Text(
              f.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : palette.tabText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SecondaryFilterRow extends ConsumerStatefulWidget {
  final MarketplaceFilters filters;
  final DmToolColors palette;
  const _SecondaryFilterRow({required this.filters, required this.palette});

  @override
  ConsumerState<_SecondaryFilterRow> createState() => _SecondaryFilterRowState();
}

class _SecondaryFilterRowState extends ConsumerState<_SecondaryFilterRow> {
  late final TextEditingController _tagCtrl;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController(text: widget.filters.tag ?? '');
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = widget.palette;
    final filters = widget.filters;
    return Row(
      children: [
        // Language dropdown
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: filters.language,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.marketplaceLanguageFilter,
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
              ref.read(marketplaceFiltersProvider.notifier).state =
                  filters.copyWith(language: v);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Tag input
        Expanded(
          child: TextField(
            controller: _tagCtrl,
            decoration: InputDecoration(
              labelText: l10n.marketplaceTagFilter,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            style: const TextStyle(fontSize: 12),
            onSubmitted: (v) {
              ref.read(marketplaceFiltersProvider.notifier).state =
                  filters.copyWith(tag: v.trim().isEmpty ? null : v.trim().toLowerCase());
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: l10n.marketplaceFilterClear,
          icon: Icon(Icons.filter_alt_off_outlined, size: 18, color: palette.sidebarLabelSecondary),
          onPressed: () {
            _tagCtrl.clear();
            ref.read(marketplaceFiltersProvider.notifier).state =
                const MarketplaceFilters();
          },
        ),
      ],
    );
  }
}

class _MarketplaceCard extends ConsumerWidget {
  final MarketplaceListing listing;
  const _MarketplaceCard({required this.listing});

  IconData get _typeIcon => switch (listing.itemType) {
        'world' => Icons.public,
        'template' => Icons.description_outlined,
        'package' => Icons.inventory_2_outlined,
        _ => Icons.folder_outlined,
      };

  String _typeLabel(L10n l10n) => switch (listing.itemType) {
        'world' => l10n.itemTypeWorld,
        'template' => l10n.itemTypeTemplate,
        'package' => l10n.itemTypePackage,
        _ => l10n.itemTypeGeneric,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ownerName = listing.ownerUsername ?? 'unknown';

    return SocialCard(
      padding: const EdgeInsets.all(16),
      onTap: () => MarketplacePreviewDialog.show(context, listing: listing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.featureCardAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, size: 22, color: palette.featureCardAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel(l10n),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: palette.featureCardAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (listing.description != null && listing.description!.isNotEmpty) ...[
                  Text(
                    listing.description!,
                    style: TextStyle(fontSize: 12, color: palette.tabText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                ],
                if (listing.tags.isNotEmpty || listing.language != null) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (listing.language != null)
                        _InlineChip(
                          label: worldLanguageNative(listing.language!),
                          icon: Icons.language,
                          palette: palette,
                        ),
                      for (final tag in listing.tags.take(4))
                        _InlineChip(
                          label: '#$tag',
                          palette: palette,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/profile/${listing.ownerId}'),
                      child: Text(
                        '@$ownerName',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.featureCardAccent,
                        ),
                      ),
                    ),
                    Text(' · ', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                    Text(
                      DateFormat.yMMMd().format(listing.createdAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                    Text(' · ', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                    Icon(Icons.download_outlined, size: 12, color: palette.sidebarLabelSecondary),
                    const SizedBox(width: 2),
                    Text(
                      '${listing.downloadCount}',
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final DmToolColors palette;
  const _InlineChip({required this.label, this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10, color: palette.tabText),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right-side players panel

class _PlayersPanel extends ConsumerWidget {
  final DmToolColors palette;
  const _PlayersPanel({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final players = ref.watch(marketplacePlayersProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.marketplacePlayersHeader,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: players.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e',
                  style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    l10n.marketplacePlayersEmpty,
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _PlayerTile(profile: list[i], palette: palette),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  final UserProfile profile;
  final DmToolColors palette;
  const _PlayerTile({required this.profile, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final override = ref.watch(followOverrideProvider(profile.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(profile.userId));
    final isFollowing = override ?? isFollowingAsync.value ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/profile/${profile.userId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: profile.avatarUrl,
              fallbackText: profile.username,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName ?? profile.username,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${profile.username}',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 28,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
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

