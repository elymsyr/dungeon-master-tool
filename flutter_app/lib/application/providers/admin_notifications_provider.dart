import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/admin_notifications_remote_ds.dart';
import 'admin_provider.dart';

final adminNotificationsDataSourceProvider =
    Provider<AdminNotificationsRemoteDataSource>((ref) {
  return AdminNotificationsRemoteDataSource();
});

/// All notifications with response counts (admin-gated).
final adminNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotificationSummary>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminNotificationsDataSourceProvider);
  return ds.list();
});

/// Per-notification user responses (admin-gated).
final adminNotificationResponsesProvider = FutureProvider.autoDispose
    .family<List<NotificationResponseRow>, String>((ref, notificationId) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminNotificationsDataSourceProvider);
  return ds.responses(notificationId);
});
