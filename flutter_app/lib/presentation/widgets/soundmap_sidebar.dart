import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Sag taraftan acilan Soundmap sidebar'i — su an bos template.
class SoundmapSidebar extends StatelessWidget {
  final DmToolColors palette;

  const SoundmapSidebar({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 48, color: palette.tabText.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Soundmap',
            style: TextStyle(fontSize: 14, color: palette.tabText.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(
            'Coming soon',
            style: TextStyle(fontSize: 12, color: palette.tabText.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
