import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Phase 0 — lightweight in-memory performance probe.
///
/// Records latency samples into bucketed histograms WITHOUT touching the DB on
/// the hot path, so it can be fed from per-frame and per-keystroke callbacks
/// cheaply. (Contrast [SyncTelemetry.recordLatency], which does an async DB
/// upsert per call — fine for low-frequency sync events, too heavy for frames.)
///
/// Usage:
///   1. `PerfProbe.instance.hookFrameTimings()` once after binding init.
///   2. Wrap hot paths: `final sw = PerfProbe.instance.start(); ...; `
///      `PerfProbe.instance.stop(PerfProbe.editorKeystroke, sw)`.
///   3. In a `--profile` build the histogram dump prints to the console (and
///      LogBuffer) every 20s; call `dump()` / `reset()` for manual A/B.
///
/// Compiled-in only outside release builds — every hot-path call short-circuits
/// on [enabled], and the [start]/[stop] stopwatch is null in release.
class PerfProbe {
  PerfProbe._();

  static final PerfProbe instance = PerfProbe._();

  /// Master switch. Hot-path callers must short-circuit on this so release
  /// builds pay nothing.
  static bool get enabled => !kReleaseMode;

  // Metric names — stable strings.
  static const String frameBuild = 'frame_build_ms';
  static const String frameRaster = 'frame_raster_ms';
  static const String editorKeystroke = 'editor_keystroke_ms';
  static const String saveCommit = 'save_commit_ms';

  final Map<String, _Hist> _hist = HashMap<String, _Hist>();
  bool _frameHooked = false;
  Timer? _dumpTimer;

  /// Returns a started stopwatch outside release, else null (no allocation).
  Stopwatch? start() => enabled ? (Stopwatch()..start()) : null;

  /// Stops [sw] (no-op if null) and records the elapsed time under [metric].
  void stop(String metric, Stopwatch? sw) {
    if (sw == null || !enabled) return;
    sw.stop();
    record(metric, sw.elapsedMicroseconds / 1000.0);
  }

  void record(String metric, double ms) {
    if (!enabled) return;
    (_hist[metric] ??= _Hist()).add(ms);
  }

  /// Hook Flutter frame timings (build + raster). Idempotent. Call once after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  void hookFrameTimings() {
    if (!enabled || _frameHooked) return;
    _frameHooked = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        record(frameBuild, t.buildDuration.inMicroseconds / 1000.0);
        record(frameRaster, t.rasterDuration.inMicroseconds / 1000.0);
      }
    });
    // In profile mode (the measurement build) dump every 20s so before/after
    // numbers land in the console + LogBuffer without needing any UI.
    if (kProfileMode) {
      _dumpTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
        final out = dump();
        if (out.isNotEmpty) debugPrint(out);
      });
    }
  }

  /// Formatted multi-metric histogram (count / avg / max / jank / buckets).
  String dump() {
    if (_hist.isEmpty) return '';
    final b = StringBuffer('── PerfProbe ── [buckets <8/<16/<33/<50/<100/<300/<800/inf ms]\n');
    for (final e in _hist.entries) {
      b.writeln('  ${e.key}: ${e.value.summary()}');
    }
    return b.toString();
  }

  void reset() => _hist.clear();
}

class _Hist {
  int count = 0;
  double sum = 0;
  double max = 0;
  int jank = 0; // samples over one 60fps frame budget (16ms)

  // Upper edges (ms); a final implicit "inf" bucket catches the rest.
  static const List<double> _edges = [8, 16, 33, 50, 100, 300, 800];
  final List<int> _buckets = List<int>.filled(_edges.length + 1, 0);

  void add(double ms) {
    count++;
    sum += ms;
    if (ms > max) max = ms;
    if (ms > 16) jank++;
    var i = 0;
    while (i < _edges.length && ms >= _edges[i]) {
      i++;
    }
    _buckets[i]++;
  }

  String summary() {
    final avg = count == 0 ? 0.0 : sum / count;
    return 'n=$count avg=${avg.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
        'jank>16ms=$jank  [${_buckets.join('/')}]';
  }
}
