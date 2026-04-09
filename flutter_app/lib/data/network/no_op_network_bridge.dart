import 'dart:async';

import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/game_snapshot.dart';
import 'network_bridge.dart';

/// Default offline implementasyon — tüm metotlar no-op.
/// Online'a geçildiğinde SupabaseNetworkBridge ile değiştirilir.
class NoOpNetworkBridge implements NetworkBridge {
  final _connectionController = StreamController<bool>.broadcast();
  final _incomingController = StreamController<EventEnvelope>.broadcast();

  @override
  bool get isConnected => false;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  Stream<EventEnvelope> get incomingEvents => _incomingController.stream;

  @override
  Future<void> connect(String sessionCode) async {
    // Offline mode — hiçbir şey yapma
  }

  @override
  Future<void> disconnect() async {
    // Offline mode — hiçbir şey yapma
  }

  @override
  Future<void> broadcast(EventEnvelope event) async {
    // Offline mode — event sadece local stream'de kalır
  }

  @override
  Future<void> sendSnapshot(
      String targetPlayerId, GameSnapshot snapshot) async {
    // Offline mode — hiçbir şey yapma
  }

  @override
  void dispose() {
    _connectionController.close();
    _incomingController.close();
  }
}
