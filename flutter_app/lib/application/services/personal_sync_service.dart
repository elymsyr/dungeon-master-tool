import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-user Supabase Realtime sync orchestrator.
///
/// Tek bir `dmt:user:{uid}` kanal'ı şu tablolardaki INSERT/UPDATE/DELETE
/// event'lerini dinler:
///   - `personal_characters` (`owner_id = uid`) — char cross-device sync
///   - `personal_packages`   (`owner_id = uid`) — package cross-device sync
///   - `world_members`       (`user_id  = uid`) — join/leave karşı cihazlara
///     anlık yansısın (kullanıcı Device A'da join etti → Device B'de world
///     listesi otomatik refresh)
///
/// Bu service kanalı yönetir ve event'leri tek `Stream<PersonalSyncEvent>`
/// içinden yayar. Apply mantığı `PersonalMirrorApplier`'da.
class PersonalSyncService {
  final SupabaseClient client;

  PersonalSyncService(this.client);

  RealtimeChannel? _channel;
  String? _activeUid;
  Future<void>? _starting;

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
    if (_activeUid == uid && _channel != null) return;
    await stop();

    final channel = client.channel('dmt:user:$uid');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'personal_characters',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'owner_id',
        value: uid,
      ),
      callback: (payload) =>
          _dispatch('personal_characters', payload),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'personal_packages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'owner_id',
        value: uid,
      ),
      callback: (payload) =>
          _dispatch('personal_packages', payload),
    );

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

    channel.subscribe();
    _channel = channel;
    _activeUid = uid;
  }

  Future<void> stop() async {
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
