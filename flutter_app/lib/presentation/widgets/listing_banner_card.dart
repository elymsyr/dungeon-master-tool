import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/world_languages.dart';
import '../../domain/entities/game_listing.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Hub `MetadataListTile.topBanner` desenine paralel — marketplace ve game
/// listings kartları artık her yerde aynı banner yapıyı kullanır.
///
/// Üç varyant:
///   - `.marketplace(...)`  full listing + edit/delete aksiyonları
///   - `.game(...)`         full game listing + owner aksiyonları
///   - `.compact(...)`      post attachment için kompakt satır
class ListingBannerCard extends StatelessWidget {
  /// `full` mod için:
  final MarketplaceListing? marketplaceListing;
  final GameListing? gameListing;

  /// Her iki varyant için ortak aksiyonlar.
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Sadece game listing owner akışları için:
  final VoidCallback? onEdit;
  final VoidCallback? onClose;

  /// Compact mod alanları.
  final String? compactTitle;
  final String? compactItemType; // 'world' | 'template' | 'package' | 'character' | 'gameListing'
  final String? compactSystem;

  final _Variant _variant;

  const ListingBannerCard.marketplace({
    super.key,
    required MarketplaceListing listing,
    this.onTap,
    this.onDelete,
  })  : _variant = _Variant.marketplaceFull,
        marketplaceListing = listing,
        gameListing = null,
        onEdit = null,
        onClose = null,
        compactTitle = null,
        compactItemType = null,
        compactSystem = null;

  const ListingBannerCard.game({
    super.key,
    required GameListing listing,
    this.onTap,
    this.onEdit,
    this.onClose,
    this.onDelete,
  })  : _variant = _Variant.gameFull,
        marketplaceListing = null,
        gameListing = listing,
        compactTitle = null,
        compactItemType = null,
        compactSystem = null;

  const ListingBannerCard.compact({
    super.key,
    required String title,
    required String itemType,
    String? system,
    this.onTap,
  })  : _variant = _Variant.compact,
        marketplaceListing = null,
        gameListing = null,
        onEdit = null,
        onDelete = null,
        onClose = null,
        compactTitle = title,
        compactItemType = itemType,
        compactSystem = system;

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _Variant.marketplaceFull => _MarketplaceFullCard(
          listing: marketplaceListing!,
          onTap: onTap,
          onDelete: onDelete,
        ),
      _Variant.gameFull => _GameFullCard(
          listing: gameListing!,
          onTap: onTap,
          onEdit: onEdit,
          onClose: onClose,
          onDelete: onDelete,
        ),
      _Variant.compact => _CompactAttachmentCard(
          title: compactTitle!,
          itemType: compactItemType!,
          system: compactSystem,
          onTap: onTap,
        ),
    };
  }
}

enum _Variant { marketplaceFull, gameFull, compact }

// ── Shared helpers ──────────────────────────────────────────────────

IconData iconForListingType(String itemType) => switch (itemType) {
      'world' => Icons.public,
      'template' => Icons.description_outlined,
      'package' => Icons.inventory_2_outlined,
      'character' => Icons.person,
      'gameListing' => Icons.groups_outlined,
      _ => Icons.folder_outlined,
    };

String labelForListingType(L10n l10n, String itemType) => switch (itemType) {
      'world' => l10n.itemTypeWorld,
      'template' => l10n.itemTypeTemplate,
      'package' => l10n.itemTypePackage,
      'character' => l10n.itemTypeCharacter,
      _ => l10n.itemTypeGeneric,
    };

Widget _bannerCover({
  required IconData icon,
  required DmToolColors palette,
  String? coverImageB64,
}) {
  Uint8List? bytes;
  if (coverImageB64 != null && coverImageB64.isNotEmpty) {
    try {
      bytes = base64Decode(coverImageB64);
    } catch (_) {
      bytes = null;
    }
  }
  return Container(
    height: 120,
    decoration: BoxDecoration(
      color: palette.featureCardBg,
      border: Border(bottom: BorderSide(color: palette.featureCardBorder)),
    ),
    alignment: Alignment.center,
    clipBehavior: Clip.antiAlias,
    child: bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 120,
            errorBuilder: (_, _, _) => Icon(
              icon,
              size: 48,
              color: palette.featureCardAccent,
            ),
          )
        : Icon(
            icon,
            size: 48,
            color: palette.featureCardAccent,
          ),
  );
}

Widget _chip({
  required String label,
  IconData? icon,
  required DmToolColors palette,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: palette.featureCardBg,
      borderRadius: palette.cbr,
      border: Border.all(color: palette.featureCardBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 3),
        ],
        Text(label, style: TextStyle(fontSize: 10, color: palette.tabText)),
      ],
    ),
  );
}

Widget _outerShell({
  required DmToolColors palette,
  required VoidCallback? onTap,
  required Widget child,
}) {
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: palette.featureCardBg,
      borderRadius: palette.cbr,
      border: Border.all(color: palette.featureCardBorder),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

// ── Marketplace full card ──────────────────────────────────────────

class _MarketplaceFullCard extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _MarketplaceFullCard({
    required this.listing,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ownerName = listing.ownerUsername ?? 'unknown';
    final hasActions = onDelete != null;

    return _outerShell(
      palette: palette,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bannerCover(
            icon: iconForListingType(listing.itemType),
            palette: palette,
            coverImageB64: listing.coverImageB64,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        borderRadius: palette.br,
                      ),
                      child: Text(
                        labelForListingType(l10n, listing.itemType),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: palette.featureCardAccent,
                        ),
                      ),
                    ),
                    if (hasActions) ...[
                      const SizedBox(width: 4),
                      _OwnerMenuButton(onDelete: onDelete),
                    ],
                  ],
                ),
                if (listing.description != null && listing.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      listing.description!,
                      style: TextStyle(fontSize: 12, color: palette.tabText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: () =>
                                  context.push('/profile/${listing.ownerId}'),
                              child: Text(
                                '@$ownerName',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.featureCardAccent,
                                ),
                              ),
                            ),
                          ),
                          Text(' · ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                          Text(
                            DateFormat.yMMMd()
                                .format(listing.createdAt.toLocal()),
                            style: TextStyle(
                                fontSize: 11,
                                color: palette.sidebarLabelSecondary),
                          ),
                          Text(' · ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                          Icon(Icons.download_outlined,
                              size: 12, color: palette.sidebarLabelSecondary),
                          const SizedBox(width: 2),
                          Text(
                            '${listing.downloadCount}',
                            style: TextStyle(
                                fontSize: 11,
                                color: palette.sidebarLabelSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (listing.language != null || listing.tags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (listing.language != null)
                                _chip(
                                  label: worldLanguageNative(listing.language!),
                                  icon: Icons.language,
                                  palette: palette,
                                ),
                              for (final tag in listing.tags.take(3))
                                _chip(label: '#$tag', palette: palette),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Game listing full card ──────────────────────────────────────────

class _GameFullCard extends StatelessWidget {
  final GameListing listing;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;

  const _GameFullCard({
    required this.listing,
    this.onTap,
    this.onEdit,
    this.onClose,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final hasActions = onEdit != null || onClose != null || onDelete != null;
    final ownerName = listing.ownerUsername ?? 'unknown';

    return _outerShell(
      palette: palette,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                if (!listing.isOpen)
                  _chip(
                    label: l10n.listingClosedBadge,
                    palette: palette,
                  ),
                if (hasActions) ...[
                  const SizedBox(width: 4),
                  _OwnerMenuButton(
                    onEdit: onEdit,
                    onClose: listing.isOpen ? onClose : null,
                    onDelete: onDelete,
                  ),
                ],
              ],
            ),
                if (listing.description != null && listing.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      listing.description!,
                      style: TextStyle(fontSize: 12, color: palette.tabText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (listing.gameLanguage != null || listing.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (listing.gameLanguage != null)
                        _chip(
                          label: worldLanguageNative(listing.gameLanguage!),
                          icon: Icons.language,
                          palette: palette,
                        ),
                      for (final t in listing.tags.take(4))
                        _chip(label: '#$t', palette: palette),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
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
                    const SizedBox(width: 10),
                    if (listing.seatsTotal != null) ...[
                      Icon(Icons.event_seat_outlined,
                          size: 13, color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.seatsFilled}/${listing.seatsTotal}',
                        style: TextStyle(
                            fontSize: 11, color: palette.sidebarLabelSecondary),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (listing.schedule != null) ...[
                      Icon(Icons.schedule,
                          size: 13, color: palette.sidebarLabelSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          listing.schedule!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: palette.sidebarLabelSecondary),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      DateFormat.yMMMd().format(listing.createdAt.toLocal()),
                      style: TextStyle(
                          fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

// ── Compact attachment (post body) ──────────────────────────────────

class _CompactAttachmentCard extends StatelessWidget {
  final String title;
  final String itemType;
  final String? system;
  final VoidCallback? onTap;

  const _CompactAttachmentCard({
    required this.title,
    required this.itemType,
    this.system,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return InkWell(
      borderRadius: palette.cbr,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.cbr,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.featureCardAccent.withValues(alpha: 0.12),
                borderRadius: palette.cbr,
              ),
              child: Icon(
                iconForListingType(itemType),
                size: 18,
                color: palette.featureCardAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (system != null && system!.isNotEmpty)
                    Text(
                      system!,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: palette.sidebarLabelSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Owner kebab menu ────────────────────────────────────────────────

class _OwnerMenuButton extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;

  const _OwnerMenuButton({this.onEdit, this.onClose, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: 'Actions',
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit?.call();
          case 'close':
            onClose?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(value: 'edit', child: Text(l10n.btnEdit)),
        if (onClose != null)
          PopupMenuItem(value: 'close', child: Text(l10n.listingCloseAction)),
        if (onDelete != null)
          PopupMenuItem(value: 'delete', child: Text(l10n.listingDeleteAction)),
      ],
    );
  }
}
