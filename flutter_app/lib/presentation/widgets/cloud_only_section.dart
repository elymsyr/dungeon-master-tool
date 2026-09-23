import 'package:flutter/material.dart';

import '../../application/services/cloud_pull_service.dart';
import '../../core/utils/error_format.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Faz 5c — hub'ın "bulutta, bu cihazda yok" bölümü: başka cihazda online
/// yapılmış dünya ya da paket, satır başına "İndir" ve ilerleme çubuğu.
/// Liste boşsa (çevrimdışı, hesap yok, hepsi zaten burada) hiçbir şey çizmez.
///
/// Aynı anda tek indirme: ikisi aynı Drift'e sayfa sayfa yazıyor, sırayla
/// gitmeleri hem ilerlemeyi okunur tutuyor hem de yazma kilidini paylaşmıyor.
class CloudOnlySection extends StatefulWidget {
  const CloudOnlySection({
    super.key,
    required this.items,
    required this.hint,
    required this.download,
    required this.onDownloaded,
  });

  /// id → görünen ad, gösterilecek sırada.
  final Map<String, String> items;
  final String hint;
  final Future<CloudPullResult> Function(
    String id,
    void Function(double progress) onProgress,
  ) download;
  final VoidCallback onDownloaded;

  @override
  State<CloudOnlySection> createState() => _CloudOnlySectionState();
}

class _CloudOnlySectionState extends State<CloudOnlySection> {
  /// İnen öğe → ilerleme (0–1).
  final Map<String, double> _progress = {};

  Future<void> _download(String id, String name) async {
    setState(() => _progress[id] = 0);
    final res = await widget.download(id, (p) {
      if (mounted) setState(() => _progress[id] = p);
    });
    if (!mounted) return;
    setState(() => _progress.remove(id));
    final l10n = L10n.of(context)!;
    final error = res.error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok
          ? l10n.cloudOnlyDownloaded(name)
          : error is CloudPackageNameTaken
              ? l10n.cloudPackageNameTaken(error.name)
              : l10n.cloudOnlyDownloadFailed(
                  error == null ? '' : formatError(error))),
    ));
    if (res.ok) widget.onDownloaded();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cloudOnlyTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: palette.tabActiveText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.hint,
            style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 8),
          for (final MapEntry(key: id, value: name) in widget.items.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: palette.br,
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_outlined,
                        size: 18, color: palette.sidebarLabelSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                    if (_progress[id] case final p?)
                      SizedBox(
                        width: 120,
                        // İlk sayfa gelene kadar pay bilinmiyor: belirsiz.
                        child: LinearProgressIndicator(value: p == 0 ? null : p),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed:
                            _progress.isEmpty ? () => _download(id, name) : null,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(l10n.cloudOnlyDownload),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
