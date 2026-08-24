import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/storage_usage_provider.dart';
import '../../core/utils/error_format.dart';
import '../theme/dm_tool_colors.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const SectionLabel(this.text, this.palette, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DmToolColors palette;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: palette.featureCardBorder),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Media storage usage bar — used MB / quota MB + per-item limit hint.
///
/// Sayılan tek şey medya: dünyalar, karakterler ve paketler artık buluta
/// kopyalanmıyor, yerelde ve LAN üzerinden yaşıyorlar.
class StorageUsageBar extends ConsumerWidget {
  final DmToolColors palette;
  const StorageUsageBar({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(cloudStorageUsedProvider);
    const quotaBytes = mediaUserQuota;

    return storageAsync.when(
      data: (bytes) {
        final usedMb = bytes / (1024 * 1024);
        final totalMb = quotaBytes / (1024 * 1024);
        const itemLimitMb = mediaItemSizeLimit / (1024 * 1024);
        final ratio = (bytes / quotaBytes).clamp(0.0, 1.0);
        final remainingMb = totalMb - usedMb;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: palette.br,
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: palette.featureCardBorder,
                      color: ratio > 0.9
                          ? palette.dangerBtnBg
                          : palette.featureCardAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${usedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(0)} MB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${remainingMb.toStringAsFixed(1)} MB remaining  |  Max ${itemLimitMb.toStringAsFixed(0)} MB per item',
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: palette.featureCardAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Combined: cloud backups + media assets. Temporary limit.',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.sidebarLabelSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 8,
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
        isOfflineError(e)
            ? "You're offline — storage info unavailable."
            : 'Could not load storage info',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
    );
  }
}

