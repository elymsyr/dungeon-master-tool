import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Relayout sinyali — notifyListeners() çağrıldığında
/// CustomMultiChildLayout RenderObject'u markNeedsLayout() tetikler.
class _RelayoutNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// PyQt QSplitter karşılığı.
/// RelayoutNotifier ile drag sırasında build yok — sadece layout pass çalışır.
/// Parent constraint değişimlerinde (window resize) Flutter zaten relayout yapar.
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
  late final _RelayoutNotifier _relayout;
  late final _SplitDelegate _delegate;
  static final double _dividerSize =
      (Platform.isAndroid || Platform.isIOS) ? 24.0 : 8.0;

  @override
  void initState() {
    super.initState();
    _relayout = _RelayoutNotifier();
    _delegate = _SplitDelegate(
      relayout: _relayout,
      axis: widget.axis,
      ratio: widget.initialRatio.clamp(0.0, 1.0),
      dividerSize: _dividerSize,
      minFirstSize: widget.minFirstSize,
      minSecondSize: widget.minSecondSize,
    );
  }

  @override
  void dispose() {
    _relayout.dispose();
    super.dispose();
  }

  double get ratio => _delegate.ratio;
  set ratio(double value) {
    _delegate.ratio = value.clamp(0.0, 1.0);
    _relayout.notify();
  }

  @override
  Widget build(BuildContext context) {
    final isH = widget.axis == Axis.horizontal;

    return CustomMultiChildLayout(
      delegate: _delegate,
      children: [
        LayoutId(id: _Slot.first, child: widget.first),
        LayoutId(
          id: _Slot.divider,
          child: _SplitDivider(
            axis: widget.axis,
            palette: widget.palette,
            onDragUpdate: (delta) {
              _delegate.applyDelta(isH ? delta.dx : delta.dy);
            },
            onDragEnd: () => widget.onRatioChanged?.call(_delegate.ratio),
          ),
        ),
        LayoutId(id: _Slot.second, child: widget.second),
      ],
    );
  }
}

enum _Slot { first, divider, second }

class _SplitDelegate extends MultiChildLayoutDelegate {
  final _RelayoutNotifier _relayout;
  Axis axis;
  double ratio;
  final double dividerSize;
  final double minFirstSize;
  final double minSecondSize;

  _SplitDelegate({
    required _RelayoutNotifier relayout,
    required this.axis,
    required this.ratio,
    required this.dividerSize,
    required this.minFirstSize,
    required this.minSecondSize,
  })  : _relayout = relayout,
        super(relayout: relayout); // ← Flutter RenderObject bu Listenable'ı dinler

  void applyDelta(double d) {
    final available = _lastAvailable;
    if (available <= 0) return;
    final minF = minFirstSize.clamp(0.0, available * 0.8);
    final minS = minSecondSize.clamp(0.0, available - minF);
    final currentFirst = (available * ratio).clamp(minF, available - minS);
    final newFirst = (currentFirst + d).clamp(minF, available - minS);
    final newRatio = newFirst / available;
    if ((newRatio - ratio).abs() > 0.0005) {
      ratio = newRatio;
      _relayout.notify(); // → markNeedsLayout()
    }
  }

  double _lastAvailable = 0;

  @override
  void performLayout(Size size) {
    final isH = axis == Axis.horizontal;
    final total = isH ? size.width : size.height;
    final cross = isH ? size.height : size.width;
    final available = total - dividerSize;
    _lastAvailable = available > 0 ? available : 0;

    if (available <= 0) {
      for (final slot in _Slot.values) {
        if (hasChild(slot)) {
          layoutChild(slot, const BoxConstraints.tightFor(width: 0, height: 0));
          positionChild(slot, Offset.zero);
        }
      }
      return;
    }

    final minF = minFirstSize.clamp(0.0, available * 0.8);
    final minS = minSecondSize.clamp(0.0, available - minF);
    final firstSize = (available * ratio).clamp(minF, available - minS);
    final secondSize = available - firstSize;

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
  bool shouldRelayout(covariant _SplitDelegate old) =>
      old.axis != axis ||
      old.ratio != ratio ||
      old.dividerSize != dividerSize ||
      old.minFirstSize != minFirstSize ||
      old.minSecondSize != minSecondSize;
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
  static final double _lineThickness =
      (Platform.isAndroid || Platform.isIOS) ? 3.0 : 1.0;
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
            width: isH ? _lineThickness : double.infinity,
            height: isH ? double.infinity : _lineThickness,
            color: _hovered
                ? widget.palette.tabIndicator.withValues(alpha: 0.6)
                : widget.palette.sidebarDivider,
          ),
        ),
      ),
    );
  }
}
