import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/soundpack_catalog_service.dart';
import '../../domain/entities/audio/soundpack_catalog.dart';
import 'soundpad_provider.dart';

/// Long-lived catalog service (native HttpClient inside).
final soundpackCatalogServiceProvider =
    Provider<SoundpackCatalogService>((ref) => SoundpackCatalogService());

/// Curated soundpack catalog fetched from the GitHub manifest.
final soundpackCatalogProvider =
    FutureProvider<List<SoundpackCatalogEntry>>((ref) {
  return ref.watch(soundpackCatalogServiceProvider).fetchManifest();
});

/// Per-pack download status.
enum SoundpackDownloadPhase { idle, downloading, done, error }

class SoundpackDownloadStatus {
  const SoundpackDownloadStatus({
    this.phase = SoundpackDownloadPhase.idle,
    this.done = 0,
    this.total = 0,
    this.message,
  });

  final SoundpackDownloadPhase phase;
  final int done;
  final int total;
  final String? message;

  /// 0.0–1.0 download progress (0 when total unknown).
  double get progress => total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble();

  SoundpackDownloadStatus copyWith({
    SoundpackDownloadPhase? phase,
    int? done,
    int? total,
    String? message,
  }) {
    return SoundpackDownloadStatus(
      phase: phase ?? this.phase,
      done: done ?? this.done,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }
}

/// Tracks download progress per pack id and installs packs into the soundpad
/// root. On success invalidates the soundpad theme/library providers so the
/// new pack appears in the sidebar immediately (same pattern as
/// `SoundpadNotifier.createTheme`).
class SoundpackDownloadNotifier
    extends StateNotifier<Map<String, SoundpackDownloadStatus>> {
  SoundpackDownloadNotifier(this._ref) : super(const {});

  final Ref _ref;

  SoundpackDownloadStatus statusFor(String id) =>
      state[id] ?? const SoundpackDownloadStatus();

  Future<bool> download(SoundpackCatalogEntry entry) async {
    final current = statusFor(entry.id);
    if (current.phase == SoundpackDownloadPhase.downloading) return false;

    _set(entry.id, const SoundpackDownloadStatus(
      phase: SoundpackDownloadPhase.downloading,
    ));

    final service = _ref.read(soundpackCatalogServiceProvider);
    final root = _ref.read(soundpadRootProvider);

    try {
      final (ok, msg) = await service.downloadPack(
        entry,
        root,
        onProgress: (done, total) {
          _set(
            entry.id,
            statusFor(entry.id).copyWith(
              phase: SoundpackDownloadPhase.downloading,
              done: done,
              total: total,
            ),
          );
        },
      );
      if (ok) {
        // Surface the new theme (and any library entries) in the soundpad UI.
        _ref.invalidate(soundpadThemesProvider);
        _ref.invalidate(soundpadLibraryProvider);
        _ref.invalidate(soundpadTotalSizeProvider);
        _set(entry.id,
            statusFor(entry.id).copyWith(phase: SoundpackDownloadPhase.done));
        return true;
      }
      _set(entry.id, statusFor(entry.id).copyWith(
        phase: SoundpackDownloadPhase.error,
        message: msg,
      ));
      return false;
    } catch (e) {
      _set(entry.id, statusFor(entry.id).copyWith(
        phase: SoundpackDownloadPhase.error,
        message: e.toString(),
      ));
      return false;
    }
  }

  void _set(String id, SoundpackDownloadStatus status) {
    state = {...state, id: status};
  }
}

final soundpackDownloadProvider = StateNotifierProvider<
    SoundpackDownloadNotifier, Map<String, SoundpackDownloadStatus>>(
  (ref) => SoundpackDownloadNotifier(ref),
);

/// Set of installed ids — loaded theme ids plus ambience/SFX library entry
/// ids. Used by the catalog view to show "Installed" instead of "Get":
/// a theme pack is installed when its id is present; a library pack when all
/// of its entry ids are present.
final installedSoundpackIdsProvider = Provider<Set<String>>((ref) {
  final themes = ref.watch(soundpadThemesProvider).valueOrNull;
  final library = ref.watch(soundpadLibraryProvider).valueOrNull;
  return {
    ...?themes?.keys,
    ...?library?.ambience.map((a) => a.id),
    ...?library?.sfx.map((s) => s.id),
  };
});
