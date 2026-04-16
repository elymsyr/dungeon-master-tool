import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/datasources/remote/profiles_remote_ds.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_provider.dart';

/// Singleton remote DS.
final profilesRemoteDsProvider = Provider<ProfilesRemoteDataSource>(
  (ref) => ProfilesRemoteDataSource(),
);

/// Mevcut auth user için profil. Auth değişince otomatik refresh.
/// `null` döner: ya kullanıcı sign-in olmamıştır ya da henüz profil
/// oluşturmamıştır (ilk sign-in akışı) ya da cihaz offline.
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  if (!SupabaseConfig.isConfigured) return null;
  final auth = ref.watch(authProvider);
  if (auth == null) return null;
  try {
    return await ref.read(profilesRemoteDsProvider).fetchCurrent();
  } catch (e, st) {
    if (isOfflineError(e)) {
      debugPrint('currentProfileProvider offline, returning null: $e');
      return null;
    }
    debugPrint('currentProfileProvider error: $e\n$st');
    rethrow;
  }
});

/// Başka bir kullanıcının profili (Profile screen, post author'u vs.).
final profileByIdProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return await ref.read(profilesRemoteDsProvider).fetchById(userId);
  } catch (e) {
    if (isOfflineError(e)) return null;
    rethrow;
  }
});

/// Username arama (Players tab discover sekmesi).
final profileSearchProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, query) async {
  if (!SupabaseConfig.isConfigured || query.trim().length < 2) return const [];
  return ref.read(profilesRemoteDsProvider).search(query);
});

/// Profil düzenleme + oluşturma için state-machine notifier.
class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  final Ref _ref;
  ProfileEditNotifier(this._ref) : super(const ProfileEditState.idle());

  Future<bool> createProfile({
    required String username,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    state = const ProfileEditState.busy();
    try {
      await _ref.read(profilesRemoteDsProvider).create(
            username: username,
            displayName: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
          );
      _ref.invalidate(currentProfileProvider);
      state = const ProfileEditState.success();
      return true;
    } on PostgrestException catch (e, st) {
      debugPrint('Profile create error: $e\n$st');
      if (e.code == '23505' && (e.message.contains('username') || e.details.toString().contains('username'))) {
        state = const ProfileEditState.error('Username already taken');
      } else {
        state = ProfileEditState.error(e.message);
      }
      return false;
    } catch (e, st) {
      debugPrint('Profile create error: $e\n$st');
      state = ProfileEditState.error(e.toString());
      return false;
    }
  }

  Future<bool> updateProfile({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? hiddenFromDiscover,
  }) async {
    state = const ProfileEditState.busy();
    try {
      await _ref.read(profilesRemoteDsProvider).update(
            username: username,
            displayName: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
            hiddenFromDiscover: hiddenFromDiscover,
          );
      _ref.invalidate(currentProfileProvider);
      state = const ProfileEditState.success();
      return true;
    } on PostgrestException catch (e, st) {
      debugPrint('Profile update error: $e\n$st');
      if (e.code == '23505' && (e.message.contains('username') || e.details.toString().contains('username'))) {
        state = const ProfileEditState.error('Username already taken');
      } else {
        state = ProfileEditState.error(e.message);
      }
      return false;
    } catch (e, st) {
      debugPrint('Profile update error: $e\n$st');
      state = ProfileEditState.error(e.toString());
      return false;
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    try {
      return await _ref
          .read(profilesRemoteDsProvider)
          .uploadAvatar(bytes, contentType: contentType);
    } catch (e, st) {
      debugPrint('Avatar upload error: $e\n$st');
      return null;
    }
  }

  void reset() => state = const ProfileEditState.idle();
}

class ProfileEditState {
  final bool isBusy;
  final String? errorMessage;
  final bool success;
  const ProfileEditState._({this.isBusy = false, this.errorMessage, this.success = false});
  const ProfileEditState.idle() : this._();
  const ProfileEditState.busy() : this._(isBusy: true);
  const ProfileEditState.success() : this._(success: true);
  const ProfileEditState.error(String message) : this._(errorMessage: message);
}

final profileEditProvider =
    StateNotifierProvider<ProfileEditNotifier, ProfileEditState>(
  (ref) => ProfileEditNotifier(ref),
);
