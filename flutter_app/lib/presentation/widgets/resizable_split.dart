import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// PyQt QSplitter karşılığı — iki widget arasında sürüklenebilir divider.
/// ValueNotifier ile sadece boyutlar rebuild olur, child'lar asla rebuild olmaz.
class ResizableSplit extends StatefulWidget {
  final Widget first;
  final Widget second;
  final Axis axis;
  final double initialRatio;
  final double minFirstSize;
  final double minSecondSize;
  final ValueChanged<double>? onRatioChanged;
  final DmToolColors palette;

  const ResizableSplit({
    required this.first,
    required this.second,
    this.axis = Axis.horizontal,
    this.initialRatio = 0.5,
    this.minFirstSize = 100,
    this.minSecondSize = 100,
    this.onRatioChanged,
    required this.palette,
    super.key,
  });

  @override
  State<ResizableSplit> createState() => ResizableSplitState();
}

class ResizableSplitState extends State<ResizableSplit> {
  late final ValueNotifier<double> _ratioNotifier;

  @override
  void initState() {
    super.initState();
    _ratioNotifier = ValueNotifier(widget.initialRatio.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _ratioNotifier.dispose();
    super.dispose();
  }

  double get ratio => _ratioNotifier.value;

  set ratio(double value) {
    _ratioNotifier.value = value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        const dividerSize = 8.0;
        final available = totalSize - dividerSize;
        if (available <= 0) return const SizedBox.shrink();

        return ValueListenableBuilder<double>(
          valueListenable: _ratioNotifier,
          builder: (context, ratio, _) {
            final firstSize = (available * ratio).clamp(
              widget.minFirstSize,
              available - widget.minSecondSize,
            );
            final secondSize = available - firstSize;

            return Flex(
              direction: widget.axis,
              children: [
                SizedBox(
                  width: isHorizontal ? firstSize : null,
                  height: isHorizontal ? null : firstSize,
                  child: widget.first,
                ),
                _SplitDivider(
                  axis: widget.axis,
                  palette: widget.palette,
                  onDragUpdate: (delta) {
                    final d = isHorizontal ? delta.dx : delta.dy;
                    final newFirst = (firstSize + d).clamp(
                      widget.minFirstSize,
                      available - widget.minSecondSize,
                    );
                    _ratioNotifier.value = newFirst / available;
                  },
                  onDragEnd: () {
                    widget.onRatioChanged?.call(_ratioNotifier.value);
                  },
                ),
                SizedBox(
                  width: isHorizontal ? secondSize : null,
                  height: isHorizontal ? null : secondSize,
                  child: widget.second,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SplitDivider extends StatefulWidget {
  final Axis axis;
  final DmToolColors palette;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;

  const _SplitDivider({
    required this.axis,
    required this.palette,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends State<_SplitDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;

    return GestureDetector(
      onHorizontalDragUpdate: isHorizontal ? (d) => widget.onDragUpdate(d.delta) : null,
      onHorizontalDragEnd: isHorizontal ? (_) => widget.onDragEnd() : null,
      onVerticalDragUpdate: isHorizontal ? null : (d) => widget.onDragUpdate(d.delta),
      onVerticalDragEnd: isHorizontal ? null : (_) => widget.onDragEnd(),
      child: MouseRegion(
        cursor: isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          width: isHorizontal ? 8 : double.infinity,
          height: isHorizontal ? double.infinity : 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: isHorizontal ? 1 : double.infinity,
              height: isHorizontal ? double.infinity : 1,
              color: _hovered
                  ? widget.palette.tabIndicator.withValues(alpha: 0.6)
                  : widget.palette.sidebarDivider,
            ),
          ),
        ),
      ),
    );
  }
}
