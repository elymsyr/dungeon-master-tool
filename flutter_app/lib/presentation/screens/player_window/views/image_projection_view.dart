import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/entities/projection/image_view_state.dart';
import '../../../../domain/entities/projection/projection_item.dart';

/// Renders an `ImageProjection` for the player window. Uses
/// `AutomaticKeepAliveClientMixin` so the decoded image stays in the widget
/// tree across tab switches — switching back is instant.
///
/// Multi-image items auto-layout (single / row / grid) based on
/// `ImageLayout`, mirroring the rule from Python `ui/player_window.py`:
///   1=single, 2-3=row, 4+=grid.
class ImageProjectionView extends StatefulWidget {
  final ImageProjection item;

  const ImageProjectionView({required this.item, super.key});

  @override
  State<ImageProjectionView> createState() => _ImageProjectionViewState();
}

class _ImageProjectionViewState extends State<ImageProjectionView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final paths = widget.item.filePaths;
    if (paths.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return RepaintBoundary(
      child: ColoredBox(
        color: Colors.black,
        child: _layout(context, paths),
      ),
    );
  }

  Widget _layout(BuildContext context, List<String> paths) {
    final mode = _resolveLayout(widget.item.layout, paths.length);
    switch (mode) {
      case ImageLayout.single:
      case ImageLayout.auto: // unreachable after _resolve
        return _SingleImage(path: paths.first);
      case ImageLayout.row:
        return Row(
          children: paths
              .map((p) => Expanded(child: _SingleImage(path: p)))
              .toList(),
        );
      case ImageLayout.grid:
        final cols = math.max(2, (math.sqrt(paths.length)).ceil());
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 16 / 9,
          ),
          itemCount: paths.length,
          itemBuilder: (_, i) => _SingleImage(path: paths[i]),
        );
    }
  }

  ImageLayout _resolveLayout(ImageLayout requested, int count) {
    if (requested != ImageLayout.auto) return requested;
    if (count <= 1) return ImageLayout.single;
    if (count <= 3) return ImageLayout.row;
    return ImageLayout.grid;
  }
}

class _SingleImage extends StatelessWidget {
  final String path;
  const _SingleImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
        ),
      );
    }
    // cacheWidth keyed to physical pixel width — avoids decoding 4k sources
    // at full resolution on a 1080p TV.
    final mq = MediaQuery.of(context);
    final cacheWidth =
        (mq.size.width * mq.devicePixelRatio).toInt().clamp(640, 3840);
    return Image.file(
      file,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
    );
  }
}
