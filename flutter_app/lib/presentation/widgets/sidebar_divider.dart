import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Sidebar divider — toggle butonu + sürükleyerek genişletme.
/// Sol ve sağ sidebar için kullanılır.
class SidebarDivider extends StatefulWidget {
  final bool isOpen;
  final DmToolColors palette;
  final VoidCallback onToggle;
  final void Function(double dx)? onDragUpdate;
  final VoidCallback? onDragEnd;

  /// true ise sağ taraftaki sidebar için kullanılır (chevron yönü ters).
  final bool isRightSide;

  const SidebarDivider({
    super.key,
    required this.isOpen,
    required this.palette,
    required this.onToggle,
    this.onDragUpdate,
    this.onDragEnd,
    this.isRightSide = false,
  });

  @override
  State<SidebarDivider> createState() => _SidebarDividerState();
}

class _SidebarDividerState extends State<SidebarDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.onDragUpdate != null
          ? (details) => widget.onDragUpdate!(details.delta.dx)
          : null,
      onHorizontalDragEnd: widget.onDragEnd != null
          ? (_) => widget.onDragEnd!()
          : null,
      child: MouseRegion(
        cursor: widget.isOpen ? SystemMouseCursors.resizeColumn : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onToggle,
          child: Container(
            width: 10,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 1,
                height: double.infinity,
                color: _hovered
                    ? widget.palette.tabIndicator.withValues(alpha: 0.6)
                    : widget.palette.sidebarDivider,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
