import 'package:flutter/material.dart';

/// Themed `!` + count badge used on character card headers to surface
/// unresolved level-up choices. Light theme → deep blue text, soft amber
/// glow. Dark theme → warm amber text, soft blue glow. Tap-through.
Widget pendingChoicesBadge(BuildContext context, int count) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final fg = dark
      ? Color.lerp(scheme.primary, Colors.white, 0.45)!
      : Color.lerp(scheme.primary, Colors.black, 0.35)!;
  final glowBase = dark
      ? Color.lerp(scheme.secondary, Colors.white, 0.35)!
      : Color.lerp(scheme.secondary, Colors.black, 0.25)!;
  final glow = glowBase.withValues(alpha: 0.5);
  final shadows = <Shadow>[
    Shadow(color: glow, blurRadius: 4),
    Shadow(color: glow, blurRadius: 8),
  ];
  return Tooltip(
    message:
        '$count pending level-up choice${count == 1 ? '' : 's'} — open character to resolve.',
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        '!',
        style: TextStyle(
          color: fg,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: shadows,
        ),
      ),
    ),
  );
}
