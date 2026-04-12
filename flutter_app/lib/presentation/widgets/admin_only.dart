import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_provider.dart';

/// Bir widget'ı yalnızca `is_admin()` RPC'si true dönen kullanıcılara gösterir.
/// Diğerleri için [fallback] (varsa) gösterilir, yoksa SizedBox.shrink.
class AdminOnly extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;
  const AdminOnly({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isAdminProvider).when(
          loading: () => fallback ?? const SizedBox.shrink(),
          error: (e, st) => fallback ?? const SizedBox.shrink(),
          data: (isAdmin) => isAdmin ? child : (fallback ?? const SizedBox.shrink()),
        );
  }
}
