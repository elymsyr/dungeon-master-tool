import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/datasources/remote/notifications_remote_ds.dart';
import '../../domain/entities/app_notification.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

final notificationsDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSource();
});

/// Published notifications with the user's answers + read state. Guests get
/// them too (migration 111, read state local). Empty when unconfigured / offline.
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authProvider); // refetch on sign-in / sign-out
  final ds = ref.watch(notificationsDataSourceProvider);
  try {
    return await guardedNetwork(ref, () => ds.list());
  } catch (e) {
    if (isOfflineError(e)) return const [];
    rethrow;
  }
});

/// Unread count for the bell badge. 0 while loading / error / offline.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.read).length,
        orElse: () => 0,
      );
});

/// Live updates: subscribe to the global `notifications` table and refresh the
/// list on any change. Keep alive by `ref.watch`-ing it from the Hub.
/// Signed-in only: anon has no SELECT on the table (081), so a guest's list
/// refreshes when the Hub or the inbox opens instead.
final notificationsRealtimeProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;
  final auth = ref.watch(authProvider);
  if (auth == null) return;

  final client = Supabase.instance.client;
  final channel = client.channel('dmt:notifications');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'notifications',
    callback: (_) => ref.invalidate(notificationsProvider),
  );
  channel.subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
