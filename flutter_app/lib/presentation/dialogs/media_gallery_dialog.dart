import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../theme/dm_tool_colors.dart';

/// Uygulama içi medya galerisi dialogu.
/// Campaign/package'ın media dizinindeki resimleri gösterir,
/// lokalden import ve seçim yapılmasını sağlar.
class MediaGalleryDialog extends StatefulWidget {
  final String mediaDir;
  final bool allowMultiple;

  const MediaGalleryDialog({
    super.key,
    required this.mediaDir,
    this.allowMultiple = true,
  });

  /// Galeri dialogunu göster. Seçilen dosya yollarını döndürür.
  static Future<List<String>?> show(
    BuildContext context, {
    required String mediaDir,
    bool allowMultiple = true,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => MediaGalleryDialog(
        mediaDir: mediaDir,
        allowMultiple: allowMultiple,
      ),
    );
  }

  @override
  State<MediaGalleryDialog> createState() => _MediaGalleryDialogState();
}

class _MediaGalleryDialogState extends State<MediaGalleryDialog> {
  List<String> _images = [];
  final Set<String> _selected = {};
  bool _loading = true;

  static const _imageExtensions = {
    '.png', '.jpg', '.jpeg', '.bmp', '.webp', '.gif',
  };

  @override
  void initState() {
    super.initState();
    _scanImages();
  }

  Future<void> _scanImages() async {
    setState(() => _loading = true);
    final dir = Directory(widget.mediaDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final entries = <_ImageEntry>[];
    await for (final entry in dir.list()) {
      if (entry is File) {
        final ext = p.extension(entry.path).toLowerCase();
        if (_imageExtensions.contains(ext)) {
          final stat = await entry.stat();
          entries.add(_ImageEntry(entry.path, stat.modified));
        }
      }
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));

    if (mounted) {
      setState(() {
        _images = entries.map((e) => e.path).toList();
        _loading = false;
      });
    }
  }

  Future<void> _importFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final dir = Directory(widget.mediaDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final imported = <String>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final src = File(file.path!);
      if (!await src.exists()) continue;

      final name = p.basename(file.path!);
      var target = p.join(widget.mediaDir, name);
      if (await File(target).exists()) {
        final base = p.basenameWithoutExtension(name);
        final ext = p.extension(name);
        target = p.join(
          widget.mediaDir,
          '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
      }
      await src.copy(target);
      imported.add(target);
    }

    await _scanImages();

    if (mounted) {
      setState(() {
        for (final path in imported) {
          _selected.add(path);
        }
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Images'),
        content: Text('Delete $count selected image${count > 1 ? 's' : ''} from the media gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final path in _selected.toList()) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _selected.clear();
    await _scanImages();
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        if (!widget.allowMultiple) _selected.clear();
        _selected.add(path);
      }
    });
  }

  Future<void> _deleteImage(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Remove this image from the media gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final file = File(path);
    if (await file.exists()) await file.delete();
    _selected.remove(path);
    await _scanImages();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: palette.featureCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_library, size: 20, color: palette.tabIndicator),
                  const SizedBox(width: 8),
                  const Text(
                    'Media Gallery',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _importFromFiles,
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('Import', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Grid ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _images.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 48,
                                color: palette.sidebarLabelSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No images yet',
                                style: TextStyle(
                                  color: palette.sidebarLabelSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click Import to add images',
                                style: TextStyle(
                                  color: palette.sidebarLabelSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            final path = _images[index];
                            final isSelected = _selected.contains(path);
                            return _ImageTile(
                              path: path,
                              isSelected: isSelected,
                              palette: palette,
                              onTap: () => _toggleSelection(path),
                              onDelete: () => _deleteImage(path),
                            );
                          },
                        ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.featureCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_images.length} images',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(
                        'Delete (${_selected.length})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    child: Text(
                      _selected.isEmpty
                          ? 'Select'
                          : 'Select (${_selected.length})',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──

class _ImageEntry {
  final String path;
  final DateTime modified;
  _ImageEntry(this.path, this.modified);
}

class _ImageTile extends StatefulWidget {
  final String path;
  final bool isSelected;
  final DmToolColors palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageTile({
    required this.path,
    required this.isSelected,
    required this.palette,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? widget.palette.tokenBorderActive
                  : _hovered
                      ? widget.palette.featureCardBorder
                      : Colors.transparent,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(widget.path),
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (_, _, _) => Container(
                    color: widget.palette.canvasBg,
                    child: Icon(
                      Icons.broken_image,
                      color: widget.palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
                // Selection checkmark
                if (widget.isSelected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: widget.palette.tokenBorderActive,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Delete button on hover
                if (_hovered)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Filename overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    color: Colors.black54,
                    child: Text(
                      p.basename(widget.path),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
