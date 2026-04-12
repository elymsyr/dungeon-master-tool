import 'package:flutter/widgets.dart';

/// Drop-in replacement for [IndexedStack] that defers building each
/// child until the first time its index is selected. Once visited, a
/// child stays mounted for the lifetime of this widget — so tab
/// switching behaves identically to the stock IndexedStack, but the
/// initial mount cost is paid only for tabs the user actually opens.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
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
