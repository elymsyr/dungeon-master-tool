import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/social_providers.dart';
import '../../../core/utils/cached_provider.dart';
import '../../../core/utils/error_format.dart';
import '../../../core/utils/screen_type.dart';
import '../../../core/utils/world_languages.dart';
import '../../../domain/entities/game_listing.dart';
import '../../dialogs/create_listing_dialog.dart';
import '../../dialogs/listing_applicants_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import 'messages_tab.dart';
import 'social_shell.dart';

/// "Game Listings" sekmesi — kullanıcının kendi ilanlarını yönetmesi için.
/// Başvuranları incelemek, ilanları kapatmak veya silmek, yeni ilan
/// oluşturmak için tek duraktır.
class PlayersTab extends ConsumerWidget {
  const PlayersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final listingsAsync = ref.watch(myGameListingsProvider);

    final hPad = isPhone(context) ? 12.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () async {
        invalidateCache('myGameListings');
        ref.invalidate(myGameListingsProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.listingMineTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.btnNewListing),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.featureCardAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: palette.br),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => CreateListingDialog.show(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          listingsAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SocialCard(
              child: Text(formatError(e), style: TextStyle(color: palette.dangerBtnBg, fontSize: 12)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SocialEmptyState(
                  icon: Icons.groups_outlined,
                  title: l10n.listingMineEmpty,
                );
              }
              return Column(
                children: [
                  for (final l in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OwnerListingCard(listing: l),
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

class _OwnerListingCard extends ConsumerWidget {
  final GameListing listing;
  const _OwnerListingCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return SocialCard(
      onTap: () => ListingApplicantsDialog.show(context, listing: listing),
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
                ),
              ),
              if (!listing.isOpen)
                _MetaChip(label: l10n.listingClosedBadge, palette: palette, isDanger: true),
              if (listing.system != null) ...[
                const SizedBox(width: 6),
                _MetaChip(label: listing.system!, palette: palette),
              ],
            ],
          ),
          if (listing.description != null && listing.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              listing.description!,
              style: TextStyle(fontSize: 13, height: 1.4, color: palette.tabText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (listing.gameLanguage != null || listing.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (listing.gameLanguage != null)
                  _MetaChip(
                    label: worldLanguageNative(listing.gameLanguage!),
                    icon: Icons.language,
                    palette: palette,
                  ),
                for (final t in listing.tags.take(4))
                  _MetaChip(label: '#$t', palette: palette),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_add_alt, size: 14, color: palette.featureCardAccent),
              const SizedBox(width: 4),
              Text(
                l10n.listingApplicationCount(listing.applicationCount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.featureCardAccent,
                ),
              ),
              const SizedBox(width: 14),
              if (listing.seatsTotal != null) ...[
                Icon(Icons.event_seat_outlined, size: 13, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 4),
                Text(
                  '${listing.seatsFilled}/${listing.seatsTotal}',
                  style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
              const Spacer(),
              Text(
                DateFormat.yMMMd().format(listing.createdAt.toLocal()),
                style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
              ),
              _OwnerMenu(listing: listing),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerMenu extends ConsumerWidget {
  final GameListing listing;
  const _OwnerMenu({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (v) async {
        final ds = ref.read(gameListingsRemoteDsProvider);
        switch (v) {
          case 'close':
            await ds.close(listing.id);
            break;
          case 'delete':
            await ds.delete(listing.id);
            break;
        }
        invalidateCache('myGameListings');
        invalidateCachePrefix('gameListings:');
        ref.invalidate(myGameListingsProvider);
        ref.invalidate(openGameListingsProvider);
      },
      itemBuilder: (_) => [
        if (listing.isOpen)
          PopupMenuItem(value: 'close', child: Text(l10n.listingCloseAction)),
        PopupMenuItem(value: 'delete', child: Text(l10n.listingDeleteAction)),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final DmToolColors palette;
  final bool isDanger;
  const _MetaChip({
    required this.label,
    this.icon,
    required this.palette,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDanger
        ? palette.dangerBtnBg.withValues(alpha: 0.15)
        : palette.featureCardBg;
    final fg = isDanger ? palette.dangerBtnBg : palette.tabText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Applicant'a DM açmak için yardımcı: konuşma oluştur + ChatScreen push.
Future<void> openDmWithApplicant(
  BuildContext context,
  WidgetRef ref,
  String otherUserId,
  String? otherUsername,
) async {
  try {
    final conv = await ref.read(messagesRemoteDsProvider).openDirect(otherUserId);
    if (!context.mounted) return;
    final myUid = ref.read(authProvider)?.uid ?? '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conv, myUserId: myUid),
    ));
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
  } catch (e) {
    if (!context.mounted) return;
    final l10n = L10n.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileDmError('$e'))),
    );
  }
}
