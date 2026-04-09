import 'dart:async';

import '../../domain/entities/game_session.dart';
import 'session_manager.dart';

/// Offline default — session yönetimi yok.
class NoOpSessionManager implements SessionManager {
  final _controller = StreamController<GameSession?>.broadcast();

  @override
  GameSession? get currentSession => null;

  @override
  Stream<GameSession?> get sessionUpdates => _controller.stream;

  @override
  Future<GameSession> createSession(String campaignId) {
    throw UnsupportedError(
        'Online session creation requires NetworkBridge implementation');
  }

  @override
  Future<GameSession> joinSession(String sessionCode) {
    throw UnsupportedError(
        'Online session joining requires NetworkBridge implementation');
  }

  @override
  Future<void> leaveSession() async {
    // No-op
  }

  @override
  void dispose() {
    _controller.close();
  }
}
