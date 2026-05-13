import 'package:freezed_annotation/freezed_annotation.dart';

import 'world_role.dart';

part 'world_member.freezed.dart';
part 'world_member.g.dart';

/// public.world_members satırı — bir world'ün üyeliği.
@freezed
abstract class WorldMember with _$WorldMember {
  const factory WorldMember({
    required String worldId,
    required String userId,
    required WorldRole role,
    required DateTime joinedAt,
    /// Display amaçlı — public.profiles join'inden gelir, raw tabloda yok.
    String? username,
    String? displayName,
    String? avatarUrl,
  }) = _WorldMember;

  factory WorldMember.fromJson(Map<String, dynamic> json) =>
      _$WorldMemberFromJson(json);
}
