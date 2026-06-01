import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/first_party_catalog_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../l10n/app_localizations.dart';
import '../screens/social/social_shell.dart';
import '../theme/dm_tool_colors.dart';

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 16,
                      color: palette.featureCardAccent),
                  const SizedBox(width: 6),
                  Text(
                    'Official packages',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.tabActiveText,
                    ),
                  ),
                ],
              ),
            ),
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

class _OfficialPackageCard extends ConsumerWidget {
  final CatalogEntry entry;
  final DmToolColors palette;
  const _OfficialPackageCard({required this.entry, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final installedNames =
        ref.watch(packageListProvider).valueOrNull?.map((p) => p.name).toSet() ??
            const <String>{};
    final status = ref.watch(
            firstPartyInstallProvider.select((m) => m[entry.slug])) ??
        const CatalogInstallStatus();
    final installed = installedNames.contains(entry.slug) ||
        status.phase == CatalogInstallPhase.done;

    return SocialCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.featureCardAccent.withValues(alpha: 0.12),
              borderRadius: palette.br,
            ),
            child: Icon(Icons.inventory_2,
                size: 22, color: palette.featureCardAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? entry.slug : entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _meta(l10n),
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _action(context, ref, l10n, installed, status),
        ],
      ),
    );
  }

  String _meta(L10n l10n) {
    final parts = <String>[];
    if (entry.publisher.isNotEmpty) parts.add(entry.publisher);
    if (entry.license.isNotEmpty) parts.add(entry.license);
    if (entry.totalEntities > 0) {
      parts.add(l10n.packageEntityCount(entry.totalEntities));
    }
    return parts.join(' · ');
  }

  Widget _action(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    bool installed,
    CatalogInstallStatus status,
  ) {
    if (installed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 4),
          Text(
            l10n.soundpackInstalled,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.featureCardAccent),
          ),
        ],
      );
    }

    if (status.phase == CatalogInstallPhase.installing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final isError = status.phase == CatalogInstallPhase.error;
    return ElevatedButton(
      onPressed: () =>
          ref.read(firstPartyInstallProvider.notifier).install(entry),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isError ? palette.dangerBtnBg : palette.featureCardAccent,
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: palette.br),
      ),
      child: Text(isError ? l10n.soundpackRetry : l10n.marketplaceDownload,
          style: const TextStyle(fontSize: 12)),
    );
  }
}
