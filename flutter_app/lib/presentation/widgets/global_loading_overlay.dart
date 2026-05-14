import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/global_loading_provider.dart';
import '../theme/dm_tool_colors.dart';

/// Full-screen overlay that displays the most recent [LoadingTask] as an
/// indeterminate/determinate progress card over a dimmed barrier.
///
/// Mount once at the root (in [MaterialApp.builder]) so it sits above all
/// routes and dialogs. Empty task list → renders nothing and doesn't
/// intercept pointer events.
class GlobalLoadingOverlay extends ConsumerWidget {
  const GlobalLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(globalLoadingProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final current = tasks.last;
    final extraCount = tasks.length - 1;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: palette.srdParchment,
              borderRadius: BorderRadius.circular(palette.cardBorderRadius),
              border: Border.all(color: palette.srdRule, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: current.progress,
                      strokeWidth: 3,
                      color: palette.srdHeadingRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    current.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: palette.useSerif ? 'Georgia' : null,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.srdInk,
                    ),
                  ),
                  if (current.progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: current.progress,
                        minHeight: 4,
                        color: palette.srdHeadingRed,
                        backgroundColor: palette.srdRule.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                  if (extraCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+$extraCount more',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.srdSubtitle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
