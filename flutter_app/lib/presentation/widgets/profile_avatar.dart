import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Network avatar with gradient/initial fallback. Reused across profile menu,
/// profile screen, post author rows, message bubbles.
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackText;
  final double size;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    required this.fallbackText,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final initial = fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.featureCardAccent,
            palette.featureCardAccent.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallback,
        loadingBuilder: (ctx, child, prog) =>
            prog == null ? child : fallback,
      ),
    );
  }
}
