import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Stack whose hit-testing bypasses [RenderBox.size.contains].
///
/// Use when children are positioned in a coordinate system that exceeds the
/// Stack's laid-out bounds — for example, canvas-space children inside a
/// Transform whose constraints come from a viewport-sized parent. The
/// default [RenderStack.hitTest] rejects positions outside its size and so
/// pointer events for far-away children never reach them; this subclass
/// removes that check so tap / long-press / drag handlers fire for any
/// Positioned child regardless of its coordinate.
class UnboundedStack extends Stack {
  const UnboundedStack({
    super.key,
    super.alignment = AlignmentDirectional.topStart,
    super.textDirection,
    super.fit = StackFit.loose,
    super.clipBehavior = Clip.none,
    super.children = const <Widget>[],
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return _RenderUnboundedStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }
}

class _RenderUnboundedStack extends RenderStack {
  _RenderUnboundedStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position) ||
        hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
