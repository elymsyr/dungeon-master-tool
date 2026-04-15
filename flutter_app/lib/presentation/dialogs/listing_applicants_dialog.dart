import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/social_providers.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/game_listing.dart';
import '../../domain/entities/game_listing_application.dart';
import '../l10n/app_localizations.dart';
import '../screens/social/players_tab.dart' show openDmWithApplicant;
import '../theme/dm_tool_colors.dart';
import '../widgets/profile_avatar.dart';

/// Listing sahibine o ilana gelen başvuruları gösteren dialog. Her
/// başvurucu için avatar + username + mesaj + Mesaj gönder butonu.
class ListingApplicantsDialog extends ConsumerWidget {
  final GameListing listing;
  const ListingApplicantsDialog({super.key, required this.listing});

  static Future<void> show(BuildContext context, {required GameListing listing}) {
    return showDialog<void>(
      context: context,
      builder: (_) => ListingApplicantsDialog(listing: listing),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final apps = ref.watch(listingApplicationsProvider(listing.id));
    return AlertDialog(
      title: Text(
        l10n.listingApplicantsTitle(listing.title),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: apps.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(formatError(e),
                style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    l10n.listingApplicantsEmpty,
                    style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
                  ),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.featureCardBorder),
                itemBuilder: (_, i) =>
                    _ApplicantRow(app: list[i], palette: palette),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }
}

class _ApplicantRow extends ConsumerWidget {
  final GameListingApplication app;
  final DmToolColors palette;
  const _ApplicantRow({required this.app, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            avatarUrl: app.applicantAvatarUrl,
            fallbackText: app.applicantUsername ?? '?',
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.applicantDisplayName ?? '@${app.applicantUsername ?? '?'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().format(app.createdAt.toLocal()),
                      style: TextStyle(fontSize: 10, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
                if (app.applicantUsername != null)
                  Text('@${app.applicantUsername}',
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                const SizedBox(height: 6),
                Text(app.message,
                    style: TextStyle(fontSize: 12, height: 1.4, color: palette.tabText)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: Text(l10n.listingMessageApplicant),
                      onPressed: () => openDmWithApplicant(
                        context,
                        ref,
                        app.applicantId,
                        app.applicantUsername,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
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
