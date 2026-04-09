import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_models.freezed.dart';

/// Tek ses dosyası referansı — theme track'inin bir parçası.
@freezed
abstract class LoopNode with _$LoopNode {
  const factory LoopNode({
    required String filePath,
    @Default(0) int repeatCount, // 0 = infinite loop
  }) = _LoopNode;
}

/// Intensity katmanı (e.g. 'base', 'level1', 'level2', 'level3').
@freezed
abstract class MusicTrack with _$MusicTrack {
  const factory MusicTrack({
    required String name,
    @Default([]) List<LoopNode> sequence,
  }) = _MusicTrack;
}

/// Müzik durumu (e.g. 'normal', 'combat', 'victory').
@freezed
abstract class MusicState with _$MusicState {
  const factory MusicState({
    required String name,
    @Default({}) Map<String, MusicTrack> tracks, // key: 'base', 'level1', ...
  }) = _MusicState;
}

/// Tema — birden fazla state içeren müzik paketi.
@freezed
abstract class SoundpadTheme with _$SoundpadTheme {
  const factory SoundpadTheme({
    required String id,
    @Default('') String name,
    @Default({}) Map<String, MusicState> states, // key: 'normal', 'combat', ...
    @Default({}) Map<String, String> shortcuts,
  }) = _SoundpadTheme;
}

/// Global library — ambience girişi.
@freezed
abstract class AmbienceEntry with _$AmbienceEntry {
  const factory AmbienceEntry({
    required String id,
    @Default('') String name,
    @Default([]) List<String> files, // expanded full paths
  }) = _AmbienceEntry;
}

/// Global library — SFX girişi.
@freezed
abstract class SfxEntry with _$SfxEntry {
  const factory SfxEntry({
    required String id,
    @Default('') String name,
    @Default([]) List<String> files,
  }) = _SfxEntry;
}

/// Soundpad global kütüphanesi — ambience + sfx + shortcuts.
@freezed
abstract class SoundpadLibrary with _$SoundpadLibrary {
  const factory SoundpadLibrary({
    @Default([]) List<AmbienceEntry> ambience,
    @Default([]) List<SfxEntry> sfx,
    @Default({}) Map<String, String> shortcuts,
  }) = _SoundpadLibrary;
}
