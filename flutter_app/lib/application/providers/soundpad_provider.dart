import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_paths.dart';
import '../../data/services/soundpad_engine.dart';
import '../../data/services/soundpad_loader.dart';
import '../../domain/entities/audio/audio_models.dart';
import '../../domain/entities/events/event_envelope.dart';
import '../../domain/entities/events/event_types.dart';
import '../services/event_bus.dart';
import 'event_bus_provider.dart';
import 'ui_state_provider.dart';

// =============================================================================
// Infrastructure Providers
// =============================================================================

/// Çözümlenmiş soundpad dizin yolu.
final soundpadRootProvider = Provider<String>((ref) => AppPaths.soundpadRoot);

/// Global library (ambience + sfx listeleri, YAML'dan parse).
final soundpadLibraryProvider = FutureProvider<SoundpadLibrary>((ref) {
  final root = ref.watch(soundpadRootProvider);
  return SoundpadLoader.loadGlobalLibrary(root);
});

/// Soundpad kök dizinindeki tüm dosyaların toplam boyutu (byte).
/// Settings tab'da "kullanılan storage" göstergesini beslemek için.
final soundpadTotalSizeProvider = FutureProvider<int>((ref) async {
  final root = ref.watch(soundpadRootProvider);
  final dir = Directory(root);
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entry in dir.list(recursive: true, followLinks: false)) {
    if (entry is File) {
      try {
        total += await entry.length();
      } catch (_) {
        // İzin hataları vs. — yoksay.
      }
    }
  }
  return total;
});

/// Tüm müzik temaları.
final soundpadThemesProvider = FutureProvider<Map<String, SoundpadTheme>>((ref) {
  final root = ref.watch(soundpadRootProvider);
  return SoundpadLoader.loadAllThemes(root);
});

/// Audio engine singleton — widget tree'den bağımsız, uzun ömürlü.
final soundpadEngineProvider = Provider<SoundpadEngine>((ref) {
  final engine = SoundpadEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// =============================================================================
// Ambience Slot State
// =============================================================================

class AmbienceSlotState {
  final String? ambienceId;
  final double volume; // 0.0-1.0

  const AmbienceSlotState({this.ambienceId, this.volume = 0.7});

  AmbienceSlotState copyWith({String? ambienceId, double? volume, bool clearId = false}) {
    return AmbienceSlotState(
      ambienceId: clearId ? null : (ambienceId ?? this.ambienceId),
      volume: volume ?? this.volume,
    );
  }
}

// =============================================================================
// Soundpad UI State
// =============================================================================

class SoundpadState {
  final String? activeThemeId;
  final String? activeStateName;
  final int intensityLevel;
  final List<AmbienceSlotState> ambienceSlots;
  final bool musicPlaying;

  const SoundpadState({
    this.activeThemeId,
    this.activeStateName,
    this.intensityLevel = 0,
    this.ambienceSlots = const [],
    this.musicPlaying = false,
  });

  SoundpadState copyWith({
    String? activeThemeId,
    String? activeStateName,
    int? intensityLevel,
    List<AmbienceSlotState>? ambienceSlots,
    bool? musicPlaying,
    bool clearTheme = false,
    bool clearState = false,
  }) {
    return SoundpadState(
      activeThemeId: clearTheme ? null : (activeThemeId ?? this.activeThemeId),
      activeStateName: clearState ? null : (activeStateName ?? this.activeStateName),
      intensityLevel: intensityLevel ?? this.intensityLevel,
      ambienceSlots: ambienceSlots ?? this.ambienceSlots,
      musicPlaying: musicPlaying ?? this.musicPlaying,
    );
  }
}

// =============================================================================
// SoundpadNotifier — reactive state + engine yönetimi
// =============================================================================

class SoundpadNotifier extends StateNotifier<SoundpadState> {
  final SoundpadEngine _engine;
  final String _soundpadRoot;
  final Ref _ref;
  final AppEventBus _eventBus;
  SoundpadLibrary _library = const SoundpadLibrary();
  Map<String, SoundpadTheme> _themes = {};

  SoundpadNotifier(this._engine, this._soundpadRoot, this._ref, this._eventBus)
      : super(SoundpadState(
          ambienceSlots: List.generate(
            SoundpadEngine.ambienceSlotCount,
            (_) => const AmbienceSlotState(),
          ),
        )) {
    // Master volume senkronizasyonu
    _ref.listen<double>(
      uiStateProvider.select((s) => s.volume),
      (_, volume) => _engine.setMasterVolume(volume),
      fireImmediately: true,
    );
  }

  void setLibrary(SoundpadLibrary lib) => _library = lib;
  void setThemes(Map<String, SoundpadTheme> themes) => _themes = themes;

  SoundpadLibrary get library => _library;
  Map<String, SoundpadTheme> get themes => _themes;

  // --- Theme ---

  void selectTheme(String? themeId) {
    if (themeId == null) {
      _engine.setTheme(null);
      state = state.copyWith(clearTheme: true, clearState: true, musicPlaying: false, intensityLevel: 0);
      _emitAudioState();
      return;
    }

    final theme = _themes[themeId];
    if (theme == null) return;

    _engine.setTheme(theme);
    state = state.copyWith(
      activeThemeId: themeId,
      activeStateName: _engine.currentStateId,
      intensityLevel: 0,
      musicPlaying: true,
    );
    _emitAudioState();
  }

  // --- State ---

  void selectState(String stateName) {
    _engine.queueState(stateName);
    state = state.copyWith(activeStateName: stateName);
  }

  // --- Intensity ---

  void setIntensity(int level) {
    _engine.setIntensity(level);
    state = state.copyWith(intensityLevel: level);
    _emitAudioState();
  }

  // --- EventBus emission ---

  /// Audio state'ini EventBus'a emit eder. Future NetworkBridge bunu
  /// player'lara forward eder — onlar kendi bilgisayarlarında çalar.
  void _emitAudioState() {
    _eventBus.emit(EventEnvelope.now(
      EventTypes.audioStateChanged,
      {
        'theme': state.activeThemeId ?? '',
        'intensity': state.intensityLevel.toString(),
        'master_volume': 1.0,
      },
    ));
  }

  // --- Ambience ---

  void setAmbienceSlot(int index, String? ambienceId) {
    final volumePercent = state.ambienceSlots[index].volume * 100;
    _engine.playAmbience(index, ambienceId, volumePercent, _library, _soundpadRoot);

    final slots = List<AmbienceSlotState>.from(state.ambienceSlots);
    slots[index] = ambienceId == null
        ? slots[index].copyWith(clearId: true)
        : slots[index].copyWith(ambienceId: ambienceId);
    state = state.copyWith(ambienceSlots: slots);
  }

  void setAmbienceVolume(int index, double volume) {
    _engine.setAmbienceVolume(index, volume);

    final slots = List<AmbienceSlotState>.from(state.ambienceSlots);
    slots[index] = slots[index].copyWith(volume: volume);
    state = state.copyWith(ambienceSlots: slots);
  }

  // --- SFX ---

  void playSfx(String sfxId) {
    _engine.playSfx(sfxId, _library, _soundpadRoot);
    _eventBus.emit(EventEnvelope.now(
      EventTypes.audioTrackTriggered,
      {'track_id': sfxId, 'track_name': sfxId},
    ));
  }

  // --- Stop ---

  void stopAmbience() {
    _engine.stopAmbience();
    state = state.copyWith(
      ambienceSlots: List.generate(
        SoundpadEngine.ambienceSlotCount,
        (_) => const AmbienceSlotState(),
      ),
    );
  }

  void stopAll() {
    _engine.stopAll();
    state = state.copyWith(
      clearTheme: true,
      clearState: true,
      musicPlaying: false,
      intensityLevel: 0,
      ambienceSlots: List.generate(
        SoundpadEngine.ambienceSlotCount,
        (_) => const AmbienceSlotState(),
      ),
    );
  }

  // --- Library Management ---

  Future<(bool, String)> addSound(String category, String name, String filePath) async {
    final result = await SoundpadLoader.addToLibrary(_soundpadRoot, category, name, filePath);
    if (result.$1) {
      // Library'yi yeniden yükle
      _ref.invalidate(soundpadLibraryProvider);
    }
    return result;
  }

  Future<(bool, String)> removeSound(String category, String soundId) async {
    final result = await SoundpadLoader.removeFromLibrary(_soundpadRoot, category, soundId);
    if (result.$1) {
      _ref.invalidate(soundpadLibraryProvider);
    }
    return result;
  }

  // --- Theme Management ---

  Future<(bool, String)> createTheme(
    String name,
    String id,
    Map<String, Map<String, String>> stateMap,
  ) async {
    final result = await SoundpadLoader.createTheme(_soundpadRoot, name, id, stateMap);
    if (result.$1) {
      _ref.invalidate(soundpadThemesProvider);
    }
    return result;
  }

  Future<(bool, String)> deleteTheme(String themeId) async {
    // Çalan temayı siliyorsak durdur
    if (state.activeThemeId == themeId) {
      stopAll();
    }
    final result = await SoundpadLoader.deleteTheme(_soundpadRoot, themeId);
    if (result.$1) {
      _ref.invalidate(soundpadThemesProvider);
    }
    return result;
  }
}

// =============================================================================
// Main Provider
// =============================================================================

final soundpadStateProvider = StateNotifierProvider<SoundpadNotifier, SoundpadState>((ref) {
  final engine = ref.watch(soundpadEngineProvider);
  final root = ref.watch(soundpadRootProvider);
  final notifier = SoundpadNotifier(engine, root, ref, ref.read(eventBusProvider));

  // Library ve themes yüklendiğinde notifier'a aktar
  ref.listen(soundpadLibraryProvider, (_, asyncLib) {
    asyncLib.whenData((lib) => notifier.setLibrary(lib));
  });
  ref.listen(soundpadThemesProvider, (_, asyncThemes) {
    asyncThemes.whenData((themes) => notifier.setThemes(themes));
  });

  return notifier;
});
