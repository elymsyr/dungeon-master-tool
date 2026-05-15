import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Drop-in replacement for [IndexedStack] that defers building each
/// child until the first time its index is selected. Once visited, a
/// child stays mounted for the lifetime of this widget — so tab
/// switching behaves identically to the stock IndexedStack, but the
/// initial mount cost is paid only for tabs the user actually opens.
///
/// When [prewarm] is true, the remaining children are mounted one at a
/// time during idle frames after the initial paint. Each next tab is
/// scheduled via a post-frame callback so it mounts as soon as the
/// previous frame settles (no fixed delay), shifting tab first-paint
/// cost into idle time so the user's actual tap on a new tab becomes a
/// cheap IndexedStack index swap instead of a full subtree build.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;
  final bool prewarm;

  /// Optional inter-tab delay during prewarm. Defaults to [Duration.zero]
  /// which chains via post-frame callbacks so each next tab mounts as
  /// soon as the prior frame ends. Pass a non-zero value to give the
  /// engine more breathing room between mounts on very slow devices.
  final Duration prewarmInterval;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    // Expand so the active child fills the parent. With StackFit.loose,
    // the SCROLLVIEW inside a tab gets loose vertical constraints and
    // shrinks to content size — which makes `Align(topCenter)` above it
    // ineffective on first mount. Expand pins height → topCenter works.
    this.sizing = StackFit.expand,
    this.prewarm = false,
    this.prewarmInterval = Duration.zero,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = <int>{};
  Timer? _prewarmTimer;

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
    if (widget.prewarm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePrewarm());
    }
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
  }

  @override
  void dispose() {
    _prewarmTimer?.cancel();
    super.dispose();
  }

  void _schedulePrewarm() {
    if (!mounted) return;
    final next = _nextUnvisited();
    if (next == null) return;
    _prewarmTimer?.cancel();
    void mountNext() {
      if (!mounted) return;
      // Defer the setState to idle priority so it never preempts an
      // in-flight user tap / animation frame. Once the mount frame
      // completes we chain the next prewarm via a post-frame callback.
      SchedulerBinding.instance.scheduleTask(() {
        if (!mounted) return;
        setState(() => _visited.add(next));
        WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePrewarm());
      }, Priority.idle);
    }

    if (widget.prewarmInterval == Duration.zero) {
      mountNext();
    } else {
      _prewarmTimer = Timer(widget.prewarmInterval, mountNext);
    }
  }

  int? _nextUnvisited() {
    for (int i = 0; i < widget.children.length; i++) {
      if (!_visited.contains(i)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      sizing: widget.sizing,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _visited.contains(i)
              ? widget.children[i]
              : const SizedBox.shrink(),
      ],
    );
  }
}
