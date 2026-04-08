import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/dm_tool_colors.dart';

/// Sağ taraftan açılan PDF görüntüleme sidebar'ı.
/// Tab-based: en fazla 10 PDF aynı anda açılabilir.
class PdfSidebar extends StatelessWidget {
  final List<String> openPaths;
  final int activeIndex;
  final DmToolColors palette;
  final ValueChanged<int> onTabSelect;
  final ValueChanged<int> onTabClose;
  final ValueChanged<String> onOpenFile;

  const PdfSidebar({
    super.key,
    required this.openPaths,
    required this.activeIndex,
    required this.palette,
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
        // Tab bar
        if (openPaths.isNotEmpty)
          _PdfTabBar(
            paths: openPaths,
            activeIndex: activeIndex,
            palette: palette,
            onSelect: onTabSelect,
            onClose: onTabClose,
          ),
        // PDF viewer area
        Expanded(
          child: activePath != null && File(activePath).existsSync()
              ? PdfViewer.file(
                  activePath,
                  key: ValueKey(activePath),
                  params: PdfViewerParams(
                    backgroundColor: palette.canvasBg,
                  ),
                )
              : _EmptyPdfPanel(palette: palette, onOpenFile: _pickPdf),
        ),
      ],
    );
  }
}

/// PDF tab bar — database_screen _TabBar stilini takip eder.
class _PdfTabBar extends StatelessWidget {
  final List<String> paths;
  final int activeIndex;
  final DmToolColors palette;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _PdfTabBar({
    required this.paths,
    required this.activeIndex,
    required this.palette,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        itemBuilder: (context, i) {
          final fileName = paths[i].split('/').last.split('\\').last;
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
                    color: isActive ? palette.tokenBorderHostile : palette.tabText,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? palette.tabActiveText : palette.tabText,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
                        color: isActive ? palette.tabText : palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Boş state — PDF açılmadığında gösterilir.
class _EmptyPdfPanel extends StatelessWidget {
  final DmToolColors palette;
  final VoidCallback onOpenFile;

  const _EmptyPdfPanel({required this.palette, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf, size: 48, color: palette.tabText.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No PDF open',
            style: TextStyle(fontSize: 14, color: palette.tabText.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(
            'Open from entity or file',
            style: TextStyle(fontSize: 12, color: palette.tabText.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenFile,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Open File'),
          ),
        ],
      ),
    );
  }
}
