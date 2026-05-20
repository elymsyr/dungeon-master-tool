import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/connectivity_provider.dart';
import '../theme/dm_tool_colors.dart';

/// Centered "no connection" placeholder — single clean message shown when a
/// network-backed screen can't load because the device is offline. Modeled
/// on `SocialEmptyState`. Purely presentational (no Riverpod).
class ConnectionErrorView extends StatelessWidget {
  /// When non-null, a "Retry" button is shown.
  final VoidCallback? onRetry;

  /// Optional override for the body text. Defaults to the offline message.
  final String? message;

  const ConnectionErrorView({super.key, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.featureCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: palette.featureCardBorder),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 40, color: palette.sidebarLabelSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              "You're offline",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message ?? 'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: palette.sidebarLabelSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh,
                    size: 18, color: palette.featureCardAccent),
                label: Text('Retry',
                    style: TextStyle(color: palette.featureCardAccent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.featureCardAccent),
                  shape: RoundedRectangleBorder(borderRadius: palette.br),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a network-dependent subtree. When the device is offline, renders a
/// single [ConnectionErrorView] instead of [child] — so the inner network
/// providers are never watched and never fire (no infinite spinner, no
/// scattered errors). Auto-recovers when connectivity returns: the stream
/// emits `true`, this rebuilds, and [child] mounts + fetches.
///
/// Fail-open: a loading/errored connectivity stream renders [child], never
/// blocks.
class OfflineGuard extends ConsumerWidget {
  final Widget child;

  /// Optional extra refresh hook invoked when the user taps "Retry".
  final VoidCallback? onRetry;

  const OfflineGuard({super.key, required this.child, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(connectivityStreamProvider).valueOrNull ?? true;
    if (online) return child;
    return ConnectionErrorView(
      onRetry: () {
        ref.invalidate(connectivityStreamProvider);
        onRetry?.call();
      },
    );
  }
}
