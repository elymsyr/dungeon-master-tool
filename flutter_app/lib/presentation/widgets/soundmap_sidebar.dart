import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/soundpad_provider.dart';
import '../../application/providers/ui_state_provider.dart';
import '../../data/services/soundpad_engine.dart';
import '../../domain/entities/audio/audio_models.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Sağ sidebar veya mobil tab olarak gösterilen Soundpad paneli.
/// Tek scroll: Music → SFX → Ambience + alt global controls.
class SoundmapSidebar extends ConsumerWidget {
  final DmToolColors palette;

  const SoundmapSidebar({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(label: l10n.soundpadTabMusic, palette: palette),
                _MusicSection(palette: palette),
                _SectionHeader(label: l10n.soundpadTabSfx, palette: palette),
                _SfxSection(palette: palette),
                _SectionHeader(label: l10n.soundpadTabAmbience, palette: palette),
                _AmbienceSection(palette: palette),
              ],
            ),
          ),
        ),
        _GlobalControls(palette: palette),
      ],
    );
  }
}

// =============================================================================
// Section Header / Divider
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  final DmToolColors palette;

  const _SectionHeader({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.featureCardAccent,
        ),
      ),
    );
  }
}

// =============================================================================
// Music Section
// =============================================================================

class _MusicSection extends ConsumerWidget {
  final DmToolColors palette;
  const _MusicSection({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final activeThemeId =
        ref.watch(soundpadStateProvider.select((s) => s.activeThemeId));
    final intensityLevel =
        ref.watch(soundpadStateProvider.select((s) => s.intensityLevel));
    final notifier = ref.read(soundpadStateProvider.notifier);
    final themesAsync = ref.watch(soundpadThemesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          themesAsync.when(
            data: (themes) => _ThemeSelector(
              themes: themes,
              activeThemeId: activeThemeId,
              palette: palette,
              l10n: l10n,
              onSelect: notifier.selectTheme,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: palette.tokenBorderHostile)),
          ),
          if (activeThemeId != null) ...[
            const SizedBox(height: 12),
            _StateSection(activeThemeId: activeThemeId, palette: palette),
            const SizedBox(height: 12),
            _IntensitySlider(
              level: intensityLevel,
              palette: palette,
              l10n: l10n,
              onChanged: notifier.setIntensity,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.soundpadNoThemes,
                style: TextStyle(
                    fontSize: 12,
                    color: palette.tabText.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StateSection extends ConsumerWidget {
  final String activeThemeId;
  final DmToolColors palette;
  const _StateSection({required this.activeThemeId, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final activeStateName =
        ref.watch(soundpadStateProvider.select((s) => s.activeStateName));
    final themes = ref.watch(soundpadThemesProvider).valueOrNull ?? {};
    final theme = themes[activeThemeId];
    if (theme == null) return const SizedBox.shrink();
    final notifier = ref.read(soundpadStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.soundpadMusicState,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: theme.states.keys.map((stateName) {
            final isActive = stateName == activeStateName;
            return ChoiceChip(
              label: Text(
                stateName[0].toUpperCase() + stateName.substring(1),
                style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              ),
              selected: isActive,
              selectedColor: palette.featureCardAccent,
              backgroundColor: palette.tabBg,
              side: BorderSide(
                  color: isActive
                      ? palette.featureCardAccent
                      : palette.sidebarDivider),
              onSelected: (_) => notifier.selectState(stateName),
            );
          }).toList(),
        ),
      ],
    );
  }
}

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
      initialValue: activeThemeId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.soundpadSelectTheme,
        labelStyle: TextStyle(fontSize: 13, color: palette.tabText),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: palette.br),
        enabledBorder: OutlineInputBorder(
          borderRadius: palette.br,
          borderSide: BorderSide(color: palette.sidebarDivider),
        ),
      ),
      dropdownColor: palette.canvasBg,
      style: TextStyle(fontSize: 13, color: palette.tabActiveText),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('-- ${l10n.soundpadSelectTheme} --',
              style: TextStyle(color: palette.tabText)),
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
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.tabActiveText),
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
// SFX Section
// =============================================================================

class _SfxSection extends ConsumerWidget {
  final DmToolColors palette;
  const _SfxSection({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(soundpadStateProvider.notifier);
    final libraryAsync = ref.watch(soundpadLibraryProvider);

    return libraryAsync.when(
      data: (library) {
        if (library.sfx.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              'No SFX available',
              style: TextStyle(
                  fontSize: 12, color: palette.tabText.withValues(alpha: 0.5)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $e'),
      ),
    );
  }
}

class _SfxButton extends StatelessWidget {
  final SfxEntry sfx;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _SfxButton(
      {required this.sfx, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.tabBg,
      borderRadius: palette.cbr,
      child: InkWell(
        borderRadius: palette.cbr,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: palette.cbr,
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
// Ambience Section
// =============================================================================

class _AmbienceSection extends ConsumerWidget {
  final DmToolColors palette;
  const _AmbienceSection({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ambienceSlots =
        ref.watch(soundpadStateProvider.select((s) => s.ambienceSlots));
    final notifier = ref.read(soundpadStateProvider.notifier);
    final libraryAsync = ref.watch(soundpadLibraryProvider);

    return libraryAsync.when(
      data: (library) {
        final filled = <MapEntry<int, AmbienceSlotState>>[];
        for (var i = 0; i < ambienceSlots.length; i++) {
          if (ambienceSlots[i].ambienceId != null) {
            filled.add(MapEntry(i, ambienceSlots[i]));
          }
        }
        final canAdd = filled.length < SoundpadEngine.ambienceSlotCount;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...filled.map((entry) {
                final idx = entry.key;
                final slot = entry.value;
                final ambience = library.ambience.firstWhere(
                  (a) => a.id == slot.ambienceId,
                  orElse: () => AmbienceEntry(
                      id: slot.ambienceId!,
                      name: slot.ambienceId!,
                      files: const []),
                );
                return _AmbienceCompactRow(
                  key: ValueKey('amb-$idx-${slot.ambienceId}'),
                  name: ambience.name,
                  volume: slot.volume,
                  palette: palette,
                  onVolumeChanged: (v) => notifier.setAmbienceVolume(idx, v),
                  onClear: () => notifier.setAmbienceSlot(idx, null),
                );
              }),
              if (canAdd) ...[
                if (filled.isNotEmpty) const SizedBox(height: 4),
                _AddAmbienceButton(
                  ambienceList: library.ambience,
                  usedIds: filled
                      .map((e) => e.value.ambienceId!)
                      .toSet(),
                  palette: palette,
                  onPick: (pickedId) {
                    final emptyIdx = ambienceSlots
                        .indexWhere((s) => s.ambienceId == null);
                    if (emptyIdx >= 0) {
                      notifier.setAmbienceSlot(emptyIdx, pickedId);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $e'),
      ),
    );
  }
}

class _AmbienceCompactRow extends StatelessWidget {
  final String name;
  final double volume;
  final DmToolColors palette;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onClear;

  const _AmbienceCompactRow({
    super.key,
    required this.name,
    required this.volume,
    required this.palette,
    required this.onVolumeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.tabBg,
        borderRadius: palette.cbr,
        border: Border.all(color: palette.sidebarDivider),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 14, color: palette.tabText),
          const SizedBox(width: 6),
          SizedBox(
            width: 78,
            child: Text(
              name,
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: volume,
                onChanged: onVolumeChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${(volume * 100).round()}%',
              style: TextStyle(fontSize: 10, color: palette.tabText),
              textAlign: TextAlign.end,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
            color: palette.tabText,
            onPressed: onClear,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _AddAmbienceButton extends StatelessWidget {
  final List<AmbienceEntry> ambienceList;
  final Set<String> usedIds;
  final DmToolColors palette;
  final ValueChanged<String> onPick;

  const _AddAmbienceButton({
    required this.ambienceList,
    required this.usedIds,
    required this.palette,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        ambienceList.where((a) => !usedIds.contains(a.id)).toList();
    final enabled = available.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: 'Add ambience',
        color: palette.canvasBg,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => available
            .map((a) => PopupMenuItem<String>(
                  value: a.id,
                  child: Text(
                    a.name,
                    style: TextStyle(
                        fontSize: 13, color: palette.tabActiveText),
                  ),
                ))
            .toList(),
        onSelected: onPick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.tabBg,
            borderRadius: palette.cbr,
            border: Border.all(color: palette.sidebarDivider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add,
                  size: 16,
                  color: enabled
                      ? palette.tabActiveText
                      : palette.tabText.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Add ambience',
                style: TextStyle(
                  fontSize: 12,
                  color: enabled
                      ? palette.tabActiveText
                      : palette.tabText.withValues(alpha: 0.4),
                ),
              ),
            ],
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
      child: Row(
        children: [
          Icon(Icons.volume_down, size: 16, color: palette.tabText),
          Expanded(
            child: Slider(
              value: volume,
              onChanged: (v) => ref
                  .read(uiStateProvider.notifier)
                  .update((s) => s.copyWith(volume: v)),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${(volume * 100).round()}%',
              style: TextStyle(fontSize: 10, color: palette.tabText),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: l10n.soundpadStopAll,
            child: Material(
              color: palette.tokenBorderHostile,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: notifier.stopAll,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.stop, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
