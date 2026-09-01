import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/first_party_catalog_provider.dart';
import '../../../application/providers/follows_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../application/providers/soundpack_catalog_provider.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../../core/utils/world_languages.dart';
import '../../../domain/entities/user_profile.dart';
import '../../dialogs/marketplace_preview_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/banner_metrics.dart';
import '../../widgets/connection_error_view.dart';
import '../../widgets/marketplace_listing_tile.dart';
import '../../widgets/official_packages_catalog_view.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/soundpack_catalog_view.dart';
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

    // Soundpacks are a curated GitHub catalog, not Supabase listings — so this
    // type renders the catalog view and skips the listing feed + tag/language
    // filters (which don't apply).
    final isSoundpack = filters.type == 'soundpack';
    // The "All" tab merges the Supabase listing feed with the soundpack catalog
    // so soundpacks aren't hidden behind their dedicated tab.
    final isAll = filters.type == 'all';
    // "All" and "Packages" also surface the first-party (R2) official packages
    // catalog below the Supabase package listings — unless the user filtered
    // to "community only" via the content type filter.
    final isPackage = filters.type == 'package';
    final showOfficialPackages =
        (isAll || isPackage) && filters.contentType != 'community';
    // Same for the official world catalog under "All"/"Worlds".
    final showOfficialWorlds =
        (isAll || filters.type == 'world') && filters.contentType != 'community';

    final hPad = isPhone(context) ? 12.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () async {
        if (isSoundpack) {
          ref.invalidate(soundpackCatalogProvider);
          return;
        }
        if (isAll) ref.invalidate(soundpackCatalogProvider);
        if (showOfficialPackages || showOfficialWorlds) {
          ref.invalidate(firstPartyManifestProvider);
        }
        invalidateCachePrefix('marketplace:');
        ref.invalidate(marketplaceProvider);
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCardMaxWidth),
          child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: [
          _FilterBar(filters: filters, palette: palette),
          const SizedBox(height: 12),
          if (!isSoundpack) ...[
            _SecondaryFilterRow(filters: filters, palette: palette),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),
          if (isSoundpack)
            const SoundpackCatalogView()
          else
          entries.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => isOfflineError(e)
                ? ConnectionErrorView(
                    onRetry: () => ref.invalidate(marketplaceProvider))
                : SocialCard(
                    child: Text(formatError(e),
                        style: TextStyle(
                            fontSize: 12, color: palette.dangerBtnBg)),
                  ),
            data: (items) {
              if (items.isEmpty) {
                // In "All"/"Packages" the catalog below carries content — skip
                // the empty state.
                if (isAll || showOfficialPackages || showOfficialWorlds) {
                  return const SizedBox.shrink();
                }
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
                      child: MarketplaceListingTile(
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
          // Official (first-party) packages flow inline right after the
          // user-shared listings — same card look, no separate section.
          if (showOfficialPackages) const OfficialPackagesCatalogView(),
          if (showOfficialWorlds)
            OfficialPackagesCatalogView(
                provider: firstPartyWorldCatalogProvider),
          if (isAll) ...[
            const SizedBox(height: 8),
            const SoundpackCatalogView(),
          ],
        ],
          ),
        ),
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
      ('soundpack', l10n.filterSoundpacks),
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

class _SecondaryFilterRow extends ConsumerWidget {
  final MarketplaceFilters filters;
  final DmToolColors palette;
  const _SecondaryFilterRow({required this.filters, required this.palette});

  bool get _hasActiveFilters =>
      filters.contentType != 'all' ||
      filters.language != null ||
      filters.tag != null ||
      filters.showMature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    return Row(
      children: [
        InkWell(
          borderRadius: palette.br,
          onTap: () => _openFilterDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hasActiveFilters
                  ? palette.featureCardAccent.withValues(alpha: 0.1)
                  : palette.featureCardBg,
              borderRadius: palette.br,
              border: Border.all(
                color: _hasActiveFilters
                    ? palette.featureCardAccent.withValues(alpha: 0.4)
                    : palette.featureCardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 16, color: palette.tabActiveText),
                const SizedBox(width: 6),
                Text(
                  l10n.marketplaceFilterButton,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.tabActiveText,
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.featureCardAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _FilterDialog(
        filters: filters,
        onApply: (updated) {
          ref.read(marketplaceFiltersProvider.notifier).state = updated;
        },
        onClear: () {
          ref.read(marketplaceFiltersProvider.notifier).state =
              const MarketplaceFilters();
        },
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final MarketplaceFilters filters;
  final ValueChanged<MarketplaceFilters> onApply;
  final VoidCallback onClear;
  const _FilterDialog({
    required this.filters,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String? _language;
  late TextEditingController _tagCtrl;
  late bool _showMature;
  late String _contentType;

  @override
  void initState() {
    super.initState();
    _language = widget.filters.language;
    _tagCtrl = TextEditingController(text: widget.filters.tag ?? '');
    _showMature = widget.filters.showMature;
    _contentType = widget.filters.contentType;
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      title: Text(l10n.marketplaceFilterButton),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Content Type
            DropdownButtonFormField<String>(
              initialValue: _contentType,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.marketplaceContentTypeFilter,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(l10n.filterAll,
                      style: const TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'official',
                  child: Text(l10n.filterOfficial,
                      style: const TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'community',
                  child: Text(l10n.filterCommunity,
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _contentType = v ?? 'all'),
            ),
            const SizedBox(height: 12),
            // Language
            DropdownButtonFormField<String?>(
              initialValue: _language,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.marketplaceLanguageFilter,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.marketplaceFilterAny,
                      style: const TextStyle(fontSize: 12)),
                ),
                ...worldLanguages.map((lang) => DropdownMenuItem(
                      value: lang.code,
                      child: Text(lang.native,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() => _language = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagCtrl,
              decoration: InputDecoration(
                labelText: l10n.marketplaceTagFilter,
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _showMature = !_showMature),
              borderRadius: palette.br,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: _showMature,
                        onChanged: (v) => setState(() => _showMature = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: palette.tabText.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.marketplaceMatureFilter,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.tabActiveText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onClear();
            Navigator.pop(context);
          },
          child: Text(l10n.marketplaceFilterClear),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(MarketplaceFilters(
              type: widget.filters.type,
              contentType: _contentType,
              language: _language,
              tag: _tagCtrl.text.trim().isEmpty
                  ? null
                  : _tagCtrl.text.trim().toLowerCase(),
              showMature: _showMature,
            ));
            Navigator.pop(context);
          },
          child: Text(l10n.marketplaceFilterApply),
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
    final isFollowing = override ?? isFollowingAsync.valueOrNull ?? false;

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
