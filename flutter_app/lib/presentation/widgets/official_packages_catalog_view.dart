import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/first_party_catalog_provider.dart';
import '../../data/services/first_party_catalog_service.dart'
    show officialBannerUrl;
import '../../domain/entities/catalog/catalog_entry.dart';
import '../dialogs/official_package_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'listing_banner_card.dart'
    show iconForListingType, labelForListingType;
import 'metadata_list_tile.dart';

/// Renders the first-party "Official" package catalog as a column of cards, each
/// with an Install / Installing… / Installed action. Embeddable inside an
/// existing scroll view (returns a [Column], not its own scrollable) — folded
/// into the Marketplace feed alongside the Supabase listings + soundpacks.
class OfficialPackagesCatalogView extends ConsumerWidget {
  const OfficialPackagesCatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final catalog = ref.watch(firstPartyCatalogProvider);

    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      // The service degrades to the bundled catalog when offline, so an error
      // here is genuinely unexpected (e.g. a malformed manifest) — show it
      // quietly rather than blocking the rest of the feed.
      error: (e, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        // No section header — official cards flow inline in the same feed as
        // the user-shared listings, looking identical aside from the verified
        // "Official" line.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OfficialPackageCard(entry: entry, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _OfficialPackageCard extends StatelessWidget {
  final CatalogEntry entry;
  final DmToolColors palette;
  const _OfficialPackageCard({required this.entry, required this.palette});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    void open() => OfficialPackageDialog.show(context, entry: entry);

    // Same shell as the user-shared marketplace card (`_BannerTile`) so official
    // packages look identical to community content — the only difference is the
    // verified "Official" line instead of an `@username`. Tapping the card (or
    // its Get button) opens the details + install dialog, like user listings.
    return InkWell(
      borderRadius: palette.br,
      onTap: open,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: MetadataListTile(
          icon: iconForListingType(entry.itemType),
          name: entry.title.isEmpty ? entry.slug : entry.title,
          subtitle: _meta(l10n),
          subtitleLeading: Icon(Icons.verified,
              size: 12, color: palette.featureCardAccent),
          description: '',
          tags: const [],
          coverImagePath: '',
          coverNetworkUrl: officialBannerUrl(entry.slug),
          isSelected: false,
          palette: palette,
          layout: MetadataTileLayout.topBanner,
          topLeftOverlay: [
            _OfficialTypeBadge(
              label: labelForListingType(l10n, entry.itemType),
              palette: palette,
            ),
          ],
          trailingControl: _GetButton(onPressed: open, palette: palette),
          onSettings: () {},
        ),
      ),
    );
  }

  /// Meta line mirroring the user card order — template name, then "Official"
  /// (next to the verified checkmark) replacing `@owner`, then license + entity
  /// count. Publisher/username intentionally omitted.
  String _meta(L10n l10n) {
    // No "Official" text — the verified checkmark (subtitleLeading) already
    // marks the card as official.
    final parts = <String>[];
    if (entry.gameSystem.isNotEmpty) parts.add(entry.gameSystem);
    if (entry.license.isNotEmpty) parts.add(entry.license);
    if (entry.totalEntities > 0) {
      parts.add(l10n.packageEntityCount(entry.totalEntities));
    }
    return parts.join(' · ');
  }
}

/// Compact "Get" action mirroring the user-shared card's `_GetButton`
/// (marketplace_listing_tile.dart) — opens the official details dialog.
class _GetButton extends StatelessWidget {
  final VoidCallback onPressed;
  final DmToolColors palette;
  const _GetButton({required this.onPressed, required this.palette});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.featureCardAccent,
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(l10n.marketplaceGet),
    );
  }
}

/// Small type pill matching the user-shared card's `_TypeBadge`
/// (marketplace_listing_tile.dart) so official cards carry the same header tag.
class _OfficialTypeBadge extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  const _OfficialTypeBadge({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.15),
        borderRadius: palette.br,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.featureCardAccent,
        ),
      ),
    );
  }
}
