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
    @Default('') String note,
    @Default('') String color,
    @Default({}) Map<String, dynamic> style,
  }) = _MapPin;

  factory MapPin.fromJson(Map<String, dynamic> json) =>
      _$MapPinFromJson(json);
}

/// Timeline pin — day-based event marker on the map.
@freezed
abstract class TimelinePin with _$TimelinePin {
  const factory TimelinePin({
    required String id,
    @Default(0) double x,
    @Default(0) double y,
    @Default(1) int day,
    @Default('') String note,
    @Default([]) List<String> entityIds,
    String? sessionId,
    @Default([]) List<String> parentIds,
    @Default('#42a5f5') String color,
    @Default({}) Map<String, dynamic> style,
  }) = _TimelinePin;

  factory TimelinePin.fromJson(Map<String, dynamic> json) =>
      _$TimelinePinFromJson(json);
}

/// A single era (time segment) with its own map image, pins, and timeline.
/// `locationMaps` holds per-location nested pin collections — the map image
/// is sourced from the location entity's `map_per_era[era.id]`, not stored
/// here.
@freezed
abstract class MapEra with _$MapEra {
  const factory MapEra({
    required String id,
    @Default('') String imagePath,
    @Default([]) List<MapPin> pins,
    @Default([]) List<TimelinePin> timelinePins,
    @Default({}) Map<String, LocationMapData> locationMaps,
  }) = _MapEra;

  factory MapEra.fromJson(Map<String, dynamic> json) =>
      _$MapEraFromJson(json);
}

/// Per-location nested map data inside a [MapEra]. Holds the pins and
/// timeline pins for a drill-in view; the background image comes from the
/// location entity's `map_per_era[eraId]` (falls back to `map`).
@freezed
abstract class LocationMapData with _$LocationMapData {
  const factory LocationMapData({
    @Default([]) List<MapPin> pins,
    @Default([]) List<TimelinePin> timelinePins,
  }) = _LocationMapData;

  factory LocationMapData.fromJson(Map<String, dynamic> json) =>
      _$LocationMapDataFromJson(json);
}

/// A waypoint marker separating two eras on the era scroll bar.
@freezed
abstract class EraWaypoint with _$EraWaypoint {
  const factory EraWaypoint({
    required String id,
    @Default('') String label,
  }) = _EraWaypoint;

  factory EraWaypoint.fromJson(Map<String, dynamic> json) =>
      _$EraWaypointFromJson(json);
}
