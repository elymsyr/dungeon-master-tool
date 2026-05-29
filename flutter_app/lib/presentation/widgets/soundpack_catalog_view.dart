import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/soundpack_catalog_provider.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/audio/soundpack_catalog.dart';
import '../l10n/app_localizations.dart';
import '../screens/social/social_shell.dart';
import '../theme/dm_tool_colors.dart';
import 'connection_error_view.dart';

/// Renders the curated GitHub soundpack catalog as a column of cards, each with
/// a Get / Downloading… / Installed action. Embeddable inside an existing
/// scroll view (returns a [Column], not its own scrollable).
class SoundpackCatalogView extends ConsumerWidget {
  const SoundpackCatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final catalog = ref.watch(soundpackCatalogProvider);

    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => isOfflineError(e)
          ? ConnectionErrorView(
              onRetry: () => ref.invalidate(soundpackCatalogProvider))
          : SocialCard(
              child: Text(formatError(e),
                  style:
                      TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
            ),
      data: (packs) {
        if (packs.isEmpty) {
          return SocialEmptyState(
            icon: Icons.library_music_outlined,
            title: l10n.soundpacksEmpty,
            subtitle: l10n.soundpacksEmptySub,
          );
        }
        return Column(
          children: [
            for (final pack in packs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SoundpackCard(pack: pack, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _SoundpackCard extends ConsumerWidget {
  final SoundpackCatalogEntry pack;
  final DmToolColors palette;
  const _SoundpackCard({required this.pack, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final installed = ref.watch(installedSoundpackIdsProvider).contains(pack.id);
    final status = ref.watch(
        soundpackDownloadProvider.select((m) => m[pack.id])) ??
        const SoundpackDownloadStatus();

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
            child: Icon(Icons.library_music_outlined,
                size: 22, color: palette.featureCardAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name.isEmpty ? pack.id : pack.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
                if (pack.description != null &&
                    pack.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pack.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _meta(),
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

  String _meta() {
    final parts = <String>[];
    if (pack.author != null && pack.author!.isNotEmpty) parts.add(pack.author!);
    if (pack.sizeBytes > 0) parts.add(_humanSize(pack.sizeBytes));
    return parts.join(' · ');
  }

  Widget _action(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    bool installed,
    SoundpackDownloadStatus status,
  ) {
    final done = installed || status.phase == SoundpackDownloadPhase.done;
    if (done) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 4),
          Text(l10n.soundpackInstalled,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.featureCardAccent)),
        ],
      );
    }

    if (status.phase == SoundpackDownloadPhase.downloading) {
      final pct = (status.progress * 100).round();
      return SizedBox(
        width: 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.progress > 0 ? status.progress : null,
                minHeight: 5,
                backgroundColor: palette.featureCardBorder,
                color: palette.featureCardAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text('${l10n.soundpackDownloading} $pct%',
                style: TextStyle(
                    fontSize: 10, color: palette.sidebarLabelSecondary)),
          ],
        ),
      );
    }

    final isError = status.phase == SoundpackDownloadPhase.error;
    return ElevatedButton(
      onPressed: () => ref
          .read(soundpackDownloadProvider.notifier)
          .download(pack),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isError ? palette.dangerBtnBg : palette.featureCardAccent,
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: palette.br),
      ),
      child: Text(isError ? l10n.soundpackRetry : l10n.soundpackGet,
          style: const TextStyle(fontSize: 12)),
    );
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
