import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../../core/utils/world_languages.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/listing_banner_card.dart';
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

    final hPad = isPhone(context) ? 12.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () async {
        invalidateCachePrefix('marketplace:');
        ref.invalidate(marketplaceProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: [
          _FilterBar(filters: filters, palette: palette),
          const SizedBox(height: 8),
          _BuiltinFilterChip(filters: filters, palette: palette),
          const SizedBox(height: 12),
          _SecondaryFilterRow(filters: filters, palette: palette),
          const SizedBox(height: 20),
          entries.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SocialCard(
              child: Text(formatError(e),
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
                      child: ListingBannerCard.marketplace(
                        listing: e,
                        onTap: () => MarketplacePreviewDialog.show(
                          context,
                          listing: e,
                        ),
                      ),
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
      ('character', l10n.filterCharacters),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((f) {
        final isActive = f.$1 == filters.type;
        return InkWell(
          borderRadius: palette.br,
          onTap: () {
            ref.read(marketplaceFiltersProvider.notifier).state =
                filters.copyWith(type: f.$1);
          },
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

class _BuiltinFilterChip extends ConsumerWidget {
  final MarketplaceFilters filters;
  final DmToolColors palette;
  const _BuiltinFilterChip({required this.filters, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3 state: null (all) / true (builtin only) / false (user only).
    final options = <(bool?, IconData, String)>[
      (null, Icons.all_inclusive, 'All'),
      (true, Icons.star, 'Built-ins'),
      (false, Icons.people_outline, 'Community'),
    ];
    return Wrap(
      spacing: 6,
      children: options.map((o) {
        final isActive = o.$1 == filters.builtinOnly;
        return InkWell(
          borderRadius: palette.br,
          onTap: () {
            ref.read(marketplaceFiltersProvider.notifier).state =
                filters.copyWith(builtinOnly: o.$1);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive
                  ? palette.featureCardAccent.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? palette.featureCardAccent
                    : palette.featureCardBorder,
              ),
              borderRadius: palette.br,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(o.$2,
                    size: 14,
                    color: isActive
                        ? palette.featureCardAccent
                        : palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Text(
                  o.$3,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? palette.featureCardAccent
                        : palette.tabText,
                  ),
                ),
              ],
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
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(formatError(e),
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
      borderRadius: palette.cbr,
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
