import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/account_gate.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// **Audit phase O2 — the single place a gated surface is drawn or not.**
///
/// [child] is a builder, not a widget, on purpose: the exit criterion is that a
/// guest never constructs a Supabase client, and a `Widget child` argument is
/// constructed by the caller *before* this widget can decide anything. With a
/// builder the surface's widgets — and the providers they watch — are only
/// built when [surfaceAccessProvider] says [SurfaceAccess.open].
class AccountGatedSurface extends ConsumerWidget {
  const AccountGatedSurface({
    super.key,
    required this.surface,
    required this.builder,
    this.message,
    this.hiddenBuilder,
  });

  /// Which surface this is. Its [AppSurface.requiresAccount] flag, not the
  /// widget, decides whether anything is gated at all.
  final AppSurface surface;

  /// The surface itself. Built only when access is open.
  final WidgetBuilder builder;

  /// Optional surface-specific line under the generic prompt (localized by the
  /// caller).
  final String? message;

  /// What a build with no Supabase defines shows. Defaults to nothing — there
  /// is no account to ask for, so the surface simply is not part of that app.
  final WidgetBuilder? hiddenBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(surfaceAccessProvider(surface));
    return switch (access) {
      SurfaceAccess.open => builder(context),
      SurfaceAccess.hidden =>
        hiddenBuilder?.call(context) ?? const SizedBox.shrink(),
      SurfaceAccess.signInRequired => SignInRequiredNotice(message: message),
    };
  }
}

/// The call to action a guest gets in place of a gated surface.
class SignInRequiredNotice extends StatelessWidget {
  const SignInRequiredNotice({super.key, this.message, this.compact = false});

  final String? message;

  /// Drops the body text — for tight rows where the title and the button are
  /// all that fit.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(palette.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 16, color: palette.sidebarLabelSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.accountRequiredTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              message ?? l10n.accountRequiredBody,
              style: TextStyle(
                  fontSize: 12, color: palette.sidebarLabelSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.login, size: 18),
              label: Text(l10n.accountRequiredSignIn),
              // The landing page is where the auth form lives (O1); an
              // account-only route sends a guest to exactly the same place.
              onPressed: () => context.go('/'),
            ),
          ),
        ],
      ),
    );
  }
}
