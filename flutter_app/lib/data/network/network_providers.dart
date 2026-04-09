import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_bridge.dart';
import 'no_op_network_bridge.dart';
import 'no_op_session_manager.dart';
import 'session_manager.dart';

/// NetworkBridge provider — default: NoOp (offline).
/// Online'a geçildiğinde override ile SupabaseNetworkBridge enjekte edilir.
final networkBridgeProvider = Provider<NetworkBridge>((ref) {
  final bridge = NoOpNetworkBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// SessionManager provider — default: NoOp (offline).
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = NoOpSessionManager();
  ref.onDispose(manager.dispose);
  return manager;
});
