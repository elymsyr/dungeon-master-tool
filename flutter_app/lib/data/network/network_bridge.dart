import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/game_snapshot.dart';

/// Network bridge interface — Flutter'ın online katmana arayüzü.
/// Offline: NoOpNetworkBridge. Online (future): SupabaseNetworkBridge.
///
/// Python core/network/bridge.py ile simetrik olarak tasarlanmıştır.
abstract class NetworkBridge {
  /// Şu an bağlı mı?
  bool get isConnected;

  /// Bağlantı durumu stream'i.
  Stream<bool> get connectionState;

  /// Sunucuya bağlan (oyun masası kodu ile).
  Future<void> connect(String sessionCode);

  /// Bağlantıyı kapat.
  Future<void> disconnect();

  /// Event'i broadcast et — tüm bağlı oyunculara gönderir.
  /// Offline'da no-op.
  Future<void> broadcast(EventEnvelope event);

  /// Remote'tan gelen event'ler. Offline'da boş stream.
  Stream<EventEnvelope> get incomingEvents;

  /// Belirli bir oyuncuya snapshot gönder (sync_request cevabı).
  Future<void> sendSnapshot(String targetPlayerId, GameSnapshot snapshot);

  /// Kaynakları temizle.
  void dispose();
}
