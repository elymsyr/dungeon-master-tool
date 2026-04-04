import '../entities/session.dart';

/// Session persistence interface.
abstract class SessionRepository {
  /// Load combat state from campaign data.
  Map<String, dynamic>? loadCombatState();

  /// Save combat state to campaign data.
  void saveCombatState(Map<String, dynamic> state);

  /// Load all sessions.
  List<Session> loadSessions();

  /// Save a session.
  void saveSession(Session session);

  /// Delete a session.
  void deleteSession(String sessionId);
}
