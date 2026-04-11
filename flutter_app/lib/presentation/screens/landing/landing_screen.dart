import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/dm_tool_colors.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.canvasBg,
                  palette.featureCardBg,
                ],
              ),
            ),
          ),

          // İçerik
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Icon(
                  Icons.castle,
                  size: size.width > 600 ? 96 : 72,
                  color: palette.featureCardAccent,
                ),
                const SizedBox(height: 16),

                // Başlık
                Text(
                  'Dungeon Master Tool',
                  style: TextStyle(
                    fontSize: size.width > 600 ? 32 : 24,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v2.0.1',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                // Start butonu
                SizedBox(
                  width: 200,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/hub'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.featureCardAccent,
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alt kısım: versiyon notu
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Text(
              'Campaign Management for Tabletop RPGs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
