import 'package:flutter/material.dart';

import '../../theme/dm_tool_colors.dart';

/// Player'ın "Second Screen" sekmesi — şimdilik placeholder.
/// Online game session başlatıldığında DM'in projection state'ini realtime
/// olarak gösterecek. PR-O9+ ile doldurulacak.
class PlayerSecondScreenTab extends StatelessWidget {
  const PlayerSecondScreenTab({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      color: palette.tabBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cast,
                  size: 56, color: palette.sidebarLabelSecondary),
              const SizedBox(height: 12),
              Text(
                'Waiting for DM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your DM has not started a live session yet. When they do,'
                ' anything they project to the player screen will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
