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

  /// worldId → "kendim dışında en az bir üye kanalda" (oturum kapısı).
  final Map<String, bool> _sessionOpen = {};

  /// Aynı anda açık tutulabilecek kanal sayısı tavanı (R3). Normalde aktif
  /// dünya provider dispose'da unsubscribe eder → ~1 kanal; bu tavan uzun
  /// oturumda dünya gezerken kazara sızıntıya karşı defansif ağ.
  static const int _maxChannels = 6;

  bool _disposed = false;

  /// Birleştirilmiş event stream — tüm subscribe edilen worldlerden CDC
  /// payload'ları yayar. UI/sync hook'ları dinler.
  final _events = StreamController<WorldSyncEvent>.broadcast();
  Stream<WorldSyncEvent> get events => _events.stream;

  /// Oturum kapısı — `(worldId, open)` yalnızca DEĞİŞTİĞİNDE yayılır.
  ///
  /// "Oturum açık" = kanalda benden başka en az bir üye var. Buton, kolon ya
  /// da RPC yok: `dmt:world:{id}` kanalı zaten hem DM'de hem oyuncuda açık,
  /// Supabase Presence onun üstünde bedava geliyor — DM oturum başlatmayı
  /// unutamaz, çünkü başlatacağı bir şey yok.
  ///
  /// Sunucu tarafı zorlaması DEĞİL: presence Postgres'ten okunamaz, bir RPC
  /// "oturum kapalıyken transient'e yazma" diye reddedemez. Kapı bir güvenlik
  /// sınırı değil, israf önleyici — transient'e yazan tek şey DM'in kendi
  /// client'ı ve dosya başı 100 MB + havuz LRU emniyet kapağı zaten duruyor.
  final _sessions = StreamController<({String worldId, bool open})>.broadcast();
  Stream<({String worldId, bool open})> get sessions => _sessions.stream;

  /// [worldId] için oturum açık mı (kanal yoksa / presence boşsa false).
  bool isSessionOpen(String worldId) => _sessionOpen[worldId] ?? false;

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

    // R3: tavan aşıldıysa en eski kanalı (insertion-order ilk) kapat.
    while (_channels.length >= _maxChannels) {
      final oldest = _channels.keys.first;
      debugPrint('WorldSyncService channel cap: evicting "$oldest"');
      await unsubscribe(oldest);
    }

    // Presence key = kullanıcı id'si, böylece `presenceState()` anahtarları
    // doğrudan üye kimlikleri olur ve "benden başkası var mı" tek karşılaştırma.
    final selfUid = client.auth.currentUser?.id ?? '';
    final channel = client.channel(
      'dmt:world:$worldId',
      opts: RealtimeChannelConfig(key: selfUid, enabled: selfUid.isNotEmpty),
    );
    if (selfUid.isNotEmpty) {
      channel.onPresenceSync((_) => _updateSession(worldId, channel, selfUid));
    }
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
          if (selfUid.isNotEmpty) {
            // track() ancak SUBSCRIBED sonrası gönderilebilir. Hata yutulur:
            // presence düşerse kapı kapanır, veri kaybı olmaz (bekleyen
            // `missing_shas` kalıcı, bağlantı dönünce karşılanır).
            channel.track({'uid': selfUid}).ignore();
          }
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

  /// Presence state'inden oturum kapısını türetir; yalnızca değişimde yayar.
  void _updateSession(String worldId, RealtimeChannel channel, String selfUid) {
    if (_disposed) return;
    final open = channel
        .presenceState()
        .any((s) => s.key.isNotEmpty && s.key != selfUid);
    if (_sessionOpen[worldId] == open) return;
    _sessionOpen[worldId] = open;
    if (!_sessions.isClosed) _sessions.add((worldId: worldId, open: open));
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
    if (_sessionOpen.remove(worldId) == true && !_sessions.isClosed) {
      _sessions.add((worldId: worldId, open: false));
    }
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

  /// Oyuncuya canlı akan tablolar — hepsi DM'in bilinçli bir paylaşımı.
  ///
  /// Tam dünya aynası kaldırıldı: entity / harita / oturum / ayar / mind-map
  /// artık replike EDİLMEZ. Bu listeye tablo eklemek, oyuncunun cihazına
  /// DM'in paylaşmadığı veri göndermek demektir — önce paylaşım eylemi neyse
  /// onu tanımla, sonra tabloyu ekle.
  static const _mirrorTables = <String>[
    // DM'in canlı yayını (projeksiyon manifesti).
    'world_projection',
    // DM'in paylaştığı kartlar — gövdeleri payload_json'da.
    'entity_shares',
    // Oyuncunun karakter sayfası (claim/assign dahil).
    'world_characters',
    // DM'in dünyaya paylaştığı paketler.
    'world_packages',
    // Üyelik / rol.
    'world_members',
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
    _sessionOpen.clear();
    await _events.close();
    await _sessions.close();
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
