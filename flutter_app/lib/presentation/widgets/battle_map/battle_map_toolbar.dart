import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/battle_map/battle_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';

typedef _ToolbarState = ({
  BattleMapTool activeTool,
  bool gridVisible,
  bool gridSnap,
  int gridSize,
  int feetPerCell,
  int tokenSize,
});

/// DM battle map toolbar — 3 rows:
/// Row 1: View controls (reset, token size slider, map image picker)
/// Row 2: Tool selector + fog/draw action buttons
/// Row 3: Grid controls
class BattleMapToolbar extends ConsumerWidget {
  final String encounterId;

  const BattleMapToolbar({required this.encounterId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // Selective watch — only rebuild when toolbar-relevant fields change,
    // not on pan/zoom/token moves/fog/annotation/measurements.
    final tb = ref.watch(battleMapProvider(encounterId).select((s) => (
      activeTool: s.activeTool,
      gridVisible: s.gridVisible,
      gridSnap: s.gridSnap,
      gridSize: s.gridSize,
      feetPerCell: s.feetPerCell,
      tokenSize: s.tokenSize,
    )));
    final notifier = ref.read(battleMapProvider(encounterId).notifier);

    return Container(
      color: palette.tabBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow1(context, palette, tb, notifier),
          Divider(height: 1, color: palette.sidebarDivider),
          _buildRow2(context, palette, tb, notifier),
          Divider(height: 1, color: palette.sidebarDivider),
          _buildRow3(context, palette, tb, notifier),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Row 1: View + Token Size + Map Picker
  // -------------------------------------------------------------------------

  Widget _buildRow1(BuildContext context, DmToolColors palette, _ToolbarState mapState, BattleMapNotifier notifier) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Reset view
          _ToolbarButton(
            icon: Icons.fit_screen,
            tooltip: 'Reset View',
            palette: palette,
            onPressed: notifier.resetView,
          ),
          const SizedBox(width: 8),
          // Map image picker
          _ToolbarButton(
            icon: Icons.image_outlined,
            tooltip: 'Open Map Image',
            palette: palette,
            onPressed: () async { await notifier.pickMapImage(); },
          ),
          const SizedBox(width: 12),
          // Token size label
          Text(
            'Token:',
            style: TextStyle(fontSize: 11, color: palette.tabText),
          ),
          const SizedBox(width: 4),
          // Token size slider
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: palette.tabIndicator,
                thumbColor: palette.tabIndicator,
                overlayColor: palette.tabIndicator.withValues(alpha: 0.2),
                inactiveTrackColor: palette.sidebarDivider,
              ),
              child: Slider(
                value: mapState.tokenSize.toDouble(),
                min: 20,
                max: 300,
                onChanged: (v) => notifier.setGlobalTokenSize(v.round()),
              ),
            ),
          ),
          Text(
            '${mapState.tokenSize}px',
            style: TextStyle(fontSize: 11, color: palette.tabText),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Row 2: Tool selector + fog/draw actions
  // -------------------------------------------------------------------------

  Widget _buildRow2(BuildContext context, DmToolColors palette, _ToolbarState mapState, BattleMapNotifier notifier) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Tool buttons
          _ToolButton(tool: BattleMapTool.navigate, icon: Icons.pan_tool_outlined, tooltip: 'Navigate', mapState: mapState, notifier: notifier, palette: palette),
          _ToolButton(tool: BattleMapTool.ruler, icon: Icons.straighten, tooltip: 'Ruler', mapState: mapState, notifier: notifier, palette: palette),
          _ToolButton(tool: BattleMapTool.circle, icon: Icons.radio_button_unchecked, tooltip: 'Circle', mapState: mapState, notifier: notifier, palette: palette),
          _ToolButton(tool: BattleMapTool.draw, icon: Icons.edit_outlined, tooltip: 'Draw', mapState: mapState, notifier: notifier, palette: palette),
          _ToolButton(tool: BattleMapTool.fogAdd, icon: Icons.cloud, tooltip: 'Add Fog', mapState: mapState, notifier: notifier, palette: palette),
          _ToolButton(tool: BattleMapTool.fogErase, icon: Icons.cloud_off, tooltip: 'Erase Fog', mapState: mapState, notifier: notifier, palette: palette),
          // Separator
          Container(width: 1, height: 24, color: palette.sidebarDivider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          // Fog actions
          _ToolbarButton(
            icon: Icons.cloud_queue,
            tooltip: 'Fill Fog',
            palette: palette,
            onPressed: () async { await notifier.fillFog(); },
          ),
          _ToolbarButton(
            icon: Icons.wb_sunny_outlined,
            tooltip: 'Clear Fog',
            palette: palette,
            onPressed: () async { await notifier.clearFog(); },
          ),
          // Separator
          Container(width: 1, height: 24, color: palette.sidebarDivider, margin: const EdgeInsets.symmetric(horizontal: 6)),
          // Draw actions
          _ToolbarButton(
            icon: Icons.cleaning_services_outlined,
            tooltip: 'Clear Drawing',
            palette: palette,
            onPressed: notifier.clearAnnotation,
          ),
          _ToolbarButton(
            icon: Icons.straighten_outlined,
            tooltip: 'Clear Rulers',
            palette: palette,
            onPressed: notifier.clearMeasurements,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Row 3: Grid controls
  // -------------------------------------------------------------------------

  Widget _buildRow3(BuildContext context, DmToolColors palette, _ToolbarState mapState, BattleMapNotifier notifier) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Grid toggle
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: mapState.gridVisible,
                  onChanged: (v) => notifier.setGridVisible(v ?? false),
                  activeColor: palette.tabIndicator,
                  side: BorderSide(color: palette.tabText.withValues(alpha: 0.5)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Text('Grid', style: TextStyle(fontSize: 12, color: palette.tabText)),
            ],
          ),
          const SizedBox(width: 12),
          // Grid size
          Text('Cell:', style: TextStyle(fontSize: 12, color: palette.tabText)),
          const SizedBox(width: 4),
          _SpinBox(
            value: mapState.gridSize,
            min: 10,
            max: 300,
            palette: palette,
            onChanged: notifier.setGridSize,
          ),
          Text('px', style: TextStyle(fontSize: 11, color: palette.tabText.withValues(alpha: 0.6))),
          const SizedBox(width: 12),
          // Snap toggle
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: mapState.gridSnap,
                  onChanged: (v) => notifier.setGridSnap(v ?? false),
                  activeColor: palette.tabIndicator,
                  side: BorderSide(color: palette.tabText.withValues(alpha: 0.5)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Text('Snap', style: TextStyle(fontSize: 12, color: palette.tabText)),
            ],
          ),
          const SizedBox(width: 12),
          // Feet per cell
          Text('Ft/cell:', style: TextStyle(fontSize: 12, color: palette.tabText)),
          const SizedBox(width: 4),
          _SpinBox(
            value: mapState.feetPerCell,
            min: 1,
            max: 100,
            palette: palette,
            onChanged: notifier.setFeetPerCell,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable toolbar button
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final DmToolColors palette;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Icon(icon, size: 18, color: palette.tabText),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool toggle button (highlights when active)
// ---------------------------------------------------------------------------

class _ToolButton extends StatelessWidget {
  final BattleMapTool tool;
  final IconData icon;
  final String tooltip;
  final _ToolbarState mapState;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.mapState,
    required this.notifier,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = mapState.activeTool == tool;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => notifier.setTool(tool),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? palette.tabIndicator.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(4),
            border: isActive ? Border.all(color: palette.tabIndicator, width: 1) : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? palette.tabIndicator : palette.tabText,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact integer spinbox
// ---------------------------------------------------------------------------

class _SpinBox extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final DmToolColors palette;
  final void Function(int) onChanged;

  const _SpinBox({
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(color: palette.sidebarDivider),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SpinBtn(
            icon: Icons.remove,
            onPressed: value > min ? () => onChanged(value - 1) : null,
            palette: palette,
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 11, color: palette.tabActiveText),
            ),
          ),
          _SpinBtn(
            icon: Icons.add,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _SpinBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final DmToolColors palette;

  const _SpinBtn({required this.icon, required this.onPressed, required this.palette});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 12, color: onPressed != null ? palette.tabText : palette.tabText.withValues(alpha: 0.3)),
      ),
    );
  }
}
