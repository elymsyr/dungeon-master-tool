import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_format.dart';

/// Faz 9 — bulut aynasında bir şeyin ters gittiği yer. Her tür kendi son
/// sonucuyla değişir: pull'un başarısı push'un reddettiği satırları silmez.
enum CloudSyncIssue { push, pull, media, quota, share }

class CloudSyncProblem {
  const CloudSyncProblem(this.count, {this.error});

  /// Buluta çıkmayan satır / dosya sayısı; tek bir hata için 1.
  final int count;

  /// Turun kendisi başarısızsa hatası; null ise tur koştu ama [count] satır
  /// ya da dosya reddedildi.
  final String? error;
}

/// Bir online dünyanın ya da paketin bulut hali.
@immutable
class CloudSyncStatus {
  const CloudSyncStatus({
    this.running = 0,
    this.offline = false,
    this.problems = const {},
    this.syncedAt,
  });

  /// Şu an koşan (ya da şeritte sırasını bekleyen) tur sayısı.
  final int running;

  /// Son deneme ağa çıkamadı: düzenlemeler bu cihazda, bağlantı gelince
  /// gidiyor.
  final bool offline;

  final Map<CloudSyncIssue, CloudSyncProblem> problems;

  /// Son başarılı push turu.
  final DateTime? syncedAt;

  bool get syncing => running > 0;
  int get problemCount => problems.values.fold(0, (n, p) => n + p.count);

  CloudSyncStatus copyWith({
    int? running,
    bool? offline,
    Map<CloudSyncIssue, CloudSyncProblem>? problems,
    DateTime? syncedAt,
  }) =>
      CloudSyncStatus(
        running: running ?? this.running,
        offline: offline ?? this.offline,
        problems: problems ?? this.problems,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}

/// Anahtar açık öğenin anahtarı: dünyada id, pakette paket **adı** — paket
/// ekranı `activeCampaignProvider`'ı paket adıyla override ettiği için
/// gösterge ikisinde de aynı okumayla bulur. Kayıt yalnız online öğe için
/// var; yoksa gösterge yalnız yerel kaydı anlatır.
class CloudSyncStatusNotifier
    extends StateNotifier<Map<String, CloudSyncStatus>> {
  CloudSyncStatusNotifier() : super(const {});

  void started(String key) =>
      _put(key, (s) => s.copyWith(running: s.running + 1));

  void ended(String key) {
    final s = state[key];
    if (s == null) return;
    _put(key, (s) => s.copyWith(running: s.running > 0 ? s.running - 1 : 0));
  }

  /// [kind]'ın son sonucu. Ağ hatası sorun sayılmaz: öğe "bekliyor"a düşer,
  /// eski sorun yerinde kalır — bağlantı gelince tur kendisi temizler.
  void report(
    String key,
    CloudSyncIssue kind, {
    Object? error,
    int failed = 0,
  }) {
    if (error != null && isOfflineError(error)) {
      _put(key, (s) => s.copyWith(offline: true));
      return;
    }
    _put(key, (s) {
      final problems = Map.of(s.problems);
      if (error != null) {
        problems[kind] = CloudSyncProblem(failed > 0 ? failed : 1,
            error: formatError(error));
      } else if (failed > 0) {
        problems[kind] = CloudSyncProblem(failed);
      } else {
        problems.remove(kind);
      }
      return s.copyWith(
        offline: false,
        problems: problems,
        syncedAt: kind == CloudSyncIssue.push && error == null && failed == 0
            ? DateTime.now()
            : null,
      );
    });
  }

  /// Online öğe ama tur hiç denenemedi (rol çevrimdışı çözülemedi).
  void markOffline(String key) =>
      _put(key, (s) => s.copyWith(offline: true));

  /// Öğe artık online değil.
  void remove(String key) {
    if (!state.containsKey(key)) return;
    state = {...state}..remove(key);
  }

  void _put(String key, CloudSyncStatus Function(CloudSyncStatus) f) {
    state = {...state, key: f(state[key] ?? const CloudSyncStatus())};
  }
}

final cloudSyncStatusProvider = StateNotifierProvider<CloudSyncStatusNotifier,
    Map<String, CloudSyncStatus>>((_) => CloudSyncStatusNotifier());
