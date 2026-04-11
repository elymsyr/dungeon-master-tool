import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/projection_provider.dart';
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

/// Mobile battle map toolbar — persistent mini bar at the bottom with an
/// expand button that opens a modal bottom sheet with 3 tabs (Tools, Grid, View).
class BattleMapMobileToolbar extends ConsumerWidget {
  final String encounterId;

  const BattleMapMobileToolbar({required this.encounterId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
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
      height: 44,
      color: palette.tabBg,
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Quick tool buttons — 4 most common tools
          _MiniToolButton(
            tool: BattleMapTool.navigate,
            icon: Icons.pan_tool_outlined,
            activeTool: tb.activeTool,
            palette: palette,
            onTap: () => notifier.setTool(BattleMapTool.navigate),
          ),
          _MiniToolButton(
            tool: BattleMapTool.draw,
            icon: Icons.edit_outlined,
            activeTool: tb.activeTool,
            palette: palette,
            onTap: () => notifier.setTool(BattleMapTool.draw),
          ),
          _MiniToolButton(
            tool: BattleMapTool.fogAdd,
            icon: Icons.cloud,
            activeTool: tb.activeTool,
            palette: palette,
            onTap: () => notifier.setTool(BattleMapTool.fogAdd),
          ),
          _MiniToolButton(
            tool: BattleMapTool.fogErase,
            icon: Icons.cloud_off,
            activeTool: tb.activeTool,
            palette: palette,
            onTap: () => notifier.setTool(BattleMapTool.fogErase),
          ),
          const SizedBox(width: 4),
          // Cast / project to player screen
          InkWell(
            onTap: () async {
              final encounter = ref
                  .read(combatProvider)
                  .encounters
                  .where((e) => e.id == encounterId)
                  .firstOrNull;
              if (encounter == null) return;
              await ref
                  .read(projectionControllerProvider.notifier)
                  .addBattleMap(
                    encounterId: encounterId,
                    label: encounter.name.isEmpty
                        ? 'Battle Map'
                        : encounter.name,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  duration: Duration(seconds: 2),
                  content: Text('Battle map projected'),
                ));
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.cast, size: 18, color: palette.tabText),
            ),
          ),
          const Spacer(),
          // Expand button — opens full bottom sheet
          InkWell(
            onTap: () => _showFullSheet(context, encounterId),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(Icons.expand_less, size: 22, color: palette.tabText),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showFullSheet(BuildContext context, String encounterId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullBottomSheet(encounterId: encounterId),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini toolbar tool button (highlights when active)
// ---------------------------------------------------------------------------

class _MiniToolButton extends StatelessWidget {
  final BattleMapTool tool;
  final IconData icon;
  final BattleMapTool activeTool;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _MiniToolButton({
    required this.tool,
    required this.icon,
    required this.activeTool,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeTool == tool;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Full bottom sheet with 3 tabs
// ---------------------------------------------------------------------------

class _FullBottomSheet extends ConsumerStatefulWidget {
  final String encounterId;

  const _FullBottomSheet({required this.encounterId});

  @override
  ConsumerState<_FullBottomSheet> createState() => _FullBottomSheetState();
}

class _FullBottomSheetState extends ConsumerState<_FullBottomSheet>
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
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final tb = ref.watch(battleMapProvider(widget.encounterId).select((s) => (
      activeTool: s.activeTool,
      gridVisible: s.gridVisible,
      gridSnap: s.gridSnap,
      gridSize: s.gridSize,
      feetPerCell: s.feetPerCell,
      tokenSize: s.tokenSize,
    )));
    final notifier = ref.read(battleMapProvider(widget.encounterId).notifier);

    return Container(
      decoration: BoxDecoration(
        color: palette.tabBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: palette.sidebarDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: palette.tabIndicator,
            labelColor: palette.tabActiveText,
            unselectedLabelColor: palette.tabText,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            dividerColor: palette.sidebarDivider,
            tabs: const [
              Tab(text: 'Tools', height: 32),
              Tab(text: 'Grid', height: 32),
              Tab(text: 'View', height: 32),
            ],
          ),

          // Tab content
          SizedBox(
            height: 180,
            child: TabBarView(
              controller: _tabController,
              children: [
                _ToolsTab(tb: tb, notifier: notifier, palette: palette),
                _GridTab(tb: tb, notifier: notifier, palette: palette),
                _ViewTab(tb: tb, notifier: notifier, palette: palette),
              ],
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Tools — all 6 tools + fog actions + draw actions
// ---------------------------------------------------------------------------

class _ToolsTab extends StatelessWidget {
  final _ToolbarState tb;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  const _ToolsTab({
    required this.tb,
    required this.notifier,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool grid — 6 tools in a row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SheetToolButton(tool: BattleMapTool.navigate, icon: Icons.pan_tool_outlined, label: 'Navigate', tb: tb, notifier: notifier, palette: palette),
              _SheetToolButton(tool: BattleMapTool.ruler, icon: Icons.straighten, label: 'Ruler', tb: tb, notifier: notifier, palette: palette),
              _SheetToolButton(tool: BattleMapTool.circle, icon: Icons.radio_button_unchecked, label: 'Circle', tb: tb, notifier: notifier, palette: palette),
              _SheetToolButton(tool: BattleMapTool.draw, icon: Icons.edit_outlined, label: 'Draw', tb: tb, notifier: notifier, palette: palette),
              _SheetToolButton(tool: BattleMapTool.fogAdd, icon: Icons.cloud, label: 'Add Fog', tb: tb, notifier: notifier, palette: palette),
              _SheetToolButton(tool: BattleMapTool.fogErase, icon: Icons.cloud_off, label: 'Erase Fog', tb: tb, notifier: notifier, palette: palette),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.sidebarDivider),
          const SizedBox(height: 8),
          // Action buttons row
          Row(
            children: [
              _SheetActionButton(icon: Icons.cloud_queue, label: 'Fill Fog', palette: palette, onTap: () async { await notifier.fillFog(); }),
              const SizedBox(width: 8),
              _SheetActionButton(icon: Icons.wb_sunny_outlined, label: 'Clear Fog', palette: palette, onTap: () async { await notifier.clearFog(); }),
              const SizedBox(width: 8),
              _SheetActionButton(icon: Icons.cleaning_services_outlined, label: 'Clear Draw', palette: palette, onTap: notifier.clearAnnotation),
              const SizedBox(width: 8),
              _SheetActionButton(icon: Icons.straighten_outlined, label: 'Clear Rulers', palette: palette, onTap: notifier.clearMeasurements),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Grid — toggle, cell size, snap, feet/cell
// ---------------------------------------------------------------------------

class _GridTab extends StatelessWidget {
  final _ToolbarState tb;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  const _GridTab({
    required this.tb,
    required this.notifier,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Grid visible toggle
          _SwitchRow(
            label: 'Grid Visible',
            value: tb.gridVisible,
            palette: palette,
            onChanged: notifier.setGridVisible,
          ),
          const SizedBox(height: 12),
          // Grid cell size
          _SpinBoxRow(
            label: 'Cell Size',
            suffix: 'px',
            value: tb.gridSize,
            min: 10,
            max: 300,
            palette: palette,
            onChanged: notifier.setGridSize,
          ),
          const SizedBox(height: 12),
          // Snap toggle
          _SwitchRow(
            label: 'Snap to Grid',
            value: tb.gridSnap,
            palette: palette,
            onChanged: notifier.setGridSnap,
          ),
          const SizedBox(height: 12),
          // Feet per cell
          _SpinBoxRow(
            label: 'Feet / Cell',
            suffix: 'ft',
            value: tb.feetPerCell,
            min: 1,
            max: 100,
            palette: palette,
            onChanged: notifier.setFeetPerCell,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: View — reset view, map picker, token size slider
// ---------------------------------------------------------------------------

class _ViewTab extends StatelessWidget {
  final _ToolbarState tb;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  const _ViewTab({
    required this.tb,
    required this.notifier,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Action buttons row
          Row(
            children: [
              _SheetActionButton(
                icon: Icons.fit_screen,
                label: 'Reset View',
                palette: palette,
                onTap: notifier.resetView,
              ),
              const SizedBox(width: 8),
              _SheetActionButton(
                icon: Icons.image_outlined,
                label: 'Open Map',
                palette: palette,
                onTap: () async { await notifier.pickMapImage(context); },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Token size slider
          Row(
            children: [
              Text(
                'Token Size',
                style: TextStyle(fontSize: 12, color: palette.tabText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: palette.tabIndicator,
                    thumbColor: palette.tabIndicator,
                    overlayColor: palette.tabIndicator.withValues(alpha: 0.2),
                    inactiveTrackColor: palette.sidebarDivider,
                  ),
                  child: Slider(
                    value: tb.tokenSize.toDouble(),
                    min: 20,
                    max: 300,
                    onChanged: (v) => notifier.setGlobalTokenSize(v.round()),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${tb.tokenSize}px',
                style: TextStyle(fontSize: 11, color: palette.tabText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bottom sheet components
// ---------------------------------------------------------------------------

/// Tool button for the full sheet — icon + label, highlighted when active.
class _SheetToolButton extends StatelessWidget {
  final BattleMapTool tool;
  final IconData icon;
  final String label;
  final _ToolbarState tb;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  const _SheetToolButton({
    required this.tool,
    required this.icon,
    required this.label,
    required this.tb,
    required this.notifier,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tb.activeTool == tool;
    return InkWell(
      onTap: () => notifier.setTool(tool),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? palette.tabIndicator.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: palette.tabIndicator, width: 1) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? palette.tabIndicator : palette.tabText),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? palette.tabIndicator : palette.tabText,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic action button — icon + label, no active state.
class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final DmToolColors palette;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: palette.sidebarDivider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.tabText),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: palette.tabText)),
          ],
        ),
      ),
    );
  }
}

/// Row with label + switch toggle.
class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final DmToolColors palette;
  final void Function(bool) onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: palette.tabText)),
        ),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.tabIndicator,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

/// Row with label + spinbox + suffix.
class _SpinBoxRow extends StatelessWidget {
  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final DmToolColors palette;
  final void Function(int) onChanged;

  const _SpinBoxRow({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: palette.tabText)),
        ),
        _MobileSpinBox(value: value, min: min, max: max, palette: palette, onChanged: onChanged),
        const SizedBox(width: 4),
        Text(suffix, style: TextStyle(fontSize: 11, color: palette.tabText.withValues(alpha: 0.6))),
      ],
    );
  }
}

/// Compact integer spinbox for mobile — slightly larger tap targets than desktop.
class _MobileSpinBox extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final DmToolColors palette;
  final void Function(int) onChanged;

  const _MobileSpinBox({
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: palette.sidebarDivider),
        borderRadius: BorderRadius.circular(4),
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
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
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
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          icon,
          size: 14,
          color: onPressed != null ? palette.tabText : palette.tabText.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
