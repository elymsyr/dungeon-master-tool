import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../../core/utils/world_languages.dart';
import '../../dialogs/apply_listing_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/listing_banner_card.dart';
import 'social_shell.dart';

class GameListingsTab extends ConsumerWidget {
  const GameListingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hPad = isPhone(context) ? 12.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () async {
        invalidateCachePrefix('gameListings:');
        ref.invalidate(openGameListingsProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: const [
          _GameListingFilterBar(),
          SizedBox(height: 16),
          _FeedGameListings(),
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
                child: ListingBannerCard.game(
                  listing: l,
                  onTap: () => ApplyListingDialog.show(context, listing: l),
                ),
              ),
          ],
        );
      },
    );
  }
}
