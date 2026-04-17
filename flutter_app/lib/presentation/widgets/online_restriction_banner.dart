import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_provider.dart';
import '../theme/dm_tool_colors.dart';

/// Online yasağı (restriction) konmuş kullanıcıya gösterilen banner.
/// Restricted değilse hiç render edilmez (SizedBox.shrink).
///
/// Sosyal ekranların başında (feed, marketplace publish, game listings,
/// DM compose) Column/ListView başlığı olarak kullanılır. Butonların kendisi
/// ayrıca `onlineRestrictionProvider`'a bakıp disable edilmelidir; banner
/// yalnızca UX bildirimidir, RLS tarafında da kuvvet uygulanır.
class OnlineRestrictionBanner extends ConsumerWidget {
  const OnlineRestrictionBanner({super.key, this.compact = false});

  /// `compact` = true ise dar padding'li tek-satırlık sürüm. Dialog'ların
  /// başında kullanılır.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restriction = ref.watch(onlineRestrictionProvider);
    return restriction.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (r) {
        if (!r.restricted) return const SizedBox.shrink();
        final palette = Theme.of(context).extension<DmToolColors>()!;
        final reason = (r.reason ?? '').trim();
        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(
            compact ? 0 : 12,
            compact ? 4 : 8,
            compact ? 0 : 12,
            compact ? 4 : 8,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: palette.dangerBtnBg.withValues(alpha: 0.10),
            border: Border.all(color: palette.dangerBtnBg.withValues(alpha: 0.5)),
            borderRadius: palette.br,
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: compact ? 14 : 18,
                  color: palette.dangerBtnBg),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your online interactions are restricted by an admin.',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      ),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reason: $reason',
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: palette.sidebarLabelSecondary,
                        ),
                      ),
                    ],
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        'You can still browse and download marketplace items.',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.sidebarLabelSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Convenience helper — restricted ise true döner. Widget'ların onPressed
/// guard'ları için.
bool isOnlineRestrictedNow(WidgetRef ref) {
  return ref.watch(onlineRestrictionProvider).maybeWhen(
        data: (r) => r.restricted,
        orElse: () => false,
      );
}
