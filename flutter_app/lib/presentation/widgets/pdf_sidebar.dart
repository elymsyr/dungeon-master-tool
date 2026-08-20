import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../application/services/pdf_library_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Sağ taraftan açılan PDF görüntüleme sidebar'ı.
/// Tab-based: en fazla 10 PDF aynı anda açılabilir. İlk tab kapanmayan
/// kütüphanedir ([activeIndex] `-1`) — dünyaya kopyalanmış PDF'leri listeler.
class PdfSidebar extends StatelessWidget {
  final List<String> openPaths;
  final int activeIndex;
  final DmToolColors palette;
  final String worldName;
  final ValueChanged<int> onTabSelect;
  final ValueChanged<int> onTabClose;
  final ValueChanged<String> onOpenFile;

  const PdfSidebar({
    super.key,
    required this.openPaths,
    required this.activeIndex,
    required this.palette,
    required this.worldName,
    required this.onTabSelect,
    required this.onTabClose,
    required this.onOpenFile,
  });

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      if (file.path != null) onOpenFile(file.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePath = (activeIndex >= 0 && activeIndex < openPaths.length)
        ? openPaths[activeIndex]
        : null;

    return Column(
      children: [
        _PdfTabBar(
          paths: openPaths,
          activeIndex: activeIndex,
          palette: palette,
          onSelect: onTabSelect,
          onClose: onTabClose,
          onAdd: _pickPdf,
        ),
        // PDF viewer area
        Expanded(
          child: activePath != null && File(activePath).existsSync()
              ? PdfViewer.file(
                  activePath,
                  key: ValueKey(activePath),
                  params: PdfViewerParams(backgroundColor: palette.canvasBg),
                )
              : PdfLibraryPanel(
                  palette: palette,
                  worldName: worldName,
                  openPaths: openPaths,
                  onOpenFile: onOpenFile,
                  onCloseTab: onTabClose,
                  onPickFile: _pickPdf,
                ),
        ),
      ],
    );
  }
}

/// PDF tab bar — database_screen _TabBar stilini takip eder.
/// En soldaki kütüphane tab'ı kapatılamaz; seçilince [onSelect] `-1` alır.
class _PdfTabBar extends StatelessWidget {
  final List<String> paths;
  final int activeIndex;
  final DmToolColors palette;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onAdd;

  const _PdfTabBar({
    required this.paths,
    required this.activeIndex,
    required this.palette,
    required this.onSelect,
    required this.onClose,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final libraryActive = activeIndex < 0 || activeIndex >= paths.length;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: Row(
        // stretch: kütüphane tab'ı ve + butonu şeridin tamamını kaplasın —
        // default `center` ile Container yalnız içeriği kadar yükseklik alır
        // ve aktif arkaplan rengi görünmezdi (dosya tab'ları yatay ListView
        // içinde olduğu için zaten stretch oluyor).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kütüphane (ana menü) tab'ı — kapanmaz.
          GestureDetector(
            onTap: () => onSelect(-1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 1),
              decoration: BoxDecoration(
                color: libraryActive ? palette.tabActiveBg : palette.tabBg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 14,
                    color: libraryActive
                        ? palette.tabActiveText
                        : palette.tabText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.pdfLibraryTab,
                    style: TextStyle(
                      fontSize: 12,
                      color: libraryActive
                          ? palette.tabActiveText
                          : palette.tabText,
                      fontWeight: libraryActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              itemBuilder: (context, i) {
                final fileName = p.basename(paths[i]);
                final isActive = i == activeIndex;

                return GestureDetector(
                  onTap: () => onSelect(i),
                  onTertiaryTapUp: (_) => onClose(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(right: 1),
                    decoration: BoxDecoration(
                      color: isActive ? palette.tabActiveBg : palette.tabBg,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 14,
                          color: isActive
                              ? palette.tokenBorderHostile
                              : palette.tabText,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? palette.tabActiveText
                                  : palette.tabText,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onClose(i),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: isActive
                                  ? palette.tabText
                                  : palette.sidebarLabelSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          InkWell(
            onTap: onAdd,
            child: Container(
              width: 32,
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 18, color: palette.tabText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kütüphane paneli — `{worldsDir}/{worldName}/pdfs/` klasörünü listeler.
/// Dünya online ise DM'in paylaştığı, henüz indirilmemiş PDF'ler de görünür.
class PdfLibraryPanel extends ConsumerStatefulWidget {
  const PdfLibraryPanel({
    super.key,
    required this.palette,
    required this.worldName,
    required this.openPaths,
    required this.onOpenFile,
    required this.onCloseTab,
    required this.onPickFile,
  });

  final DmToolColors palette;
  final String worldName;
  final List<String> openPaths;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<int> onCloseTab;
  final VoidCallback onPickFile;

  @override
  ConsumerState<PdfLibraryPanel> createState() => _PdfLibraryPanelState();
}

class _PdfLibraryPanelState extends ConsumerState<PdfLibraryPanel> {
  late Future<List<_LibraryRow>> _rows;

  /// İndirilme sırasındaki dosya adları — satır spinner gösterir.
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _rows = _load();
  }

  @override
  void didUpdateWidget(PdfLibraryPanel old) {
    super.didUpdateWidget(old);
    // Yeni bir PDF import edilince tab listesi büyür — panel state'i korunduğu
    // için future'ı tazelemezsek kütüphaneye dönen kullanıcı yeni dosyayı
    // göremezdi.
    if (old.worldName != widget.worldName ||
        old.openPaths.length != widget.openPaths.length) {
      _refresh();
    }
  }

  void _refresh() {
    // Blok gövde şart: `=> _rows = _load()` atamanın değerini (bir Future)
    // döndürür ve setState "callback argument returned a Future" atar.
    setState(() {
      _rows = _load();
    });
  }

  Future<List<_LibraryRow>> _load() async {
    final svc = ref.read(pdfLibraryServiceProvider);
    final local = await PdfLibraryService.localFiles(widget.worldName);
    final rows = <_LibraryRow>[
      for (final f in local)
        _LibraryRow(
          name: p.basename(f.path),
          path: f.path,
          size: await f.length(),
        ),
    ];
    final localNames = rows.map((r) => r.name).toSet();
    // Paylaşılmış ama henüz inmemiş olanlar.
    for (final entry in svc.manifest()) {
      if (entry.name.isEmpty || localNames.contains(entry.name)) continue;
      rows.add(
        _LibraryRow(name: entry.name, size: entry.sizeBytes, remote: entry),
      );
    }
    return rows;
  }

  Future<void> _open(_LibraryRow row) async {
    if (row.path != null) {
      widget.onOpenFile(row.path!);
      return;
    }
    final entry = row.remote;
    if (entry == null || _downloading.contains(row.name)) return;
    setState(() => _downloading.add(row.name));
    try {
      final path = await ref
          .read(pdfLibraryServiceProvider)
          .download(entry, widget.worldName);
      if (!mounted) return;
      widget.onOpenFile(path);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context)!.pdfLibraryDownloadFailed('$e')),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading.remove(row.name));
    }
  }

  Future<void> _remove(_LibraryRow row) async {
    final l10n = L10n.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pdfLibraryRemoveTitle),
        content: Text(l10n.pdfLibraryRemoveBody(row.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.pdfLibraryRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Açık tab'ı önce kapat — silinen dosyaya bakan viewer kalmasın.
    if (row.path != null) {
      final idx = widget.openPaths.indexOf(row.path!);
      if (idx != -1) widget.onCloseTab(idx);
    }
    await ref
        .read(pdfLibraryServiceProvider)
        .remove(widget.worldName, row.name);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = widget.palette;

    // ListTile arkaplanını/ink splash'ini en yakın Material'a çizer; sidebar'ın
    // DecoratedBox'ı araya girdiği için kendi transparan Material'ımızı veriyoruz.
    return Material(
      type: MaterialType.transparency,
      child: FutureBuilder<List<_LibraryRow>>(
        future: _rows,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return _EmptyLibrary(
              palette: palette,
              onPickFile: widget.onPickFile,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pdfLibraryTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.sidebarLabelSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onPickFile,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: Text(l10n.pdfLibraryOpenFile),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final isRemote = row.path == null;
                    return ListTile(
                      dense: true,
                      leading: _downloading.contains(row.name)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isRemote
                                  ? Icons.cloud_download_outlined
                                  : Icons.picture_as_pdf,
                              size: 20,
                              color: isRemote
                                  ? palette.sidebarLabelSecondary
                                  : palette.tokenBorderHostile,
                            ),
                      title: Text(
                        row.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        isRemote
                            ? '${_formatSize(row.size)} · ${l10n.pdfLibraryShared}'
                            : _formatSize(row.size),
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.sidebarLabelSecondary,
                        ),
                      ),
                      onTap: () => _open(row),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: l10n.pdfLibraryRemove,
                        onPressed: () => _remove(row),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

/// Kütüphane boşken gösterilir.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.palette, required this.onPickFile});

  final DmToolColors palette;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 48,
            color: palette.tabText.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.pdfLibraryEmpty,
            style: TextStyle(
              fontSize: 14,
              color: palette.tabText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.pdfLibraryEmptyHint,
            style: TextStyle(
              fontSize: 12,
              color: palette.tabText.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(l10n.pdfLibraryOpenFile),
          ),
        ],
      ),
    );
  }
}

class _LibraryRow {
  const _LibraryRow({
    required this.name,
    required this.size,
    this.path,
    this.remote,
  });

  final String name;
  final int size;

  /// Local kopyanın yolu; yalnızca paylaşılmış (henüz inmemiş) satırlarda null.
  final String? path;

  /// Local karşılığı yoksa indirilecek manifest girdisi.
  final PdfLibraryEntry? remote;
}
