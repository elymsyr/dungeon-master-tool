import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/event_bus.dart';

/// Singleton AppEventBus provider — tüm notifier'lar aynı bus instance'ını
/// paylaşır. NetworkBridge de bu provider üzerinden bus'a erişir.
final eventBusProvider = Provider<AppEventBus>((ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
