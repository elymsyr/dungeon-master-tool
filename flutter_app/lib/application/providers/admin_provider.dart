import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/datasources/remote/admin_users_remote_ds.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

/// Şu anki kullanıcının admin olup olmadığı. Email kaynak kodda DEĞİL —
/// Supabase tarafındaki `app_admins` tablosu ve `is_admin()` RPC'si
/// üzerinden doğrulanır. Auth state değişince otomatik refresh.
///
/// Atama: Supabase SQL editor'da elle:
///   INSERT INTO public.app_admins (user_id)
///     SELECT id FROM auth.users WHERE email = '...';
final isAdminProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;

  try {
    final result = await guardedNetwork(
        ref, () => Supabase.instance.client.rpc('is_admin'));
    return result == true;
  } catch (e, st) {
    if (isOfflineError(e)) {
      debugPrint('isAdmin skipped: offline ($e)');
    } else {
      debugPrint('isAdmin RPC error: $e\n$st');
    }
    return false;
  }
});

/// Admin data source — tek instance, provider'lar üzerinden erişilir.
final adminUsersDataSourceProvider = Provider<AdminUsersRemoteDataSource>((ref) {
  return AdminUsersRemoteDataSource();
});

/// Admin panelindeki arama kutusu state'i. Boşken tüm kullanıcılar listelenir.
final adminUserSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Kullanıcı listesi sıralama modu.
enum AdminUserSortMode { registrationDate, lastSeen, appVersion }

/// Sıralama yönü: true = azalan (yeniden eskiye), false = artan.
final adminUserSortReversedProvider = StateProvider.autoDispose<bool>((ref) => true);

/// Sıralama modu.
final adminUserSortModeProvider = StateProvider.autoDispose<AdminUserSortMode>(
  (ref) => AdminUserSortMode.registrationDate,
);

/// Tüm kullanıcılar (arama sorgusuna göre filtreli). Admin değilse boş döner.
final adminUserListProvider = FutureProvider.autoDispose<List<AdminUserSummary>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  final query = ref.watch(adminUserSearchQueryProvider).trim();
  if (query.isEmpty) {
    return ds.fetchAllUsers();
  }
  return ds.searchUsers(query);
});

/// Sıralanmış kullanıcı listesi — adminUserListProvider'ı izler, client-side sıralama uygular.
final adminUserSortedListProvider = FutureProvider.autoDispose<List<AdminUserSummary>>((ref) async {
  final users = await ref.watch(adminUserListProvider.future);
  final mode = ref.watch(adminUserSortModeProvider);
  final reversed = ref.watch(adminUserSortReversedProvider);

  final sorted = List<AdminUserSummary>.of(users);
  int Function(AdminUserSummary a, AdminUserSummary b) comparator;
  switch (mode) {
    case AdminUserSortMode.registrationDate:
      comparator = (a, b) => a.createdAt.compareTo(b.createdAt);
    case AdminUserSortMode.lastSeen:
      comparator = (a, b) {
        final aTime = a.lastActiveAt ?? DateTime(0);
        final bTime = b.lastActiveAt ?? DateTime(0);
        return aTime.compareTo(bTime);
      };
    case AdminUserSortMode.appVersion:
      comparator = (a, b) {
        final av = a.appVersion ?? '';
        final bv = b.appVersion ?? '';
        return av.compareTo(bv);
      };
  }
  sorted.sort(comparator);
  if (reversed) {
    final len = sorted.length;
    for (var i = 0; i < len ~/ 2; i++) {
      final tmp = sorted[i];
      sorted[i] = sorted[len - 1 - i];
      sorted[len - 1 - i] = tmp;
    }
  }
  return sorted;
});

/// Özet istatistikler — toplam kullanıcı sayısı. Arama sorgusundan
/// bağımsız, her zaman tüm kullanıcılar üzerinden hesaplanır.
class AdminUserStats {
  final int total;
  const AdminUserStats({required this.total});
}

final adminUserStatsProvider = FutureProvider.autoDispose<AdminUserStats>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const AdminUserStats(total: 0);
  final ds = ref.watch(adminUsersDataSourceProvider);
  final all = await ds.fetchAllUsers();
  return AdminUserStats(
    total: all.length,
  );
});

/// Banlanmış kullanıcı listesi.
final adminBannedUsersProvider = FutureProvider.autoDispose<List<BannedUserEntry>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchBannedUsers();
});

/// Supabase storage bucket istatistikleri (kullanılan byte).
final adminStorageStatsProvider = FutureProvider.autoDispose<List<StorageBucketStat>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchStorageStats();
});

/// Restricted (online yasaklı) kullanıcı listesi — admin paneli için.
final adminRestrictedUsersProvider =
    FutureProvider.autoDispose<List<RestrictedUserEntry>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchRestrictedUsers();
});

/// Tüm post'lar (admin moderation tab).
final adminAllPostsProvider =
    FutureProvider.autoDispose<List<AdminPostRow>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchAllPosts();
});

/// Tüm game listing'leri (admin moderation tab).
final adminAllGameListingsProvider =
    FutureProvider.autoDispose<List<AdminGameListingRow>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchAllGameListings();
});

/// Tüm marketplace listing'leri (admin moderation tab).
final adminAllMarketplaceListingsProvider =
    FutureProvider.autoDispose<List<AdminMarketplaceListingRow>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchAllMarketplaceListings();
});

/// Admin audit log — en yeni başta.
final adminAuditLogProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return const [];
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.fetchAuditLog();
});

/// Kullanıcı tarafı: mevcut oturumun online restriction durumu. Auth state
/// değişince otomatik refresh olur (banned user flow'una benzer).
///
/// UI tarafında `onlineRestrictionProvider` ile izlenir; restricted ise
/// sosyal etkileşim butonları disable edilir ve banner gösterilir.
final onlineRestrictionProvider =
    FutureProvider<OnlineRestriction>((ref) async {
  if (!SupabaseConfig.isConfigured) return OnlineRestriction.none;
  final auth = ref.watch(authProvider);
  if (auth == null) return OnlineRestriction.none;
  final ds = ref.watch(adminUsersDataSourceProvider);
  return ds.amIOnlineRestricted();
});
