import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_data.freezed.dart';
part 'map_data.g.dart';

/// Battle/World map data — Sprint 3'te detaylandırılacak.
@freezed
abstract class MapData with _$MapData {
  const factory MapData({
    @Default('') String imagePath,
    @Default([]) List<MapPin> pins,
    @Default([]) List<Map<String, dynamic>> timeline,
    @Default(50) int gridSize,
    @Default(false) bool gridVisible,
    @Default(false) bool gridSnap,
    @Default(5) int feetPerCell,
    @Default({}) Map<String, dynamic> fogState,
    @Default([]) List<Map<String, dynamic>> drawings,
  }) = _MapData;

  factory MapData.fromJson(Map<String, dynamic> json) =>
      _$MapDataFromJson(json);
}

/// Harita pini — entity/location referansı.
@freezed
abstract class MapPin with _$MapPin {
  const factory MapPin({
    required String id,
    @Default(0) double x,
    @Default(0) double y,
    @Default('') String label,
    @Default('default') String pinType,
    String? entityId,
    @Default({}) Map<String, dynamic> style,
  }) = _MapPin;

  factory MapPin.fromJson(Map<String, dynamic> json) =>
      _$MapPinFromJson(json);
}
