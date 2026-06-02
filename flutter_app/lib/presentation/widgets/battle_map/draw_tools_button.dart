import 'package:flutter/material.dart';

import '../../screens/battle_map/battle_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';

/// All the measure / AoE / vector-shape tools merged into a single toolbar
/// button. Tapping it opens an icon-only grid (3 per row) of every tool;
/// picking one selects it and the button's icon becomes that tool — so the
/// toolbar stays compact while remembering the last tool used.
const List<(BattleMapTool, IconData, String)> kDrawTools = [
  (BattleMapTool.ruler, Icons.straighten, 'Ruler'),
  (BattleMapTool.circle, Icons.radio_button_unchecked, 'Circle'),
  (BattleMapTool.aoeCone, Icons.change_history, 'Cone (AoE)'),
  (BattleMapTool.aoeLine, Icons.horizontal_rule, 'Line (AoE)'),
  (BattleMapTool.aoeCircle, Icons.lens, 'Sphere (AoE)'),
  (BattleMapTool.aoeSquare, Icons.square, 'Cube (AoE)'),
  (BattleMapTool.aoeSector, Icons.pie_chart_outline, 'Sector (AoE)'),
  (BattleMapTool.rect, Icons.crop_square, 'Rectangle'),
  (BattleMapTool.line, Icons.show_chart, 'Line'),
  (BattleMapTool.text, Icons.text_fields, 'Text label'),
];

bool isDrawTool(BattleMapTool t) {
  for (final entry in kDrawTools) {
    if (entry.$1 == t) return true;
  }
  return false;
}

IconData drawToolIcon(BattleMapTool t) {
  for (final (tool, icon, _) in kDrawTools) {
    if (tool == t) return icon;
  }
  return Icons.straighten; // fallback / default
}

class DrawToolsButton extends StatefulWidget {
  final BattleMapTool activeTool;
  final BattleMapNotifier notifier;
  final DmToolColors palette;

  /// Mobile sheet style (icon + label, fixed width) vs desktop (icon only).
  final bool compact;

  const DrawToolsButton({
    required this.activeTool,
    required this.notifier,
    required this.palette,
    this.compact = false,
    super.key,
  });

  @override
  State<DrawToolsButton> createState() => _DrawToolsButtonState();
}

class _DrawToolsButtonState extends State<DrawToolsButton> {
  // Last tool the user picked — drives the button icon when no draw tool is
  // currently active.
  BattleMapTool _selected = BattleMapTool.ruler;

  bool get _isActive => isDrawTool(widget.activeTool);

  BattleMapTool get _shown => _isActive ? widget.activeTool : _selected;

  Future<void> _openPicker() async {
    final palette = widget.palette;
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    // Anchor the menu's top-left at the button's bottom-left so it always drops
    // directly under the button (showMenu shifts up automatically if there's no
    // room below, e.g. the mobile bottom toolbar).
    final bottomLeft =
        box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      bottomLeft.dx,
      bottomLeft.dy,
      overlay.size.width - bottomLeft.dx,
      0,
    );

    final picked = await showMenu<BattleMapTool>(
      context: context,
      position: position,
      color: palette.tabBg,
      // Force the menu to the grid's exact width — the default min-width (112)
      // is wider than the 3 columns.
      // grid width (3×32 + 2×4 gaps = 104) + horizontal item padding (8×2 = 16).
      // Vertical edge comes from the menu's own 8px padding (Material default),
      // so the item adds none — keeps all four edges ~8px.
      constraints: const BoxConstraints.tightFor(width: 32 * 3 + 4 * 2 + 16),
      items: [
        PopupMenuItem<BattleMapTool>(
          enabled: false,
          height: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            // 3 cells per row → grid layout (32px cell + 4px gap).
            width: 32 * 3 + 4 * 2,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                  for (final (tool, icon, label) in kDrawTools)
                    Tooltip(
                      message: label,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(tool),
                        borderRadius: palette.br,
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.activeTool == tool
                                ? palette.tabIndicator.withValues(alpha: 0.2)
                                : null,
                            border: Border.all(
                                color: widget.activeTool == tool
                                    ? palette.tabIndicator
                                    : palette.sidebarDivider),
                            borderRadius: palette.br,
                          ),
                          child: Icon(icon,
                              size: 18,
                              color: widget.activeTool == tool
                                  ? palette.tabIndicator
                                  : palette.tabText),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
      widget.notifier.setTool(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final active = _isActive;
    final icon = drawToolIcon(_shown);

    if (widget.compact) {
      return InkWell(
        onTap: _openPicker,
        borderRadius: palette.cbr,
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? palette.tabIndicator.withValues(alpha: 0.2) : null,
            borderRadius: palette.cbr,
            border: active
                ? Border.all(color: palette.tabIndicator, width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? palette.tabIndicator : palette.tabText),
              const SizedBox(height: 2),
              Text('Draw',
                  style: TextStyle(
                      fontSize: 9,
                      color: active ? palette.tabIndicator : palette.tabText)),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Draw tools — ruler / AoE / shapes',
      child: InkWell(
        onTap: _openPicker,
        borderRadius: palette.br,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: active ? palette.tabIndicator.withValues(alpha: 0.2) : null,
            borderRadius: palette.br,
            border: active
                ? Border.all(color: palette.tabIndicator, width: 1)
                : null,
          ),
          child: Icon(icon,
              size: 18, color: active ? palette.tabIndicator : palette.tabText),
        ),
      ),
    );
  }
}
