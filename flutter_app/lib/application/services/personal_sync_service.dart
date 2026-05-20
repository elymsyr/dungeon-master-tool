import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-user Supabase Realtime sync orchestrator.
///
/// Tek bir `dmt:user:{uid}` kanal'ı şu tablolardaki INSERT/UPDATE/DELETE
/// event'lerini dinler:
///   - `world_members` (`user_id = uid`) — join/leave karşı cihazlara anlık
///     yansısın (kullanıcı Device A'da join etti → Device B'de world listesi
///     otomatik refresh)
///   - `world_characters` (`owner_id = uid`) — owner'ın online-dünya
///     karakteri, dünya açık olmasa da (hub char tab) sahibinin her cihazına
///     canlı yansısın. Apply `WorldMirrorApplier.applyCharacterCdc` ile ortak.
///
/// **Realtime YOK** (PR-3): paket ve worldless karakter senkronu cloud-save
/// only — `personal_packages`, `personal_package_entities`, `cloud_backups`
/// CDC subscribe edilmez. Cross-device pull = app-open bootstrap (auto via
/// `personalMirrorApplierProvider`) + manuel "Sync" butonu.
///
/// `personal_characters` 040'da retire edildi; world-bound char cross-device
/// sync `world_characters` CDC + RLS üzerinden çalışır
/// (`world_mirror_applier`).
///
/// Apply mantığı `PersonalMirrorApplier`'da.
class PersonalSyncService {
  final SupabaseClient client;

  PersonalSyncService(this.client);

  RealtimeChannel? _channel;
  String? _activeUid;
  Future<void>? _starting;

  /// channelError / timedOut sonrası bekleyen resubscribe timer'ı.
  Timer? _resubTimer;
  int _retryCount = 0;
  bool _disposed = false;

  final _events = StreamController<PersonalSyncEvent>.broadcast();
  Stream<PersonalSyncEvent> get events => _events.stream;

  bool get isActive => _channel != null;
  String? get activeUid => _activeUid;

  /// Idempotent — aynı uid için tekrar çağrı no-op.
  /// Farklı uid (auth switch) → eski kanalı kapatıp yenisini açar.
  Future<void> start(String uid) {
    if (_activeUid == uid && _channel != null) {
      return Future<void>.value();
    }
    // Coalesce concurrent start() calls for the same uid — without this,
    // a provider re-eval during the async channel setup could enter start()
    // a second time and trigger duplicate bootstrap callbacks.
    final inFlight = _starting;
    if (inFlight != null) return inFlight;
    final future = _doStart(uid);
    _starting = future.whenComplete(() => _starting = null);
    return _starting!;
  }

  Future<void> _doStart(String uid) async {
    if (_disposed) return;
    if (_activeUid == uid && _channel != null) return;
    await stop();
    if (_disposed) return;

    final channel = client.channel('dmt:user:$uid');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'world_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (payload) =>
          _dispatch('world_members', payload),
    );

    // Owner'ın online-dünya karakterleri — dünya açık olmasa da (hub char
    // tab) sahibinin her cihazına canlı yansısın. RLS "Chars: player reads
    // own" (owner_id = auth.uid()) bu filtreye izin verir.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'world_characters',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'owner_id',
        value: uid,
      ),
      callback: (payload) => _dispatch('world_characters', payload),
    );

    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _retryCount = 0;
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          debugPrint('PersonalSyncService channel $status: $error');
          _scheduleResubscribe(uid);
        case RealtimeSubscribeStatus.closed:
          // Kasıtlı stop() / socket teardown — resubscribe etme.
          break;
      }
    });
    _channel = channel;
    _activeUid = uid;
  }

  /// channelError / timedOut sonrası exponential backoff ile yeniden kur.
  void _scheduleResubscribe(String uid) {
    if (_disposed || _resubTimer != null || _activeUid != uid) return;
    _retryCount++;
    final secs = (1 << (_retryCount - 1)).clamp(1, 30);
    _resubTimer = Timer(Duration(seconds: secs), () async {
      _resubTimer = null;
      if (_disposed || _activeUid != uid) return;
      // Hatalı kanalı at, sıfırdan kur.
      _activeUid = null;
      await _doStart(uid);
    });
  }

  Future<void> stop() async {
    _resubTimer?.cancel();
    _resubTimer = null;
    final ch = _channel;
    _channel = null;
    _activeUid = null;
    if (ch != null) {
      await client.removeChannel(ch);
    }
  }

  void _dispatch(String table, PostgresChangePayload payload) {
    _events.add(
      PersonalSyncEvent(
        table: table,
        eventType: payload.eventType,
        newRecord: payload.newRecord,
        oldRecord: payload.oldRecord,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _events.close();
  }
}

class PersonalSyncEvent {
  final String table;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;

  const PersonalSyncEvent({
    required this.table,
    required this.eventType,
    required this.newRecord,
    required this.oldRecord,
  });
}
