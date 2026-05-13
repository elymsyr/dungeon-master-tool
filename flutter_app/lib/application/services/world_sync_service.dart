import 'dart:async';

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

  /// Birleştirilmiş event stream — tüm subscribe edilen worldlerden CDC
  /// payload'ları yayar. UI/sync hook'ları dinler.
  final _events = StreamController<WorldSyncEvent>.broadcast();
  Stream<WorldSyncEvent> get events => _events.stream;

  bool isSubscribed(String worldId) => _channels.containsKey(worldId);

  /// World mirror'ı için subscribe başlat. İdempotent — zaten varsa no-op.
  Future<void> subscribe(String worldId) async {
    if (_channels.containsKey(worldId)) return;

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

    channel.subscribe();
    _channels[worldId] = channel;
  }

  Future<void> unsubscribe(String worldId) async {
    final ch = _channels.remove(worldId);
    if (ch == null) return;
    await client.removeChannel(ch);
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
    'character_claim_pool',
  ];

  Future<void> dispose() async {
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
