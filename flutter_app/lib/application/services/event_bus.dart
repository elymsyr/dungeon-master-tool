import 'dart:async';

import '../../domain/entities/events/event_envelope.dart';

/// Future NetworkBridge bu callback'i kaydedecek.
/// true dönerse event local subscriber'lara da iletilir, false dönerse sadece
/// remote'a gider (şimdilik her zaman true — saf offline mod).
typedef EventInterceptor = Future<bool> Function(EventEnvelope event);

/// Application-wide pub/sub event bus.
/// Python'daki core/event_bus.py karşılığı.
///
/// NetworkBridge entegrasyon noktası: [interceptor] kaydedilerek tüm
/// event'ler online'a forward edilebilir. interceptor == null → saf offline.
class AppEventBus {
  final _controller = StreamController<EventEnvelope>.broadcast();

  /// Future NetworkBridge bu field'a kendi handler'ını kaydeder.
  EventInterceptor? interceptor;

  /// Tüm event'lerin stream'i — NetworkBridge tap noktası.
  Stream<EventEnvelope> get allEvents => _controller.stream;

  /// Event yayınla. interceptor varsa önce ona iletir.
  void emit(EventEnvelope event) {
    if (interceptor != null) {
      interceptor!(event).then((propagateLocally) {
        if (propagateLocally) _controller.add(event);
      });
    } else {
      _controller.add(event);
    }
  }

  /// Belirli bir event type'ı dinle.
  StreamSubscription<EventEnvelope> on(
    String eventType,
    void Function(EventEnvelope) handler,
  ) {
    return _controller.stream
        .where((e) => e.eventType == eventType)
        .listen(handler);
  }

  /// Remote'dan gelen event'i local stream'e inject et.
  /// Future NetworkBridge bu metodu çağırarak remote event'leri
  /// local subscriber'lara iletir.
  void injectRemote(EventEnvelope event) => _controller.add(event);

  void dispose() => _controller.close();
}
