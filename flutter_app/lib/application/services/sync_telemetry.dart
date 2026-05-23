import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';

/// F12 — sync telemetri histogramları.
///
/// Aggregated bucket'lar `sync_telemetry(metric, bucket, count, sum_ms,
/// last_at)` tablosunda tutulur. Bucketing:
///   - <50ms       → 'lt50'
///   - 50–200ms    → '50_200'
///   - 200–800ms   → '200_800'
///   - 800–3000ms  → '800_3000'
///   - >=3000ms    → 'gte3000'
///
/// Metrikler (sabit set):
///   - `open_to_first_pixel_ms` (entity card açılış → render)
///   - `cdc_apply_to_ref_ready_ms` (event al → fetch tamamla)
///   - `prewarm_completion_ms` (world açılış → kritik liste hazır)
///   - `cache_hit` (counter — every cache hit)
///   - `cache_miss` (counter — every miss)
///
/// MVP: lokal — opt-in cloud upload sonraki PR. Histogram aggregation
/// upsert ile O(1).
class SyncTelemetry {
  SyncTelemetry(this._db);

  final AppDatabase _db;

  // Metric isimleri — sabit string'ler.
  static const String openToFirstPixel = 'open_to_first_pixel_ms';
  static const String cdcApplyToRefReady = 'cdc_apply_to_ref_ready_ms';
  static const String prewarmCompletion = 'prewarm_completion_ms';
  static const String cacheHit = 'cache_hit';
  static const String cacheMiss = 'cache_miss';

  /// Latency sample ekle — bucketize edip aggregate'e ekler.
  Future<void> recordLatency(String metric, int ms) async {
    try {
      final bucket = _bucketOf(ms);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        'INSERT INTO sync_telemetry (metric, bucket, count, sum_ms, last_at) '
        'VALUES (?, ?, 1, ?, ?) '
        'ON CONFLICT(metric, bucket) DO UPDATE SET '
        'count = count + 1, sum_ms = sum_ms + excluded.sum_ms, '
        'last_at = excluded.last_at',
        [metric, bucket, ms, now],
      );
    } catch (e) {
      debugPrint('SyncTelemetry recordLatency error ($metric): $e');
    }
  }

  /// Counter increment — cache hit/miss gibi sayım metrikleri için
  /// (sum_ms anlamsız, 0 kalır).
  Future<void> incrementCounter(String metric) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        'INSERT INTO sync_telemetry (metric, bucket, count, sum_ms, last_at) '
        'VALUES (?, ?, 1, 0, ?) '
        'ON CONFLICT(metric, bucket) DO UPDATE SET '
        'count = count + 1, last_at = excluded.last_at',
        [metric, '_', now],
      );
    } catch (e) {
      debugPrint('SyncTelemetry incrementCounter error ($metric): $e');
    }
  }

  /// Belirli metric için histogram + ortalama döndürür (debug/Settings).
  Future<MetricSummary> summaryFor(String metric) async {
    final rows = await _db.customSelect(
      'SELECT bucket, count, sum_ms FROM sync_telemetry WHERE metric = ?',
      variables: [Variable<String>(metric)],
    ).get();
    final buckets = <String, int>{};
    var total = 0;
    var sum = 0;
    for (final r in rows) {
      final b = r.read<String>('bucket');
      final c = r.read<int>('count');
      buckets[b] = c;
      total += c;
      sum += r.read<int>('sum_ms');
    }
    return MetricSummary(
      metric: metric,
      totalCount: total,
      avgMs: total == 0 ? 0 : sum ~/ total,
      bucketCounts: buckets,
    );
  }

  /// Tüm metric'leri tek-shot temizle (debug için).
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM sync_telemetry');
  }

  String _bucketOf(int ms) {
    if (ms < 50) return 'lt50';
    if (ms < 200) return '50_200';
    if (ms < 800) return '200_800';
    if (ms < 3000) return '800_3000';
    return 'gte3000';
  }
}

class MetricSummary {
  MetricSummary({
    required this.metric,
    required this.totalCount,
    required this.avgMs,
    required this.bucketCounts,
  });

  final String metric;
  final int totalCount;
  final int avgMs;
  final Map<String, int> bucketCounts;

  /// p95 approx — bucket sayılarından heuristic; tam quantile için raw
  /// sample gerekir, ama bucket'lardan üst-bucket cumulative ile yaklaşık.
  int approxP95Bucket() {
    if (totalCount == 0) return 0;
    var cum = 0;
    final threshold = (totalCount * 0.95).ceil();
    for (final b in ['lt50', '50_200', '200_800', '800_3000', 'gte3000']) {
      cum += bucketCounts[b] ?? 0;
      if (cum >= threshold) {
        switch (b) {
          case 'lt50':
            return 50;
          case '50_200':
            return 200;
          case '200_800':
            return 800;
          case '800_3000':
            return 3000;
          default:
            return 10000;
        }
      }
    }
    return 0;
  }
}

final syncTelemetryProvider = Provider<SyncTelemetry>((ref) {
  return SyncTelemetry(ref.watch(appDatabaseProvider));
});
