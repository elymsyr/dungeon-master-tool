import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../domain/entities/mind_map.dart';
import '../../theme/dm_tool_colors.dart';
import 'mind_map_canvas.dart';
import 'mind_map_notifier.dart';

/// Mind Map tab root — full-bleed canvas + floating controls at bottom-right.
class MindMapScreen extends ConsumerStatefulWidget {
  final bool editMode;
  final void Function(String entityId)? onOpenEntity;

  const MindMapScreen({
    super.key,
    this.editMode = false,
    this.onOpenEntity,
  });

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> {
  late final MindMapNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(mindMapProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _init();
    });
  }

  void _init() {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final mindMaps = data['mind_maps'] as Map? ?? {};
    final defaultMap = Map<String, dynamic>.from(
      mindMaps['default'] as Map? ?? {},
    );
    _notifier.init(defaultMap);
  }

  @override
  void dispose() {
    unawaited(_notifier.save());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final notifier = ref.read(mindMapProvider.notifier);
    final mapState = ref.watch(mindMapProvider);

    return Stack(
      children: [
        // Full-bleed canvas
        MindMapCanvas(
          editMode: widget.editMode,
          onOpenEntity: widget.onOpenEntity,
        ),

        // Floating zoom controls — bottom-right
        Positioned(
          right: 16,
          bottom: 16,
          child: _FloatingControls(
            notifier: notifier,
            mapState: mapState,
            palette: palette,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Floating controls (bottom-right)
// ---------------------------------------------------------------------------

class _FloatingControls extends StatelessWidget {
  final MindMapNotifier notifier;
  final MindMapState mapState;
  final DmToolColors palette;

  const _FloatingControls({
    required this.notifier,
    required this.mapState,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final workspaces = notifier.workspaces;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Workspace list button (only if workspaces exist)
        if (workspaces.isNotEmpty)
          _FloatingButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Workspaces',
            palette: palette,
            onPressed: () => _showWorkspaceMenu(context, workspaces),
          ),
        if (workspaces.isNotEmpty) const SizedBox(height: 4),

        _FloatingButton(
          icon: Icons.center_focus_strong,
          tooltip: 'Center View',
          palette: palette,
          onPressed: notifier.centerView,
        ),
        const SizedBox(height: 4),
        _FloatingButton(
          icon: Icons.add,
          tooltip: 'Zoom In',
          palette: palette,
          onPressed: notifier.zoomIn,
        ),
        const SizedBox(height: 4),
        _FloatingButton(
          icon: Icons.remove,
          tooltip: 'Zoom Out',
          palette: palette,
          onPressed: notifier.zoomOut,
        ),
      ],
    );
  }

  void _showWorkspaceMenu(
      BuildContext context, List<MindMapNode> workspaces) {
    final button = context.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 160,
        offset.dy - workspaces.length * 40.0,
        offset.dx,
        offset.dy,
      ),
      color: palette.uiFloatingBg,
      items: workspaces.map((ws) {
        final color = _parseHexColor(ws.color);
        return PopupMenuItem<String>(
          value: ws.id,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ws.label,
                  style: TextStyle(
                      fontSize: 12, color: palette.uiFloatingText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((id) {
      if (id != null) notifier.zoomToWorkspace(id);
    });
  }

  Color _parseHexColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

class _FloatingButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final DmToolColors palette;
  final VoidCallback onPressed;

  const _FloatingButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
  });

  @override
  State<_FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<_FloatingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered ? palette.uiFloatingHoverBg : palette.uiFloatingBg,
              border: Border.all(color: palette.uiFloatingBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered
                  ? palette.uiFloatingHoverText
                  : palette.uiFloatingText,
            ),
          ),
        ),
      );
  }
}
