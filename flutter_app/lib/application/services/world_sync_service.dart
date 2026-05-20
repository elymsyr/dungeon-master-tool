import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// World-scoped Supabase Realtime sync orchestrator.
///
/// Sorumluluk: bir online worldün Supabase mirror tablolarına abone olmak,
/// gelen CDC event'lerini lokal Drift tabanlı repository hook'larına
/// iletmek. Lokal yazımları Supabase'e mirror etmek (outbox + reconcile)
/// PR-O4'te eklenir.
///
/// Bu PR (PR-O2) **skeleton**: subscribe/unsubscribe + raw event stream.
/// `apply*` callback'leri PR-O4'te repository sync hook'larına bağlanır.
class WorldSyncService {
  final SupabaseClient client;

  WorldSyncService(this.client);

  /// Aktif olarak subscribe edilen worldlerin channel handle'ları.
  final Map<String, RealtimeChannel> _channels = {};

  /// worldId → `SUBSCRIBED` callback. Reconnect sonrası tekrar çağrılır,
  /// resubscribe retry'ında da yeniden kullanılır.
  final Map<String, void Function()> _onSubscribedCbs = {};

  /// channelError/timedOut sonrası bekleyen resubscribe timer'ları.
  final Map<String, Timer> _resubTimers = {};

  /// worldId → ardışık resubscribe denemesi sayısı (exponential backoff).
  final Map<String, int> _retryCounts = {};

  bool _disposed = false;

  /// Birleştirilmiş event stream — tüm subscribe edilen worldlerden CDC
  /// payload'ları yayar. UI/sync hook'ları dinler.
  final _events = StreamController<WorldSyncEvent>.broadcast();
  Stream<WorldSyncEvent> get events => _events.stream;

  bool isSubscribed(String worldId) => _channels.containsKey(worldId);

  /// World mirror'ı için subscribe başlat. İdempotent — zaten varsa no-op.
  ///
  /// [onSubscribed] channel her `SUBSCRIBED` durumuna geçtiğinde çağrılır —
  /// hem ilk bağlanma hem de **her reconnect**. postgres_changes kesinti
  /// sırasındaki event'leri replay etmez; bu yüzden callback bir catch-up
  /// (initial state + roster) tetikler. Aynı worldId için ikinci subscribe
  /// çağrısında callback hemen tetiklenir (channel zaten subscribed).
  Future<void> subscribe(String worldId,
      {void Function()? onSubscribed}) async {
    if (_disposed) return;
    if (onSubscribed != null) _onSubscribedCbs[worldId] = onSubscribed;
    if (_channels.containsKey(worldId)) {
      if (onSubscribed != null) {
        scheduleMicrotask(onSubscribed);
      }
      return;
    }

    final channel = client.channel('dmt:world:$worldId');
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'world_id',
      value: worldId,
    );

    for (final table in _mirrorTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (payload) => _dispatch(worldId, table, payload),
      );
    }
    // worlds tablosu world_id sütununa sahip değil; ayrı filter id ile.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'worlds',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: worldId,
      ),
      callback: (payload) => _dispatch(worldId, 'worlds', payload),
    );

    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          // Her SUBSCRIBED'da catch-up — ilk bağlanma + her reconnect.
          _retryCounts.remove(worldId);
          _onSubscribedCbs[worldId]?.call();
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          debugPrint(
              'WorldSyncService channel "$worldId" $status: $error');
          _scheduleResubscribe(worldId);
        case RealtimeSubscribeStatus.closed:
          // Kasıtlı unsubscribe / socket teardown — resubscribe etme.
          break;
      }
    });
    _channels[worldId] = channel;
  }

  /// channelError / timedOut sonrası exponential backoff ile yeniden
  /// subscribe et. Başarısız bir join sessizce kalıcı ölü kanal bırakmasın.
  void _scheduleResubscribe(String worldId) {
    if (_disposed) return;
    if (_resubTimers.containsKey(worldId)) return;
    final attempt = (_retryCounts[worldId] ?? 0) + 1;
    _retryCounts[worldId] = attempt;
    // 1, 2, 4, 8, 16, 30 (cap) saniye.
    final secs = (1 << (attempt - 1)).clamp(1, 30);
    _resubTimers[worldId] = Timer(Duration(seconds: secs), () async {
      _resubTimers.remove(worldId);
      if (_disposed) return;
      // External unsubscribe bu timer'ı iptal eder — buraya geldiysek
      // kanal hâlâ istenen durumda.
      final cb = _onSubscribedCbs[worldId];
      await _removeChannel(worldId);
      if (_disposed) return;
      await subscribe(worldId, onSubscribed: cb);
    });
  }

  Future<void> _removeChannel(String worldId) async {
    final ch = _channels.remove(worldId);
    if (ch == null) return;
    await client.removeChannel(ch);
  }

  Future<void> unsubscribe(String worldId) async {
    _resubTimers.remove(worldId)?.cancel();
    _onSubscribedCbs.remove(worldId);
    _retryCounts.remove(worldId);
    await _removeChannel(worldId);
  }

  Future<void> unsubscribeAll() async {
    final ids = _channels.keys.toList();
    for (final id in ids) {
      await unsubscribe(id);
    }
  }

  void _dispatch(
      String worldId, String table, PostgresChangePayload payload) {
    _events.add(
      WorldSyncEvent(
        worldId: worldId,
        table: table,
        eventType: payload.eventType,
        newRecord: payload.newRecord,
        oldRecord: payload.oldRecord,
      ),
    );
  }

  /// world_id sütunu olan mirror tabloları.
  static const _mirrorTables = <String>[
    'world_members',
    'world_entities',
    'world_mind_map_nodes',
    'world_mind_map_edges',
    'world_characters',
    'entity_shares',
    // PR-SYNC-3: granular replacements for the worlds.state_json blob.
    'world_map_data',
    'world_sessions',
    'world_settings',
    // PR-SYNC-5: DM-shared package mirror.
    'world_packages',
  ];

  Future<void> dispose() async {
    _disposed = true;
    for (final t in _resubTimers.values) {
      t.cancel();
    }
    _resubTimers.clear();
    _onSubscribedCbs.clear();
    _retryCounts.clear();
    await unsubscribeAll();
    await _events.close();
  }
}

/// Bir mirror tablosundan gelen tek CDC event.
class WorldSyncEvent {
  final String worldId;
  final String table;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;

  const WorldSyncEvent({
    required this.worldId,
    required this.table,
    required this.eventType,
    required this.newRecord,
    required this.oldRecord,
  });
}
