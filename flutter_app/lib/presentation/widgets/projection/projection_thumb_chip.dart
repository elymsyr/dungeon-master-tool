import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/entities/projection/projection_item.dart';
import '../../theme/dm_tool_colors.dart';

/// Single chip in the projection panel — represents one `ProjectionItem`.
/// Shows a small thumbnail (when available), the label, and a close button.
/// Active chip has an accent border.
class ProjectionThumbChip extends StatelessWidget {
  final ProjectionItem item;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const ProjectionThumbChip({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final borderColor = isActive ? palette.tabIndicator : palette.featureCardBorder;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 110,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isActive ? 2 : 1),
            borderRadius: BorderRadius.circular(6),
            color: palette.featureCardBg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: _thumbnail(palette),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.htmlText,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 1,
                right: 1,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(DmToolColors palette) {
    if (item is ImageProjection) {
      final paths = (item as ImageProjection).filePaths;
      if (paths.isNotEmpty) {
        final file = File(paths.first);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 220,
            errorBuilder: (_, _, _) => _iconFallback(palette),
          );
        }
      }
    }
    return _iconFallback(palette);
  }

  Widget _iconFallback(DmToolColors palette) {
    IconData icon;
    switch (item) {
      case ImageProjection():
        icon = Icons.image;
      case BlackScreenProjection():
        icon = Icons.tonality;
      case EntityCardProjection():
        icon = Icons.person;
      case BattleMapProjection():
        icon = Icons.map;
      case PdfProjection():
        icon = Icons.picture_as_pdf;
    }
    return Container(
      color: palette.tabBg,
      alignment: Alignment.center,
      child: Icon(icon, size: 24, color: palette.sidebarLabelSecondary),
    );
  }
}
