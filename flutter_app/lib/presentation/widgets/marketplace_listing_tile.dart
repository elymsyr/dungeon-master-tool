import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/world_languages.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'listing_banner_card.dart' show iconForListingType, labelForListingType;
import 'metadata_list_tile.dart';

/// Renders a marketplace [MarketplaceListing] using the SAME widget the item
/// uses in its native hub list, so a published world/package/character looks
/// identical to how it appears in the Worlds/Packages/Characters tabs, and a
/// template matches the Templates tab row.
///
/// - world / package / character → [MetadataListTile] (topBanner), the exact
///   tile the hub tabs use. Cover comes from the listing's base64 blob.
/// - template → the Templates tab's plain icon row (no cover).
///
/// Marketplace-only metadata (owner handle, publish date, download count) is
/// folded into the subtitle line so it stays visible without breaking the
/// native visual. Soundpacks are NOT handled here — they render through the
/// shared `SoundpackCatalogView` in both surfaces already.
class MarketplaceListingTile extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback? onTap;

  /// Owner-only delete action. When non-null an overflow menu replaces the
  /// inert trailing slot.
  final VoidCallback? onDelete;

  const MarketplaceListingTile({
    super.key,
    required this.listing,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    if (listing.itemType == 'template') {
      return _TemplateRow(
        listing: listing,
        palette: palette,
        onTap: onTap,
        onDelete: onDelete,
      );
    }
    return _BannerTile(
      listing: listing,
      palette: palette,
      onTap: onTap,
      onDelete: onDelete,
    );
  }
}

/// Template (when present) / owner / date / download line shared by both
/// layouts. Mirrors how the native Worlds/Packages tabs surface the template
/// in the subtitle, with the marketplace owner/date/downloads appended.
String _metaLine(MarketplaceListing listing) {
  final owner = listing.ownerUsername ?? 'unknown';
  final date = DateFormat.yMMMd().format(listing.createdAt.toLocal());
  final template = listing.templateName;
  final prefix = (template != null && template.isNotEmpty) ? '$template · ' : '';
  return '$prefix@$owner · $date · ↓${listing.downloadCount}';
}

List<String> _tagList(MarketplaceListing listing) {
  return [
    if (listing.language != null) worldLanguageNative(listing.language!),
    ...listing.tags,
  ];
}

class _BannerTile extends StatelessWidget {
  final MarketplaceListing listing;
  final DmToolColors palette;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BannerTile({
    required this.listing,
    required this.palette,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return InkWell(
      borderRadius: palette.br,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: MetadataListTile(
          icon: iconForListingType(listing.itemType),
          name: listing.title,
          subtitle: _metaLine(listing),
          description: listing.description ?? '',
          tags: _tagList(listing),
          coverImagePath: '',
          coverImageB64: listing.coverImageB64,
          isSelected: false,
          palette: palette,
          layout: MetadataTileLayout.topBanner,
          trailingBadges: [
            _TypeBadge(
              label: labelForListingType(l10n, listing.itemType),
              palette: palette,
            ),
          ],
          // No per-item settings in the marketplace — owner overflow menu when
          // deletable, otherwise a "Get" button (opens the preview dialog).
          trailingControl: onDelete != null
              ? _OwnerMenu(onDelete: onDelete!)
              : _GetButton(onPressed: onTap),
          onSettings: () {},
        ),
      ),
    );
  }
}

/// Mirrors the Templates tab `_TemplateTile` row (icon + text, no cover) so a
/// published template looks the same in the marketplace.
class _TemplateRow extends StatelessWidget {
  final MarketplaceListing listing;
  final DmToolColors palette;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _TemplateRow({
    required this.listing,
    required this.palette,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tags = _tagList(listing);
    return InkWell(
      borderRadius: palette.br,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.description,
                color: palette.featureCardAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    listing.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _metaLine(listing),
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                  if ((listing.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      listing.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: tags
                          .take(5)
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: palette.sidebarFilterBg,
                                  borderRadius: palette.chr,
                                ),
                                child: Text(t,
                                    style: TextStyle(
                                        fontSize: 9, color: palette.tabText)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onDelete != null)
              _OwnerMenu(onDelete: onDelete!)
            else
              _GetButton(onPressed: onTap),
          ],
        ),
      ),
    );
  }
}

/// Compact "Get" action shown on browse cards (mirrors the soundpack catalog's
/// trailing Get button). Opens the preview dialog via the tile's [onPressed].
class _GetButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(l10n.marketplaceGet),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  const _TypeBadge({required this.label, required this.palette});

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

class _OwnerMenu extends StatelessWidget {
  final VoidCallback onDelete;
  const _OwnerMenu({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: 'Actions',
      onSelected: (v) {
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'delete', child: Text(l10n.listingDeleteAction)),
      ],
    );
  }
}
