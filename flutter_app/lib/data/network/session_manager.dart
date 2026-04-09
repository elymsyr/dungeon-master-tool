import '../../domain/entities/game_session.dart';

/// Online game session lifecycle yönetimi.
/// Offline: NoOpSessionManager. Online (future): SupabaseSessionManager.
abstract class SessionManager {
  /// Şu anki aktif session (yoksa null).
  GameSession? get currentSession;

  /// Session değişikliklerini izle.
  Stream<GameSession?> get sessionUpdates;

  /// Yeni online session oluştur (DM rolü).
  Future<GameSession> createSession(String campaignId);

  /// Mevcut session'a katıl (player rolü).
  Future<GameSession> joinSession(String sessionCode);

  /// Session'dan ayrıl.
  Future<void> leaveSession();

  /// Kaynakları temizle.
  void dispose();
}
