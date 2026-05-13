import 'package:freezed_annotation/freezed_annotation.dart';

part 'world_invite.freezed.dart';
part 'world_invite.g.dart';

/// public.world_invites satırı — DM'in oluşturduğu join code.
@freezed
abstract class WorldInvite with _$WorldInvite {
  const factory WorldInvite({
    required String code,
    required String worldId,
    required String createdBy,
    required int usesLeft,
    required DateTime createdAt,
    DateTime? expiresAt,
  }) = _WorldInvite;

  factory WorldInvite.fromJson(Map<String, dynamic> json) =>
      _$WorldInviteFromJson(json);
}
