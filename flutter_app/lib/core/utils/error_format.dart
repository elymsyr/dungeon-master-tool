import 'dart:async';
import 'dart:io';

/// True when [error] looks like a transient offline / network failure
/// (no DNS, no route, TLS handshake failed, socket refused, timeout).
///
/// `package:http`'s `ClientException` is matched by class name rather than
/// type check so this helper can live in `core/` without dragging in a
/// direct `http` dependency.
bool isOfflineError(Object error) {
  if (error is SocketException) return true;
  if (error is HandshakeException) return true;
  if (error is TimeoutException) return true;
  if (error is HttpException) return true;
  if (error.runtimeType.toString() == 'ClientException') return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('failed host lookup') ||
      msg.contains('no address associated with hostname') ||
      msg.contains('connection refused') ||
      msg.contains('connection closed') ||
      msg.contains('network is unreachable') ||
      msg.contains('operation not permitted') ||
      msg.contains('software caused connection abort') ||
      msg.contains('clientexception');
}

/// Human-readable error text for display in the UI. Collapses network
/// failures into a single "You're offline" string so raw SocketException /
/// ClientException stack text never leaks into cards, snackbars, or dialogs.
String formatError(Object error) {
  if (isOfflineError(error)) {
    return "You're offline — check your internet connection.";
  }
  return error.toString();
}
