import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_models.freezed.dart';
part 'audio_models.g.dart';

/// Audio track — Sprint 5'te detaylandırılacak.
@freezed
abstract class AudioTrack with _$AudioTrack {
  const factory AudioTrack({
    required String id,
    @Default('') String name,
    @Default('') String filePath,
    @Default('music') String trackType, // music, ambience, sfx
    @Default(1.0) double volume,
    @Default(false) bool loop,
    @Default({}) Map<String, dynamic> metadata,
  }) = _AudioTrack;

  factory AudioTrack.fromJson(Map<String, dynamic> json) =>
      _$AudioTrackFromJson(json);
}

/// Soundpad theme — ses koleksiyonu.
@freezed
abstract class SoundpadTheme with _$SoundpadTheme {
  const factory SoundpadTheme({
    required String id,
    @Default('') String name,
    @Default([]) List<AudioTrack> musicTracks,
    @Default([]) List<AudioTrack> ambienceTracks,
    @Default([]) List<AudioTrack> sfxTracks,
  }) = _SoundpadTheme;

  factory SoundpadTheme.fromJson(Map<String, dynamic> json) =>
      _$SoundpadThemeFromJson(json);
}
