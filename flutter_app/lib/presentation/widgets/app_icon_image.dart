import 'package:flutter/material.dart';

/// Renders the project's branded castle icon from
/// `assets/app_icon_transparent.png` at [size] logical pixels.
///
/// Replaces previous `Icon(Icons.castle)` usages so the brand stays
/// consistent across the app. If [color] is provided, the icon is
/// tinted via a color filter (useful in places where the old
/// `Icons.castle` call used `color:` to match the current palette).
class AppIconImage extends StatelessWidget {
  final double size;
  final Color? color;

  const AppIconImage({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/app_icon_transparent.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
    if (color == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
