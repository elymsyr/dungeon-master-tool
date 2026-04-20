import 'package:flutter/material.dart';

/// Responsive card grid for hub tabs (Worlds / Packages / Characters).
///
/// Below [breakpoint] width: single-column column of full-width tiles —
/// preserves the legacy narrow-screen look. Above it: a Wrap lays out
/// fixed-width tiles in flowing rows so wide desktop windows use the
/// extra horizontal space instead of wasting it on margins.
///
/// Tiles size themselves intrinsically (IntrinsicHeight in leftAvatar
/// layout, Column height in topBanner layout), so the grid never clips.
class HubCardGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double tileWidth;
  final double breakpoint;
  final double spacing;

  const HubCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.tileWidth = 340,
    this.breakpoint = 640,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < breakpoint;
        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < itemCount; i++) ...[
                if (i > 0) SizedBox(height: spacing / 2),
                itemBuilder(context, i),
              ],
            ],
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(width: tileWidth, child: itemBuilder(context, i)),
          ],
        );
      },
    );
  }
}
