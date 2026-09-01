import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/first_party_catalog_provider.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/listing_banner_card.dart'
    show iconForListingType, labelForListingType;

/// Details + install dialog for an official (first-party catalog) entry —
/// a package or a ready-to-play world.
/// Mirrors [MarketplacePreviewDialog] for user listings: opened from the
/// official card's "Get" button (or by tapping the card), it shows the package
/// details and installs from the [firstPartyInstallProvider] state machine.
class OfficialPackageDialog extends ConsumerWidget {
  final CatalogEntry entry;
  const OfficialPackageDialog({super.key, required this.entry});

  static Future<void> show(BuildContext context, {required CatalogEntry entry}) {
    return showDialog<void>(
      context: context,
      builder: (_) => OfficialPackageDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Kurulu olsa da her zaman indirilebilir: kurulum var olanı ezmez,
    // ismi çakışırsa "(Copy)" olarak kurulur (bkz. uniqueCopyName).
    final status =
        ref.watch(firstPartyInstallProvider.select((m) => m[entry.slug])) ??
            const CatalogInstallStatus();

    final pills = <Widget>[
      if (entry.gameSystem.isNotEmpty)
        _Pill(
          icon: Icons.dashboard_customize_outlined,
          label: '${l10n.marketplaceTemplateLabel}: ${entry.gameSystem}',
          palette: palette,
        ),
      if (entry.license.isNotEmpty)
        _Pill(icon: Icons.balance, label: entry.license, palette: palette),
      if (entry.version.isNotEmpty)
        _Pill(icon: Icons.tag, label: 'v${entry.version}', palette: palette),
    ];

    final counts = entry.counts.entries.where((e) => e.value > 0).toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconForListingType(entry.itemType),
              color: palette.featureCardAccent, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? entry.slug : entry.title,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Text(
                      labelForListingType(l10n, entry.itemType),
                      style: TextStyle(
                          fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.verified,
                        size: 12, color: palette.featureCardAccent),
                    const SizedBox(width: 2),
                    Text(
                      'Official',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.featureCardAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.description.isNotEmpty) ...[
                Text(
                  entry.description,
                  style: TextStyle(
                      fontSize: 13, height: 1.45, color: palette.tabActiveText),
                ),
                const SizedBox(height: 12),
              ],
              if (entry.author.isNotEmpty) ...[
                _Row(
                  icon: Icons.person_outline,
                  label: entry.author,
                  palette: palette,
                ),
                const SizedBox(height: 8),
              ],
              if (entry.attribution.isNotEmpty) ...[
                Text(
                  entry.attribution,
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: palette.tabText),
                ),
                const SizedBox(height: 12),
              ],
              if (pills.isNotEmpty) ...[
                Wrap(spacing: 6, runSpacing: 6, children: pills),
                const SizedBox(height: 12),
              ],
              if (counts.isNotEmpty) ...[
                Text(
                  l10n.marketplaceContentsLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    border: Border.all(color: palette.featureCardBorder),
                    borderRadius: palette.chr,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in counts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${c.key}  (${c.value})',
                            style: TextStyle(
                                fontSize: 13, color: palette.tabActiveText),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Row(
                icon: Icons.sd_storage_outlined,
                label: _formatBytes(entry.downloadBytes),
                palette: palette,
              ),
              // The adventure PDF is not hosted in our catalog — it downloads
              // free from the publisher. Say so, so a slow install is legible.
              if (entry.externalFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Row(
                  icon: Icons.picture_as_pdf_outlined,
                  label: l10n.catalogExternalPdfNote,
                  palette: palette,
                ),
              ],
              if (entry.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SourceLink(url: entry.sourceUrl, palette: palette),
              ],
              if (entry.bannerCreditLink != null &&
                  entry.bannerCreditLink!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _BannerCredit(
                  creator: entry.bannerCreditCreator,
                  link: entry.bannerCreditLink!,
                  palette: palette,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        if (status.phase == CatalogInstallPhase.done) ...[
          Icon(Icons.check_circle, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 4),
          Text(
            l10n.soundpackInstalled,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.featureCardAccent),
          ),
          const SizedBox(width: 8),
        ],
        _action(context, ref, l10n, status),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    CatalogInstallStatus status,
  ) {
    final installing = status.phase == CatalogInstallPhase.installing;
    final isError = status.phase == CatalogInstallPhase.error;
    return FilledButton.icon(
      onPressed: installing
          ? null
          : () => ref.read(firstPartyInstallProvider.notifier).install(entry),
      icon: installing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.download, size: 18),
      label: Text(isError ? l10n.soundpackRetry : l10n.marketplaceGet),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final DmToolColors palette;
  const _Pill({required this.label, this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.chr,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: palette.tabText)),
        ],
      ),
    );
  }
}

/// Tappable banner artwork attribution (creator + source link) sourced from
/// `banner-credits.yaml`. Opens the source page in the browser.
class _BannerCredit extends StatelessWidget {
  final String? creator;
  final String link;
  final DmToolColors palette;
  const _BannerCredit({
    required this.creator,
    required this.link,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final hasCreator =
        creator != null && creator!.isNotEmpty && creator != 'unknown';
    final label = hasCreator ? 'Banner art: $creator' : 'Banner art source';
    return InkWell(
      onTap: () => launchUrl(Uri.parse(link),
          mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          Icon(Icons.image_outlined,
              size: 14, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: palette.featureCardAccent,
                decoration: TextDecoration.underline,
                decorationColor: palette.featureCardAccent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.open_in_new,
              size: 12, color: palette.featureCardAccent),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final IconData icon;
  final DmToolColors palette;
  const _Row({required this.label, required this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: palette.tabText)),
      ],
    );
  }
}

/// Total download size, KB under a megabyte and MB above — a world pulls tens
/// of megabytes of maps and tokens, which "43008.0 KB" does not communicate.
String _formatBytes(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';

/// Link to the publisher's page for the work (`source_url`), so the credited
/// author is one tap away. Mirrors [_BannerCredit].
class _SourceLink extends StatelessWidget {
  final String url;
  final DmToolColors palette;
  const _SourceLink({required this.url, required this.palette});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              url,
              style: TextStyle(
                fontSize: 12,
                color: palette.featureCardAccent,
                decoration: TextDecoration.underline,
                decorationColor: palette.featureCardAccent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
