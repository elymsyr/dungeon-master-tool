import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// PyQt QSplitter karşılığı — iki widget arasında sürüklenebilir divider.
/// CustomMultiChildLayout ile child'lar rebuild olmaz, sadece boyutları değişir.
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
  late double _ratio;
  static const _dividerSize = 8.0;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio.clamp(0.0, 1.0);
  }

  double get ratio => _ratio;
  set ratio(double value) => setState(() => _ratio = value.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final isH = widget.axis == Axis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = isH ? constraints.maxWidth : constraints.maxHeight;
        final available = total - _dividerSize;
        if (available <= 0) return const SizedBox.shrink();

        // Güvenli boyut hesapla — pencere küçültülünce overflow olmasın
        final minFirst = widget.minFirstSize.clamp(0.0, available * 0.8);
        final minSecond = widget.minSecondSize.clamp(0.0, available - minFirst);
        final firstSize = (available * _ratio).clamp(minFirst, available - minSecond);
        final secondSize = (available - firstSize).clamp(0.0, available);

        return CustomMultiChildLayout(
          delegate: _SplitDelegate(
            axis: widget.axis,
            firstSize: firstSize,
            secondSize: secondSize,
            dividerSize: _dividerSize,
          ),
          children: [
            LayoutId(id: _Slot.first, child: widget.first),
            LayoutId(
              id: _Slot.divider,
              child: _SplitDivider(
                axis: widget.axis,
                palette: widget.palette,
                onDragUpdate: (delta) {
                  final d = isH ? delta.dx : delta.dy;
                  final currentFirst = (available * _ratio).clamp(minFirst, available - minSecond);
                  final newFirst = (currentFirst + d).clamp(minFirst, available - minSecond);
                  final newRatio = newFirst / available;
                  if ((newRatio - _ratio).abs() > 0.001) {
                    setState(() => _ratio = newRatio);
                  }
                },
                onDragEnd: () => widget.onRatioChanged?.call(_ratio),
              ),
            ),
            LayoutId(id: _Slot.second, child: widget.second),
          ],
        );
      },
    );
  }
}

enum _Slot { first, divider, second }

class _SplitDelegate extends MultiChildLayoutDelegate {
  final Axis axis;
  final double firstSize;
  final double secondSize;
  final double dividerSize;

  _SplitDelegate({
    required this.axis,
    required this.firstSize,
    required this.secondSize,
    required this.dividerSize,
  });

  @override
  void performLayout(Size size) {
    final isH = axis == Axis.horizontal;
    final cross = isH ? size.height : size.width;

    if (hasChild(_Slot.first)) {
      layoutChild(_Slot.first, BoxConstraints.tight(
        isH ? Size(firstSize, cross) : Size(cross, firstSize),
      ));
      positionChild(_Slot.first, Offset.zero);
    }

    if (hasChild(_Slot.divider)) {
      layoutChild(_Slot.divider, BoxConstraints.tight(
        isH ? Size(dividerSize, cross) : Size(cross, dividerSize),
      ));
      positionChild(_Slot.divider, isH ? Offset(firstSize, 0) : Offset(0, firstSize));
    }

    if (hasChild(_Slot.second)) {
      layoutChild(_Slot.second, BoxConstraints.tight(
        isH ? Size(secondSize, cross) : Size(cross, secondSize),
      ));
      positionChild(_Slot.second, isH
          ? Offset(firstSize + dividerSize, 0)
          : Offset(0, firstSize + dividerSize));
    }
  }

  @override
  bool shouldRelayout(_SplitDelegate old) =>
      firstSize != old.firstSize || secondSize != old.secondSize || axis != old.axis;
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
    final isH = widget.axis == Axis.horizontal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: isH ? (d) => widget.onDragUpdate(d.delta) : null,
      onHorizontalDragEnd: isH ? (_) => widget.onDragEnd() : null,
      onVerticalDragUpdate: isH ? null : (d) => widget.onDragUpdate(d.delta),
      onVerticalDragEnd: isH ? null : (_) => widget.onDragEnd(),
      child: MouseRegion(
        cursor: isH ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Center(
          child: Container(
            width: isH ? 1 : double.infinity,
            height: isH ? double.infinity : 1,
            color: _hovered
                ? widget.palette.tabIndicator.withValues(alpha: 0.6)
                : widget.palette.sidebarDivider,
          ),
        ),
      ),
    );
  }
}
