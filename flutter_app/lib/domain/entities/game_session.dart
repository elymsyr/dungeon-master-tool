import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_session.freezed.dart';
part 'game_session.g.dart';

/// Online game session konsepti — DM'in oluşturduğu masa ve oyuncular.
/// Offline modda her zaman null. Online modda lobi/aktif oyun durumu.
@freezed
abstract class GameSession with _$GameSession {
  const factory GameSession({
    required String sessionId,

    /// 6 karakterlik join code (oyuncuların girdiği).
    required String sessionCode,
    required String campaignId,
    required String hostId,
    required String hostName,
    @Default(<PlayerInfo>[]) List<PlayerInfo> players,
    @Default(SessionStatus.lobby) SessionStatus status,
    DateTime? startedAt,
  }) = _GameSession;

  factory GameSession.fromJson(Map<String, dynamic> json) =>
      _$GameSessionFromJson(json);
}

@freezed
abstract class PlayerInfo with _$PlayerInfo {
  const factory PlayerInfo({
    required String playerId,
    required String displayName,
    @Default(PlayerConnectionState.connected) PlayerConnectionState connectionState,

    /// Hangi PC entity'sini kontrol ediyor.
    String? entityId,
  }) = _PlayerInfo;

  factory PlayerInfo.fromJson(Map<String, dynamic> json) =>
      _$PlayerInfoFromJson(json);
}

enum SessionStatus { lobby, active, paused, ended }

enum PlayerConnectionState { connected, disconnected, reconnecting }
