import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/datasources/remote/follows_remote_ds.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

final followsRemoteDsProvider = Provider<FollowsRemoteDataSource>(
  (ref) => FollowsRemoteDataSource(),
);

/// Auth user, [targetUserId]'i takip ediyor mu?
final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;
  return ref.read(followsRemoteDsProvider).isFollowing(targetUserId);
});

final followersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return ref.read(followsRemoteDsProvider).followersOf(userId);
});

final followingProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return ref.read(followsRemoteDsProvider).followingOf(userId);
});

class FollowToggleNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  FollowToggleNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggle(String targetUserId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(followsRemoteDsProvider).toggle(targetUserId);
      _ref.invalidate(isFollowingProvider(targetUserId));
      _ref.invalidate(followersProvider(targetUserId));
      _ref.invalidate(profileByIdProvider(targetUserId));
      _ref.invalidate(currentProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final followToggleProvider =
    StateNotifierProvider<FollowToggleNotifier, AsyncValue<void>>(
  (ref) => FollowToggleNotifier(ref),
);
