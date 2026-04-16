import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/cached_provider.dart';
import '../../data/datasources/remote/follows_remote_ds.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

final followsRemoteDsProvider = Provider<FollowsRemoteDataSource>(
  (ref) => FollowsRemoteDataSource(),
);

/// Auth user, [targetUserId]'i takip ediyor mu? Optimistic toggle
/// notifier üzerinden state = loading veya data(bool) olarak override
/// edilebilir; UI hemen yeni değeri görür.
final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;
  return cachedFetch(
    ref: ref,
    cacheKey: 'isFollowing:$targetUserId',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(followsRemoteDsProvider).isFollowing(targetUserId),
  );
});

/// Optimistic local override for follow state. Eğer set edilmişse
/// UI bu değeri kullanır, aksi halde [isFollowingProvider]'a düşer.
/// Key: target user id, Value: follow state (true = following).
final followOverrideProvider =
    StateProvider.family<bool?, String>((ref, targetUserId) => null);

final followersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'followers:$userId',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(followsRemoteDsProvider).followersOf(userId),
  );
});

final followingProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'following:$userId',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(followsRemoteDsProvider).followingOf(userId),
  );
});

class FollowToggleNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  FollowToggleNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Optimistic: önce lokal override'ı ters çevir (UI anında reflect eder),
  /// sonra DB'ye yaz. Hata olursa override'ı geri al ve hata bildir.
  Future<void> toggle(String targetUserId) async {
    final current = _ref.read(followOverrideProvider(targetUserId)) ??
        (_ref.read(isFollowingProvider(targetUserId)).value ?? false);
    final next = !current;
    _ref.read(followOverrideProvider(targetUserId).notifier).state = next;

    try {
      await _ref.read(followsRemoteDsProvider).toggle(targetUserId);
      invalidateCache('isFollowing:$targetUserId');
      invalidateCache('followers:$targetUserId');
      invalidateCache('profile:$targetUserId');
      invalidateCache('currentProfile');
      _ref.invalidate(isFollowingProvider(targetUserId));
      _ref.invalidate(followersProvider(targetUserId));
      _ref.invalidate(profileByIdProvider(targetUserId));
      _ref.invalidate(currentProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // Rollback: override'ı tekrar eski değere çek.
      _ref.read(followOverrideProvider(targetUserId).notifier).state = current;
      state = AsyncValue.error(e, st);
    }
  }
}

final followToggleProvider =
    StateNotifierProvider<FollowToggleNotifier, AsyncValue<void>>(
  (ref) => FollowToggleNotifier(ref),
);
