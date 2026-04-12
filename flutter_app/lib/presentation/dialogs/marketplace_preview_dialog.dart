import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/item_visibility_provider.dart';
import '../../application/providers/social_providers.dart';
import '../../core/utils/world_languages.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Marketplace'te bir item'a tıklanınca açılan önizleme + indirme dialog'u.
class MarketplacePreviewDialog extends ConsumerWidget {
  final MarketplaceEntry entry;
  const MarketplacePreviewDialog({super.key, required this.entry});

  static Future<void> show(BuildContext context, {required MarketplaceEntry entry}) {
    return showDialog<void>(
      context: context,
      builder: (_) => MarketplacePreviewDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final item = entry.item;
    final downloadState = ref.watch(itemVisibilityNotifierProvider);
    final downloading = downloadState is AsyncLoading;

    final typeLabel = switch (item.itemType) {
      'world' => l10n.itemTypeWorld,
      'template' => l10n.itemTypeTemplate,
      'package' => l10n.itemTypePackage,
      _ => l10n.itemTypeGeneric,
    };
    final icon = switch (item.itemType) {
      'world' => Icons.public,
      'template' => Icons.description_outlined,
      'package' => Icons.inventory_2_outlined,
      _ => Icons.folder_outlined,
    };

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.featureCardAccent, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$typeLabel · @${entry.ownerUsername ?? '?'}',
                  style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
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
              if (item.description != null && item.description!.isNotEmpty) ...[
                Text(
                  item.description!,
                  style: TextStyle(fontSize: 13, height: 1.4, color: palette.tabText),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.language != null)
                    _KvPill(
                      icon: Icons.language,
                      label: worldLanguageNative(item.language!),
                      palette: palette,
                    ),
                  for (final tag in item.tags)
                    _KvPill(label: '#$tag', palette: palette),
                ],
              ),
              const SizedBox(height: 12),
              _KvRow(
                label: l10n.marketplaceDownloadCount(item.downloadCount),
                icon: Icons.download_outlined,
                palette: palette,
              ),
              const SizedBox(height: 6),
              _KvRow(
                label: '${(item.sizeBytes / 1024).toStringAsFixed(1)} KB',
                icon: Icons.sd_storage_outlined,
                palette: palette,
              ),
              const SizedBox(height: 6),
              _KvRow(
                label: DateFormat.yMMMd().add_Hm().format(item.updatedAt.toLocal()),
                icon: Icons.update,
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
        FilledButton.icon(
          onPressed: downloading
              ? null
              : () async {
                  final ok = await ref
                      .read(itemVisibilityNotifierProvider.notifier)
                      .downloadAndImport(
                        itemId: item.id,
                        itemType: item.itemType,
                        payloadPath: item.payloadPath ?? '',
                        title: item.title,
                      );
                  if (!context.mounted) return;
                  if (ok) {
                    // Refresh marketplace so download_count reflects the bump.
                    ref.invalidate(marketplaceProvider);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.marketplaceDownloadSuccess(item.title))),
                    );
                  } else {
                    final err = ref.read(itemVisibilityNotifierProvider).error;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.marketplaceDownloadError('$err'))),
                    );
                  }
                },
          icon: downloading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download),
          label: Text(downloading ? l10n.marketplaceDownloading : l10n.marketplaceDownload),
        ),
      ],
    );
  }
}

class _KvPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final DmToolColors palette;
  const _KvPill({required this.label, this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: BorderRadius.circular(12),
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

class _KvRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final DmToolColors palette;
  const _KvRow({required this.label, required this.icon, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: palette.tabText)),
      ],
    );
  }
}
