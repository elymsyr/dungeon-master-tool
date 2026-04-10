import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/soundpad_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../data/services/soundpad_engine.dart';
import '../../domain/entities/audio/audio_models.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Sağ sidebar veya mobil tab olarak gösterilen Soundpad paneli.
/// 3 tab: Music, Ambience, SFX + alt kısımda global kontroller.
class SoundmapSidebar extends ConsumerStatefulWidget {
  final DmToolColors palette;

  const SoundmapSidebar({super.key, required this.palette});

  @override
  ConsumerState<SoundmapSidebar> createState() => _SoundmapSidebarState();
}

class _SoundmapSidebarState extends ConsumerState<SoundmapSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = L10n.of(context)!;

    return Column(
      children: [
        // Tab bar
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: palette.tabBg,
            border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: palette.tabActiveText,
            unselectedLabelColor: palette.tabText,
            indicatorColor: palette.featureCardAccent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            dividerHeight: 0,
            tabs: [
              Tab(text: l10n.soundpadTabMusic),
              Tab(text: l10n.soundpadTabAmbience),
              Tab(text: l10n.soundpadTabSfx),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _MusicTab(palette: palette),
              _AmbienceTab(palette: palette),
              _SfxTab(palette: palette),
            ],
          ),
        ),

        // Global controls — her zaman görünür
        _GlobalControls(palette: palette),
      ],
    );
  }
}

// =============================================================================
// Music Tab
// =============================================================================

class _MusicTab extends ConsumerWidget {
  final DmToolColors palette;
  const _MusicTab({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final soundpadState = ref.watch(soundpadStateProvider);
    final notifier = ref.read(soundpadStateProvider.notifier);
    final themesAsync = ref.watch(soundpadThemesProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Theme selector
          themesAsync.when(
            data: (themes) => _ThemeSelector(
              themes: themes,
              activeThemeId: soundpadState.activeThemeId,
              palette: palette,
              l10n: l10n,
              onSelect: notifier.selectTheme,
            ),
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('Error: $e', style: TextStyle(color: palette.tokenBorderHostile)),
          ),

          const SizedBox(height: 16),

          // State buttons (tema seçildiyse)
          if (soundpadState.activeThemeId != null)
            ..._buildStateSection(context, ref, soundpadState, notifier),

          // Intensity slider (tema seçildiyse)
          if (soundpadState.activeThemeId != null) ...[
            const SizedBox(height: 16),
            _IntensitySlider(
              level: soundpadState.intensityLevel,
              palette: palette,
              l10n: l10n,
              onChanged: notifier.setIntensity,
            ),
          ],

          const Spacer(),

          // Tema yoksa bilgi
          if (soundpadState.activeThemeId == null)
            Center(
              child: Column(
                children: [
                  Icon(Icons.music_note, size: 48, color: palette.tabText.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.soundpadNoThemes,
                    style: TextStyle(fontSize: 12, color: palette.tabText.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildStateSection(
    BuildContext context,
    WidgetRef ref,
    SoundpadState soundpadState,
    SoundpadNotifier notifier,
  ) {
    final l10n = L10n.of(context)!;
    final themes = ref.read(soundpadThemesProvider).valueOrNull ?? {};
    final theme = themes[soundpadState.activeThemeId];
    if (theme == null) return [];

    return [
      Text(
        l10n.soundpadMusicState,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: theme.states.keys.map((stateName) {
          final isActive = stateName == soundpadState.activeStateName;
          return ChoiceChip(
            label: Text(
              stateName[0].toUpperCase() + stateName.substring(1),
              style: TextStyle(fontSize: 12, color: isActive ? Colors.white : palette.tabActiveText),
            ),
            selected: isActive,
            selectedColor: palette.featureCardAccent,
            backgroundColor: palette.tabBg,
            side: BorderSide(color: isActive ? palette.featureCardAccent : palette.sidebarDivider),
            onSelected: (_) => notifier.selectState(stateName),
          );
        }).toList(),
      ),
    ];
  }
}

// =============================================================================
// Theme Selector
// =============================================================================

class _ThemeSelector extends StatelessWidget {
  final Map<String, SoundpadTheme> themes;
  final String? activeThemeId;
  final DmToolColors palette;
  final L10n l10n;
  final ValueChanged<String?> onSelect;

  const _ThemeSelector({
    required this.themes,
    required this.activeThemeId,
    required this.palette,
    required this.l10n,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: activeThemeId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.soundpadSelectTheme,
        labelStyle: TextStyle(fontSize: 13, color: palette.tabText),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.sidebarDivider),
        ),
      ),
      dropdownColor: palette.canvasBg,
      style: TextStyle(fontSize: 13, color: palette.tabActiveText),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('-- ${l10n.soundpadSelectTheme} --', style: TextStyle(color: palette.tabText)),
        ),
        ...themes.entries.map((e) => DropdownMenuItem<String?>(
              value: e.key,
              child: Text(e.value.name),
            )),
      ],
      onChanged: onSelect,
    );
  }
}

// =============================================================================
// Intensity Slider
// =============================================================================

class _IntensitySlider extends StatelessWidget {
  final int level;
  final DmToolColors palette;
  final L10n l10n;
  final ValueChanged<int> onChanged;

  const _IntensitySlider({
    required this.level,
    required this.palette,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      l10n.soundpadIntensityBase,
      l10n.soundpadIntensityLow,
      l10n.soundpadIntensityMedium,
      l10n.soundpadIntensityHigh,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.soundpadIntensity,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: level.toDouble(),
                min: 0,
                max: 3,
                divisions: 3,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                labels[level],
                style: TextStyle(fontSize: 11, color: palette.tabText),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Ambience Tab
// =============================================================================

class _AmbienceTab extends ConsumerWidget {
  final DmToolColors palette;
  const _AmbienceTab({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final soundpadState = ref.watch(soundpadStateProvider);
    final notifier = ref.read(soundpadStateProvider.notifier);
    final libraryAsync = ref.watch(soundpadLibraryProvider);

    return libraryAsync.when(
      data: (library) => Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: SoundpadEngine.ambienceSlotCount,
              itemBuilder: (context, i) => _AmbienceSlotCard(
                key: ValueKey(i),
                index: i,
                slotState: soundpadState.ambienceSlots[i],
                ambienceList: library.ambience,
                palette: palette,
                l10n: l10n,
                onSelectId: (id) => notifier.setAmbienceSlot(i, id),
                onVolumeChanged: (v) => notifier.setAmbienceVolume(i, v),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

}

// =============================================================================
// Ambience Slot Card
// =============================================================================

class _AmbienceSlotCard extends StatelessWidget {
  final int index;
  final AmbienceSlotState slotState;
  final List<AmbienceEntry> ambienceList;
  final DmToolColors palette;
  final L10n l10n;
  final ValueChanged<String?> onSelectId;
  final ValueChanged<double> onVolumeChanged;

  const _AmbienceSlotCard({
    super.key,
    required this.index,
    required this.slotState,
    required this.ambienceList,
    required this.palette,
    required this.l10n,
    required this.onSelectId,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: palette.tabBg,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.soundpadAmbienceSlot} ${index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.tabText),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: slotState.ambienceId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: palette.sidebarDivider),
                ),
              ),
              dropdownColor: palette.canvasBg,
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.soundpadSilence, style: TextStyle(color: palette.tabText)),
                ),
                ...ambienceList.map((a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(a.name),
                    )),
              ],
              onChanged: onSelectId,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.volume_down, size: 14, color: palette.tabText),
                Expanded(
                  child: Slider(
                    value: slotState.volume,
                    onChanged: onVolumeChanged,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${(slotState.volume * 100).round()}%',
                    style: TextStyle(fontSize: 10, color: palette.tabText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SFX Tab
// =============================================================================

class _SfxTab extends ConsumerWidget {
  final DmToolColors palette;
  const _SfxTab({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(soundpadStateProvider.notifier);
    final libraryAsync = ref.watch(soundpadLibraryProvider);

    return libraryAsync.when(
      data: (library) => Column(
        children: [
          Expanded(
            child: library.sfx.isEmpty
                ? Center(
                    child: Text(
                      'No SFX available',
                      style: TextStyle(fontSize: 12, color: palette.tabText.withValues(alpha: 0.5)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: library.sfx.length,
                    itemBuilder: (context, i) {
                      final sfx = library.sfx[i];
                      return _SfxButton(
                        sfx: sfx,
                        palette: palette,
                        onTap: () => notifier.playSfx(sfx.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

}

// =============================================================================
// SFX Button
// =============================================================================

class _SfxButton extends StatelessWidget {
  final SfxEntry sfx;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _SfxButton({required this.sfx, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.tabBg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.sidebarDivider),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            sfx.name,
            style: TextStyle(fontSize: 12, color: palette.tabActiveText),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Global Controls
// =============================================================================

class _GlobalControls extends ConsumerWidget {
  final DmToolColors palette;
  const _GlobalControls({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final notifier = ref.read(soundpadStateProvider.notifier);
    final volume = ref.watch(uiStateProvider.select((s) => s.volume));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(top: BorderSide(color: palette.sidebarDivider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Master volume
          Row(
            children: [
              Icon(Icons.volume_down, size: 16, color: palette.tabText),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: (v) => ref.read(uiStateProvider.notifier).update((s) => s.copyWith(volume: v)),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${(volume * 100).round()}%',
                  style: TextStyle(fontSize: 10, color: palette.tabText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Stop buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: notifier.stopAmbience,
                  child: Text(l10n.soundpadStopAmbience, style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: notifier.stopAll,
                  style: FilledButton.styleFrom(backgroundColor: palette.tokenBorderHostile),
                  child: Text(l10n.soundpadStopAll, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
