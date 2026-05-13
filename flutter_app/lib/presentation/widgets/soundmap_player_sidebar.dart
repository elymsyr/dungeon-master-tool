import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/soundpad_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../theme/dm_tool_colors.dart';

/// Player için sade soundmap sidebar — DM'in tetiklediği tema/parçayı
/// görüntüler ve sadece **master volume** ayarına izin verir. Track
/// seçimi, play/pause, upload yok.
class SoundmapPlayerSidebar extends ConsumerWidget {
  final DmToolColors palette;
  const SoundmapPlayerSidebar({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(soundpadStateProvider);
    final notifier = ref.read(soundpadStateProvider.notifier);
    final volume = ref.watch(uiStateProvider.select((s) => s.volume));
    final theme = state.activeThemeId == null
        ? null
        : notifier.themes[state.activeThemeId];
    final themeName = theme?.name ?? state.activeThemeId ?? 'No theme';
    final musicTitle = state.musicPlaying
        ? (state.activeStateName ?? 'Playing')
        : 'Stopped';

    return Container(
      color: palette.tabBg,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: palette.sidebarDivider)),
            ),
            child: Row(
              children: [
                Icon(Icons.headphones,
                    size: 18, color: palette.tabActiveText),
                const SizedBox(width: 8),
                Text('Soundmap',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    )),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.musicPlaying
                              ? palette.successBtnBg
                              : palette.sidebarLabelSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.musicPlaying ? 'Playing' : 'Stopped',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: state.musicPlaying
                                ? palette.successBtnBg
                                : palette.sidebarLabelSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Theme',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    themeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Now playing',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    musicTitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.tabActiveText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Volume slider — yalnızca master output. DM'in track seçimi
          // değişmez, sadece bu cihazın output ses seviyesi.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.tabBg,
              border: Border(top: BorderSide(color: palette.sidebarDivider)),
            ),
            child: Row(
              children: [
                Icon(Icons.volume_down,
                    size: 18, color: palette.tabActiveText),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (v) => ref
                        .read(uiStateProvider.notifier)
                        .update((s) => s.copyWith(volume: v)),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(volume * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11, color: palette.tabActiveText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
