import 'dart:async';
import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/audio/audio_models.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));
final _rng = Random();

// =============================================================================
// _TrackPlayer — tek intensity katmanı (base, level1, level2, ...)
// =============================================================================

class _TrackPlayer {
  AudioSource? _source;
  SoundHandle? _handle;
  double _volume = 0.0;

  Future<void> loadFile(String filePath) async {
    await dispose();
    try {
      _source = await SoLoud.instance.loadFile(filePath);
    } catch (e) {
      _log.e('TrackPlayer load error ($filePath): $e');
    }
  }

  Future<void> play({double volume = 0.0, bool looping = true}) async {
    if (_source == null) return;
    _volume = volume;
    try {
      _handle = await SoLoud.instance.play(
        _source!,
        volume: _volume,
        looping: looping,
      );
    } catch (e) {
      _log.e('TrackPlayer play error: $e');
    }
  }

  void stop() {
    if (_handle != null) {
      try {
        SoLoud.instance.stop(_handle!);
      } catch (_) {}
      _handle = null;
    }
  }

  set volume(double val) {
    _volume = val.clamp(0.0, 1.0);
    if (_handle != null) {
      try {
        SoLoud.instance.setVolume(_handle!, _volume);
      } catch (_) {}
    }
  }

  /// SoLoud hardware fade — Timer yok, smooth ve CPU-dostu.
  void fadeTo(double target, {Duration duration = const Duration(milliseconds: 1500)}) {
    target = target.clamp(0.0, 1.0);
    _volume = target;
    if (_handle == null) return;
    try {
      SoLoud.instance.fadeVolume(_handle!, target, duration);
    } catch (_) {}
  }

  Future<void> dispose() async {
    stop();
    if (_source != null) {
      try {
        SoLoud.instance.disposeSource(_source!);
      } catch (_) {}
      _source = null;
    }
  }
}

// =============================================================================
// _MultiTrackDeck — tek music state (Normal, Combat, ...) yöneten deck
// =============================================================================

class _MultiTrackDeck {
  final Map<String, _TrackPlayer> _players = {};
  List<String> activeLevels = ['base'];

  Future<void> loadState(MusicState state) async {
    await disposeAll();
    // Tüm track'ları yükle
    for (final entry in state.tracks.entries) {
      if (entry.value.sequence.isEmpty) continue;
      final player = _TrackPlayer();
      await player.loadFile(entry.value.sequence.first.filePath);
      _players[entry.key] = player;
    }
  }

  /// Tüm track'ları doğru volume ile başlat (senkron).
  Future<void> play() async {
    await Future.wait(_players.entries.map((entry) {
      final vol = activeLevels.contains(entry.key) ? 1.0 : 0.0;
      return entry.value.play(volume: vol, looping: true);
    }));
  }

  /// Tüm track'ları sessiz başlat (crossfade öncesi).
  Future<void> playSilent() async {
    await Future.wait(_players.entries.map((entry) {
      return entry.value.play(volume: 0.0, looping: true);
    }));
  }

  void stop() {
    for (final p in _players.values) {
      p.stop();
    }
  }

  /// Intensity mask güncelle — aktif layer'lar fade in, inaktif fade out.
  void setIntensityMask(List<String> levels) {
    activeLevels = levels;
    for (final entry in _players.entries) {
      final target = activeLevels.contains(entry.key) ? 1.0 : 0.0;
      entry.value.fadeTo(target);
    }
  }

  /// Crossfade-in: aktif layer'lar 0 → 1.0, inaktif kalır 0.
  void fadeIn({Duration duration = const Duration(seconds: 3)}) {
    for (final entry in _players.entries) {
      final target = activeLevels.contains(entry.key) ? 1.0 : 0.0;
      entry.value.fadeTo(target, duration: duration);
    }
  }

  /// Crossfade-out: tüm layer'lar → 0.
  void fadeOut({Duration duration = const Duration(seconds: 3)}) {
    for (final p in _players.values) {
      p.fadeTo(0.0, duration: duration);
    }
  }

  Future<void> disposeAll() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

// =============================================================================
// _AmbienceSlot
// =============================================================================

class _AmbienceSlot {
  AudioSource? _source;
  SoundHandle? _handle;
  String? activeId;
  double slotVolume = 0.7;

  Future<void> play(String filePath, double volume) async {
    await stop();
    try {
      _source = await SoLoud.instance.loadFile(filePath);
      _handle = await SoLoud.instance.play(
        _source!,
        volume: volume,
        looping: true,
      );
      // Gapless looping SoLoud tarafından otomatik yapılır
    } catch (e) {
      _log.e('AmbienceSlot play error: $e');
    }
  }

  void setVolume(double vol) {
    if (_handle != null) {
      try {
        SoLoud.instance.setVolume(_handle!, vol.clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    if (_handle != null) {
      try {
        SoLoud.instance.stop(_handle!);
      } catch (_) {}
      _handle = null;
    }
    if (_source != null) {
      try {
        SoLoud.instance.disposeSource(_source!);
      } catch (_) {}
      _source = null;
    }
    activeId = null;
  }

  Future<void> dispose() async => stop();
}

// =============================================================================
// SoundpadEngine — ana audio engine (SoLoud tabanlı)
// =============================================================================

class SoundpadEngine {
  // Music deck sistemi — crossfade için dual deck (A/B)
  final _deckA = _MultiTrackDeck();
  final _deckB = _MultiTrackDeck();
  late _MultiTrackDeck _activeDeck = _deckA;
  late _MultiTrackDeck _inactiveDeck = _deckB;

  // Theme state
  SoundpadTheme? _currentTheme;
  String? _currentStateId;
  String? _pendingStateId;
  int _currentIntensityLevel = 0;
  Timer? _crossfadeCleanup;

  // Ambience (4 slot)
  static const int ambienceSlotCount = 4;
  final List<_AmbienceSlot> _ambienceSlots =
      List.generate(ambienceSlotCount, (_) => _AmbienceSlot());

  // SFX cache — aynı ses dosyasını tekrar tekrar yüklememek için
  final Map<String, AudioSource> _sfxCache = {};

  // ---------------------------------------------------------------------------
  // Master Volume — SoLoud global volume olarak uygulanır
  // ---------------------------------------------------------------------------

  void setMasterVolume(double volume) {
    try {
      SoLoud.instance.setGlobalVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Theme & State
  // ---------------------------------------------------------------------------

  Future<void> setTheme(SoundpadTheme? theme) async {
    _currentTheme = theme;
    _pendingStateId = null;
    _crossfadeCleanup?.cancel();

    if (theme != null && theme.states.isNotEmpty) {
      await _hardSwitch(theme.states.keys.first);
    } else {
      _activeDeck.stop();
      _inactiveDeck.stop();
      _currentStateId = null;
    }
  }

  Future<void> setState(String stateName) async {
    if (_currentTheme == null) return;
    if (!_currentTheme!.states.containsKey(stateName)) return;
    if (stateName == _currentStateId) return;

    final targetState = _currentTheme!.states[stateName]!;

    // 1. Yeni state'i inactive deck'e yükle
    await _inactiveDeck.loadState(targetState);
    _inactiveDeck.activeLevels = _getMaskForLevel(_currentIntensityLevel);

    // 2. Sessiz başlat (tüm track'lar volume 0)
    await _inactiveDeck.playSilent();

    // 3. Deck'leri swap et
    final temp = _activeDeck;
    _activeDeck = _inactiveDeck;
    _inactiveDeck = temp;
    _currentStateId = stateName;

    // 4. Crossfade: yeni deck fade-in, eski deck fade-out (3 saniye)
    const fadeDuration = Duration(seconds: 3);
    _activeDeck.fadeIn(duration: fadeDuration);
    _inactiveDeck.fadeOut(duration: fadeDuration);

    // 5. Fade bittikten sonra eski deck'i durdur
    _crossfadeCleanup?.cancel();
    _crossfadeCleanup = Timer(
      fadeDuration + const Duration(milliseconds: 100),
      () {
        _inactiveDeck.stop();
        // Pending state varsa uygula
        if (_pendingStateId != null) {
          final pending = _pendingStateId!;
          _pendingStateId = null;
          setState(pending);
        }
      },
    );
  }

  void queueState(String stateName) {
    _pendingStateId = stateName;
    setState(stateName);
  }

  void setIntensity(int level) {
    _currentIntensityLevel = level.clamp(0, 3);
    _activeDeck.setIntensityMask(_getMaskForLevel(_currentIntensityLevel));
  }

  String? get currentStateId => _currentStateId;
  int get currentIntensityLevel => _currentIntensityLevel;

  // ---------------------------------------------------------------------------
  // Ambience
  // ---------------------------------------------------------------------------

  Future<void> playAmbience(
    int slotIndex,
    String? ambienceId,
    double volumePercent,
    SoundpadLibrary library,
    String soundpadRoot,
  ) async {
    if (slotIndex < 0 || slotIndex >= ambienceSlotCount) return;

    final slot = _ambienceSlots[slotIndex];
    slot.slotVolume = (volumePercent / 100.0).clamp(0.0, 1.0);

    if (ambienceId == null || ambienceId.isEmpty) {
      await slot.stop();
      return;
    }

    final entry = library.ambience.where((a) => a.id == ambienceId).firstOrNull;
    if (entry == null || entry.files.isEmpty) {
      await slot.stop();
      return;
    }

    final chosenFile = entry.files[_rng.nextInt(entry.files.length)];
    await slot.play(chosenFile, slot.slotVolume);
    slot.activeId = ambienceId;
  }

  void setAmbienceVolume(int slotIndex, double volume) {
    if (slotIndex < 0 || slotIndex >= ambienceSlotCount) return;
    final slot = _ambienceSlots[slotIndex];
    slot.slotVolume = volume.clamp(0.0, 1.0);
    slot.setVolume(slot.slotVolume);
  }

  Future<void> stopAmbience() async {
    for (final slot in _ambienceSlots) {
      await slot.stop();
    }
  }

  String? getAmbienceId(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= ambienceSlotCount) return null;
    return _ambienceSlots[slotIndex].activeId;
  }

  double getAmbienceVolume(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= ambienceSlotCount) return 0.7;
    return _ambienceSlots[slotIndex].slotVolume;
  }

  // ---------------------------------------------------------------------------
  // SFX — cache'li, tek seferlik çalma
  // ---------------------------------------------------------------------------

  Future<void> playSfx(
    String sfxId,
    SoundpadLibrary library,
    String soundpadRoot,
  ) async {
    final entry = library.sfx.where((s) => s.id == sfxId).firstOrNull;
    if (entry == null || entry.files.isEmpty) return;

    final chosenFile = entry.files[_rng.nextInt(entry.files.length)];

    try {
      // Cache'den al veya yükle
      AudioSource source;
      if (_sfxCache.containsKey(chosenFile)) {
        source = _sfxCache[chosenFile]!;
      } else {
        source = await SoLoud.instance.loadFile(chosenFile);
        _sfxCache[chosenFile] = source;
      }

      // Çal — loop yok, tek seferlik
      await SoLoud.instance.play(source, volume: 1.0, looping: false);
      // SoLoud voice handle'ı otomatik serbest bırakır
      // Source cache'de kalır (yeniden kullanım için)
    } catch (e) {
      _log.e('playSfx error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Stop All
  // ---------------------------------------------------------------------------

  Future<void> stopAll() async {
    _pendingStateId = null;
    _crossfadeCleanup?.cancel();
    _activeDeck.stop();
    _inactiveDeck.stop();
    await stopAmbience();
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    _crossfadeCleanup?.cancel();
    await _deckA.disposeAll();
    await _deckB.disposeAll();
    for (final slot in _ambienceSlots) {
      await slot.dispose();
    }
    // SFX cache temizle
    for (final source in _sfxCache.values) {
      try {
        SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
    _sfxCache.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<String> _getMaskForLevel(int level) {
    return ['base', ...List.generate(level, (i) => 'level${i + 1}')];
  }

  /// Crossfade olmadan direkt state yükleme (ilk yükleme).
  Future<void> _hardSwitch(String stateName) async {
    _crossfadeCleanup?.cancel();
    _activeDeck.stop();
    _inactiveDeck.stop();

    final state = _currentTheme?.states[stateName];
    if (state == null) return;

    await _activeDeck.loadState(state);
    _activeDeck.activeLevels = _getMaskForLevel(_currentIntensityLevel);
    await _activeDeck.play();
    _currentStateId = stateName;
  }
}
