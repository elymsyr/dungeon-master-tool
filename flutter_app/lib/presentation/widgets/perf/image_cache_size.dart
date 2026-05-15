import 'package:flutter/widgets.dart';

/// Logical pixel -> physical pixel cache size.
///
/// `Image.network/asset/file` decode at the source resolution by default.
/// A 2048x2048 PNG rendered at 64x64 still allocates ~16 MB RGBA in memory.
/// Pass the result to `cacheWidth` / `cacheHeight` so the decoder downsamples
/// during decode, not after.
int? cachePxFromLogical(BuildContext ctx, double logical) {
  if (logical.isInfinite || logical.isNaN || logical <= 0) return null;
  final dpr = MediaQuery.devicePixelRatioOf(ctx);
  return (logical * dpr).ceil();
}
