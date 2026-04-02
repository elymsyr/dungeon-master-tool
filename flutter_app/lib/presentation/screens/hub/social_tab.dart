import 'package:flutter/material.dart';

import '../../theme/dm_tool_colors.dart';

class SocialTab extends StatelessWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text(
            'Social',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(fontSize: 14, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Online sessions, player connections,\nand community features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.tabText),
          ),
        ],
      ),
    );
  }
}
