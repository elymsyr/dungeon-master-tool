import 'dart:async';
import 'dart:io';

/// Thrown by network-guarded providers when the device is offline or a
/// request exceeds its hard timeout. Recognized by [isOfflineError] so the
/// UI collapses it into the single "You're offline" message.
class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => 'OfflineException';
}

/// True when [error] looks like a transient offline / network failure
/// (no DNS, no route, TLS handshake failed, socket refused, timeout).
///
/// `package:http`'s `ClientException` and Supabase's
/// `AuthRetryableFetchException` are matched by class name rather than
/// type check so this helper can live in `core/` without dragging in a
/// direct `http` / `supabase` dependency.
bool isOfflineError(Object error) {
  if (error is OfflineException) return true;
  if (error is SocketException) return true;
  if (error is HandshakeException) return true;
  if (error is TimeoutException) return true;
  if (error is HttpException) return true;
  final rt = error.runtimeType.toString();
  if (rt == 'ClientException') return true;
  if (rt == 'AuthRetryableFetchException') return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('failed host lookup') ||
      msg.contains('no address associated with hostname') ||
      msg.contains('connection refused') ||
      msg.contains('connection closed') ||
      msg.contains('network is unreachable') ||
      msg.contains('operation not permitted') ||
      msg.contains('software caused connection abort') ||
      msg.contains('clientexception') ||
      msg.contains('failed to fetch') ||
      msg.contains('socketexception') ||
      msg.contains('connection timed out') ||
      msg.contains('xmlhttprequest');
}

/// True when [error] is a Supabase Storage 404 (object not found). Used by
/// catch-up flows to detect orphaned `cloud_backups` rows whose storage
/// file is missing — so the meta row can be cleaned up and the spam log
/// suppressed. Matches by message because the SDK's `StorageException`
/// reports a String `statusCode` field and we don't want to import the
/// supabase package into `core/`.
bool isStorageNotFound(Object error) {
  if (error.runtimeType.toString() != 'StorageException') return false;
  final msg = error.toString().toLowerCase();
  return msg.contains('"statuscode":"404"') ||
      msg.contains("'statuscode': '404'") ||
      msg.contains('not_found') ||
      msg.contains('object not found');
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
