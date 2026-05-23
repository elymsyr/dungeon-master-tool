import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import 'content_store.dart';
import 'reference_graph.dart';

/// Local cache reference-counted + LRU eviction.
///
/// Plan F4 — politika:
///   1) `asset_refs`'te uri YOKSA → orphan → `ContentStore.delete(sha)` +
///      DM ise cloud objesini de sil (`AssetService.deleteAsset` /
///      `FreeMediaService.deleteFreeMedia`, `keepCache:false`).
///   2) Toplam cache size budget'ı aşıyorsa → LRU: en eski `last_access_at`'i
///      olan bin dosyalarından, referans olsa dahi sil (sonraki resolve
///      re-fetch eder).
///
/// Budget defaultları:
///   - mobile (Android/iOS): 200 MB
///   - desktop (Linux/macOS/Windows): 1 GB
///
/// Trigger çağrı yerleri (F5/F10'da bağlanır):
///   - CDC apply batch sonrası
///   - DM write commit (debounced ~5sn)
///   - Entity / world delete cleanup'tan sonra
///   - Manual ayar "Önbelleği temizle" butonu
class EvictionSweeper {
  EvictionSweeper({
    required ContentStore store,
    required ReferenceGraph graph,
    AssetService? assetService,
    FreeMediaService? freeMediaService,
  })  : _store = store,
        _graph = graph,
        _asset = assetService,
        _free = freeMediaService;

  final ContentStore _store;
  final ReferenceGraph _graph;
  final AssetService? _asset;
  final FreeMediaService? _free;

  bool _running = false;
  Timer? _pendingTimer;

  /// Debounce penceresi — birçok CDC delete event'i bir araya gelir.
  static const Duration debounceWindow = Duration(seconds: 30);

  /// Çoklu trigger'ları tek sweep'e topla. CDC apply / write commit / entity
  /// delete sonrası çağrılır → debounceWindow sonra orphan + LRU pass.
  void requestSweep({bool allowCloudDelete = false}) {
    _pendingTimer?.cancel();
    _pendingTimer = Timer(debounceWindow, () async {
      _pendingTimer = null;
      try {
        await sweepOrphans(allowCloudDelete: allowCloudDelete);
        await sweepIfOverBudget();
      } catch (e) {
        debugPrint('EvictionSweeper requestSweep error: $e');
      }
    });
  }

  void dispose() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  static int defaultBudgetBytes() {
    // Mobile: 200 MB; desktop: 1 GB.
    if (Platform.isAndroid || Platform.isIOS) {
      return 200 * 1024 * 1024;
    }
    return 1024 * 1024 * 1024;
  }

  /// Orphan ref'leri sil. [allowCloudDelete] true ise DM rolünden çağrılır
  /// ve cloud objeleri de silinir; aksi halde yalnız local cache.
  Future<SweepResult> sweepOrphans({bool allowCloudDelete = false}) async {
    if (_running) return SweepResult.empty();
    _running = true;
    final result = SweepResult();
    try {
      await for (final entry in _store.entries()) {
        final uri = entry.metadata?.sourceUri;
        if (uri == null) {
          // Source bilinmiyor → legacy migrate veya bozuk meta;
          // referanslı olup olmadığını bilemediğimiz için tut.
          continue;
        }
        final referenced = await _graph.isReferenced(uri);
        if (referenced) continue;

        try {
          await _store.delete(entry.sha);
          result.localDeleted++;
          result.localBytesFreed += entry.sizeBytes;
        } catch (e) {
          debugPrint('sweep local delete error sha=${entry.sha}: $e');
        }

        if (!allowCloudDelete) continue;
        try {
          final ref = AssetRef(uri);
          if (ref.isCloud) {
            final key = ref.r2Key;
            if (key != null) {
              await _asset?.deleteAsset(key, keepCache: true);
              result.cloudDeleted++;
            }
          } else if (ref.isPublic) {
            final path = ref.publicPath;
            if (path != null) {
              await _free?.deleteFreeMedia(path, keepCache: true);
              result.cloudDeleted++;
            }
          }
        } catch (e) {
          debugPrint('sweep cloud delete error uri=$uri: $e');
        }
      }
    } finally {
      _running = false;
    }
    return result;
  }

  /// Toplam cache size > [budgetBytes] ise en eski LRU dosyalardan sil.
  /// Referenced dosyaları da siler — sonraki resolve re-fetch eder.
  Future<SweepResult> sweepIfOverBudget({int? budgetBytes}) async {
    final budget = budgetBytes ?? defaultBudgetBytes();
    final total = await _store.totalSizeBytes();
    if (total <= budget) return SweepResult.empty();

    final entries = <ContentEntry>[];
    await for (final e in _store.entries()) {
      entries.add(e);
    }
    // En eski access tarihli önce (null meta → çok eski say).
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    entries.sort((a, b) {
      final ta = a.metadata?.lastAccessAt ?? epoch;
      final tb = b.metadata?.lastAccessAt ?? epoch;
      return ta.compareTo(tb);
    });

    var current = total;
    final result = SweepResult();
    for (final e in entries) {
      if (current <= budget) break;
      try {
        await _store.delete(e.sha);
        current -= e.sizeBytes;
        result.localDeleted++;
        result.localBytesFreed += e.sizeBytes;
      } catch (err) {
        debugPrint('sweep LRU delete error sha=${e.sha}: $err');
      }
    }
    return result;
  }

  /// Manual full clear — settings "Önbelleği temizle".
  Future<SweepResult> clearAll() async {
    final result = SweepResult();
    await for (final e in _store.entries()) {
      try {
        await _store.delete(e.sha);
        result.localDeleted++;
        result.localBytesFreed += e.sizeBytes;
      } catch (err) {
        debugPrint('sweep clearAll error sha=${e.sha}: $err');
      }
    }
    return result;
  }

  /// Toplam cache durumu — settings "Cache" sayfası için.
  Future<CacheStatus> status({int? budgetBytes}) async {
    final budget = budgetBytes ?? defaultBudgetBytes();
    final total = await _store.totalSizeBytes();
    var count = 0;
    await for (final _ in _store.entries()) {
      count++;
    }
    return CacheStatus(
      totalBytes: total,
      budgetBytes: budget,
      entryCount: count,
    );
  }
}

class SweepResult {
  SweepResult({
    this.localDeleted = 0,
    this.localBytesFreed = 0,
    this.cloudDeleted = 0,
  });

  factory SweepResult.empty() => SweepResult();

  int localDeleted;
  int localBytesFreed;
  int cloudDeleted;

  @override
  String toString() =>
      'SweepResult(local=$localDeleted, freed=${localBytesFreed}B, cloud=$cloudDeleted)';
}

class CacheStatus {
  CacheStatus({
    required this.totalBytes,
    required this.budgetBytes,
    required this.entryCount,
  });

  final int totalBytes;
  final int budgetBytes;
  final int entryCount;

  bool get overBudget => totalBytes > budgetBytes;
  double get utilization => budgetBytes == 0 ? 0 : totalBytes / budgetBytes;
}

final evictionSweeperProvider = Provider<EvictionSweeper>((ref) {
  final sweeper = EvictionSweeper(
    store: ref.watch(contentStoreProvider),
    graph: ref.watch(referenceGraphProvider),
    assetService: ref.watch(assetServiceProvider),
    freeMediaService: ref.watch(freeMediaServiceProvider),
  );
  ref.onDispose(sweeper.dispose);
  return sweeper;
});
