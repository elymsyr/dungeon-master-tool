import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/first_party_catalog_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../domain/entities/catalog/catalog_entry.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Details + install dialog for an official (first-party catalog) package.
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

    final installedNames =
        ref.watch(packageListProvider).valueOrNull?.map((p) => p.name).toSet() ??
            const <String>{};
    final status =
        ref.watch(firstPartyInstallProvider.select((m) => m[entry.slug])) ??
            const CatalogInstallStatus();
    // Installed packages are named by their human title (see
    // PackagePayloadImporter), so match on title with a slug fallback.
    final installedName = entry.title.isEmpty ? entry.slug : entry.title;
    final installed = installedNames.contains(installedName) ||
        status.phase == CatalogInstallPhase.done;

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
          Icon(Icons.inventory_2_outlined,
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
                      l10n.itemTypePackage,
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
                label: '${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
                palette: palette,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        _action(context, ref, l10n, palette, installed, status),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    DmToolColors palette,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.featureCardAccent),
          ),
        ],
      );
    }

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
