import 'package:flutter/material.dart';

import 'app_icon_image.dart';

/// Splash shown while a world is opening — blocks the tab shell so battlemap /
/// mindmap / map screens don't mount with stale local state. `completeLoad`
/// awaits cloud `applyInitialState` (8s ceiling), then flips the loading flag.
class WorldOpenSplash extends StatelessWidget {
  const WorldOpenSplash({super.key, this.message = 'Opening world...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1A1814);
    const gold = Color(0xFFC8A24B);
    return Material(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconImage(size: 160),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
