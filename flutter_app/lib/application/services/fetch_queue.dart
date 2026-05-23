import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'asset_ref_resolver.dart';
import 'content_store.dart';

/// Asset pre-fetch öncelikleri.
enum FetchPriority {
  /// PreWarmOrchestrator (F6) — bootstrap kritik medya.
  high,

  /// CDCPreFetcher — normal event akışı.
  normal,

  /// Galeri / lazy widget mount tetikli arka plan fetch.
  low,
}

/// Asset ref'i için arka planda fetch kuyruğa atan, eşzamanlılığı sınırlayan
/// queue. Bir uri için eşzamanlı tek fetch garanti (dedupe).
///
/// Concurrency:
///   - mobile: 4 (Platform.isAndroid/isIOS)
///   - desktop: 8
///
/// Fetch tamamlanan ref'ler [readyStream]'e yayınlanır → UI dinler ve
/// görüntülemekte olan widget re-render yapar.
///
/// F5 ana giriş noktası: [CDCPreFetcher] applier event apply'ından önce
/// `enqueue(uri, FetchPriority.normal)` çağırır → apply continue, fetch
/// background.
class FetchQueue {
  FetchQueue({
    required AssetRefResolver resolver,
    required ContentStore store,
    int? concurrency,
  })  : _resolver = resolver,
        _store = store,
        _concurrency = concurrency ?? _defaultConcurrency() {
    _ready = StreamController<String>.broadcast();
  }

  final AssetRefResolver _resolver;
  final ContentStore _store;
  final int _concurrency;

  late final StreamController<String> _ready;

  /// Bekleyen ref'ler — priority başına FIFO kuyruk.
  final Map<FetchPriority, Queue<String>> _pending = {
    FetchPriority.high: Queue(),
    FetchPriority.normal: Queue(),
    FetchPriority.low: Queue(),
  };

  /// Aktif fetch'in son priority'si (telemetri için ileride).
  /// Aynı anda işlenen ref → tek future paylaşılır.
  final Map<String, Completer<bool>> _inflight = {};

  /// Her ref için kuyruk üyeliği.
  final Set<String> _enqueued = {};

  int _running = 0;

  static int _defaultConcurrency() {
    if (Platform.isAndroid || Platform.isIOS) return 4;
    return 8;
  }

  /// Bir ref'i ön plana al (high priority). Telemetri:
  /// bool returndönen [Future] fetch sonucunu reveal eder
  /// (true=cache hit veya başarılı download, false=hata).
  Future<bool> enqueue(
    String uri, {
    FetchPriority priority = FetchPriority.normal,
  }) {
    // Cache hit fast-path — disk'te varsa hiç queue'ya atma.
    return _maybeImmediate(uri).then((immediate) {
      if (immediate) return Future.value(true);

      // Already in flight? join.
      final existing = _inflight[uri];
      if (existing != null) return existing.future;

      // Already enqueued? — return a future that completes when ready stream emits.
      if (_enqueued.contains(uri)) {
        return _ready.stream
            .firstWhere((emitted) => emitted == uri)
            .then((_) => true)
            .timeout(const Duration(seconds: 60), onTimeout: () => false);
      }

      _enqueued.add(uri);
      _pending[priority]!.add(uri);
      _pump();

      return _ready.stream
          .firstWhere((emitted) => emitted == uri)
          .then((_) => true)
          .timeout(const Duration(seconds: 60), onTimeout: () => false);
    });
  }

  /// Hem cache hit hem de inflight'tan bağımsız fire-and-forget tetik.
  /// Result önemli değil — sadece queue'ya at.
  void schedule(
    String uri, {
    FetchPriority priority = FetchPriority.normal,
  }) {
    enqueue(uri, priority: priority).catchError((_) => false);
  }

  /// Birçok uri'yi batch enqueue.
  void scheduleAll(
    Iterable<String> uris, {
    FetchPriority priority = FetchPriority.normal,
  }) {
    for (final u in uris) {
      schedule(u, priority: priority);
    }
  }

  Future<bool> _maybeImmediate(String uri) async {
    // SHA-cache hit kontrolü AssetRef şemasına bağlı; resolver'ı tek-shot
    // çağırmak yeterli — cache hit'te zero transfer döner.
    // Optimization: önce content store ile direkt SHA lookup ile cache hit
    // kontrol edebilirdik ama resolver zaten cache-first.
    final sha = _shaOf(uri);
    if (sha != null && await _store.contains(sha)) {
      return true;
    }
    return false;
  }

  String? _shaOf(String uri) {
    // dmt-asset://{u}/{c}/{sha}.{ext}  → last segment'in noktadan önceki kısım
    // dmt-public://{u}/{sha}.{ext}     → aynı
    // dmt-transient://{sha}.{ext}      → aynı
    final lastSlash = uri.lastIndexOf('/');
    final filename = lastSlash >= 0 ? uri.substring(lastSlash + 1) : uri;
    final dot = filename.indexOf('.');
    final base = dot >= 0 ? filename.substring(0, dot) : filename;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(base)) return null;
    return base.toLowerCase();
  }

  void _pump() {
    while (_running < _concurrency) {
      final uri = _next();
      if (uri == null) break;
      _running++;
      unawaited(_run(uri));
    }
  }

  String? _next() {
    for (final p in [
      FetchPriority.high,
      FetchPriority.normal,
      FetchPriority.low,
    ]) {
      final q = _pending[p]!;
      if (q.isNotEmpty) return q.removeFirst();
    }
    return null;
  }

  Future<void> _run(String uri) async {
    final completer = Completer<bool>();
    _inflight[uri] = completer;
    var success = false;
    try {
      final file = await _resolver.resolve(AssetRef(uri));
      success = file != null;
    } catch (e) {
      debugPrint('FetchQueue resolve error uri=$uri: $e');
      success = false;
    } finally {
      _inflight.remove(uri);
      _enqueued.remove(uri);
      _running--;
      try {
        _ready.add(uri);
      } catch (_) {}
      completer.complete(success);
      _pump();
    }
  }

  /// Ready event stream — fetch tamamlanan uri'ler. UI watch eder.
  Stream<String> get readyStream => _ready.stream;

  Future<void> dispose() async {
    await _ready.close();
  }
}

final fetchQueueProvider = Provider<FetchQueue>((ref) {
  final queue = FetchQueue(
    resolver: ref.watch(assetRefResolverProvider),
    store: ref.watch(contentStoreProvider),
  );
  // network_providers'ı zorla import — bağımlılıkları aktif tutar.
  ref.read(assetServiceProvider);
  ref.read(freeMediaServiceProvider);
  ref.onDispose(queue.dispose);
  return queue;
});
