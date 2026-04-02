import 'dart:async';

/// Cross-cutting event. NetworkBridge entegrasyon noktası.
class AppEvent {
  final String type;
  final Map<String, dynamic> payload;

  const AppEvent(this.type, [this.payload = const {}]);
}

/// Application-wide pub/sub event bus.
/// Python'daki core/event_bus.py karşılığı.
class AppEventBus {
  final _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get stream => _controller.stream;

  void emit(AppEvent event) => _controller.add(event);

  StreamSubscription<AppEvent> on(
    String eventType,
    void Function(AppEvent) handler,
  ) {
    return _controller.stream
        .where((e) => e.type == eventType)
        .listen(handler);
  }

  void dispose() => _controller.close();
}
