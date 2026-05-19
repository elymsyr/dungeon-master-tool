import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tipe göre debounce penceresi. Aynı (kind, key) için ardışık schedule
/// timer'ı reset eder; tek fire'da en son closure çalışır. Settings
/// patch'leri için key'i (örn. `"settings:$worldId:combat_state"`) ile
/// anahtarlayarak farklı patch tipleri bağımsız fire'lansın.
///
/// Effective window = `kind.window`. Tier çarpanı kaldırıldı — yalnızca
/// `SyncTier.cloudDelay` outbox push'unu etkiler (sync_engine).
enum WriteKind {
  /// 750ms — HP/AC/level/CR/sayısal stat.
  shortNumber,

  /// 1500ms — name, source, single-line identifier.
  shortText,

  /// 2000ms — description, dm_notes, multi-line text.
  longText,

  /// 1000ms — tags, pdfs, images, linked refs.
  listEdit,

  /// 1000ms — map pin drag, mind map node move.
  spatial,

  /// 500ms — combat_state mutation. Snappy bağlı kalır.
  combatTick,

  /// 2000ms — pan/zoom/camera/scroll. Motion-class field; pair with
  /// `CampaignNotifier.saveSettingsPatchLocalOnly` — local Drift'e yazılır,
  /// outbox'a girmez. Reset-on-edit: PendingWriteBuffer aynı key için yeni
  /// schedule'da timer'ı cancel + reset zaten yapıyor.
  viewport,

  /// 0ms — addEntities import, paste, delete (hemen fire).
  immediate;

  Duration get window => switch (this) {
        shortNumber => const Duration(milliseconds: 750),
        shortText => const Duration(milliseconds: 1500),
        longText => const Duration(milliseconds: 2000),
        listEdit => const Duration(milliseconds: 1000),
        spatial => const Duration(milliseconds: 1000),
        combatTick => const Duration(milliseconds: 500),
        viewport => const Duration(milliseconds: 2000),
        immediate => Duration.zero,
      };
}

class _PendingWrite {
  _PendingWrite(this.timer, this.action);
  final Timer timer;
  final FutureOr<void> Function() action;
}

/// Debounced row-level write coalescer. Caller schedules a write with a
/// stable [key] (örn. `"entity:$worldId:$entityId"`) ve [WriteKind]; aynı
/// key için yeni schedule timer'ı reset eder ve action closure'unu son
/// gelenle değiştirir. Timer fire'ında action sync veya async çağrılır.
///
/// Flush hook'ları (app close, world close, dispose) pending'leri hemen
/// drain etmek için `flush()` veya `flushPrefix(...)` kullanır.
///
/// CDC race guard: remote applier'lar `isPending(key)` / `hasPendingPrefix`
/// kontrol eder; pending varken remote event apply edilmez, trailing local
/// fire LWW kazanır.
class PendingWriteBuffer {
  PendingWriteBuffer(this._ref);
  // ignore: unused_field
  final Ref _ref;

  final Map<String, _PendingWrite> _pending = {};

  /// Pending count + fire event'leri için tick — saveStateProvider gibi
  /// listener'lar dirty/saved transition'larını buradan görür.
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  void _bumpTick() => tick.value++;

  /// [key] yeni schedule'da action ve timer reset. Effective duration =
  /// `kind.window`. Action async ise Future throw'ları yutulur (debugPrint).
  void schedule({
    required String key,
    required WriteKind kind,
    required FutureOr<void> Function() action,
  }) {
    _pending.remove(key)?.timer.cancel();
    final duration = kind.window;
    if (kind == WriteKind.immediate || duration == Duration.zero) {
      _run(action);
      _bumpTick();
      return;
    }
    final timer = Timer(duration, () {
      final entry = _pending.remove(key);
      if (entry == null) return;
      _run(entry.action);
      _bumpTick();
    });
    _pending[key] = _PendingWrite(timer, action);
    _bumpTick();
  }

  /// Tüm pending'leri hemen fire'la. Timer'lar iptal, action'lar sırayla
  /// await edilir. Bekleyen iş yoksa no-op.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final entries = _pending.entries.toList();
    _pending.clear();
    for (final e in entries) {
      e.value.timer.cancel();
      try {
        await e.value.action();
      } catch (err, st) {
        debugPrint('PendingWriteBuffer flush(${e.key}): $err\n$st');
      }
    }
    _bumpTick();
  }

  /// Belirli prefix'li key'leri flush et (örn. world close →
  /// `flushPrefix("world:$worldId")`).
  Future<void> flushPrefix(String prefix) async {
    final keys = _pending.keys.where((k) => k.startsWith(prefix)).toList();
    if (keys.isEmpty) return;
    for (final k in keys) {
      final entry = _pending.remove(k);
      if (entry == null) continue;
      entry.timer.cancel();
      try {
        await entry.action();
      } catch (err, st) {
        debugPrint('PendingWriteBuffer flushPrefix($k): $err\n$st');
      }
    }
    _bumpTick();
  }

  /// Pending kaldı mı? UI dirty indicator için.
  bool get hasPending => _pending.isNotEmpty;

  int get pendingCount => _pending.length;

  /// Belirli key pending mi (CDC race guard + test).
  bool isPending(String key) => _pending.containsKey(key);

  /// Prefix ile başlayan key'lerden biri pending mi?
  bool hasPendingPrefix(String prefix) =>
      _pending.keys.any((k) => k.startsWith(prefix));

  /// Pending key listesi (prefix filter). Settings subkey merge'de kullanılır.
  Iterable<String> pendingKeysWithPrefix(String prefix) =>
      _pending.keys.where((k) => k.startsWith(prefix));

  void _run(FutureOr<void> Function() action) {
    final result = action();
    if (result is Future) {
      result.catchError((Object e, StackTrace st) {
        debugPrint('PendingWriteBuffer fire error: $e\n$st');
      });
    }
  }
}

final pendingWriteBufferProvider =
    Provider<PendingWriteBuffer>((ref) => PendingWriteBuffer(ref));
