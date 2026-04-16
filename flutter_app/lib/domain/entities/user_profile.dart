import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// Public profil — `profiles` Postgres tablosu + `profile_counts` view'inden
/// türetilir. Tüm profiller publictir; herkes okuyabilir, yalnızca sahibi
/// güncelleyebilir.
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    required String username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    @Default(0) int followers,
    @Default(0) int following,
    @Default(false) bool hiddenFromDiscover,
    required DateTime createdAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
