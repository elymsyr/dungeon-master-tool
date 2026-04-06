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
  }) = _TimelinePin;

  factory TimelinePin.fromJson(Map<String, dynamic> json) =>
      _$TimelinePinFromJson(json);
}

/// A single epoch (time segment) with its own map image, pins, and timeline.
@freezed
abstract class MapEpoch with _$MapEpoch {
  const factory MapEpoch({
    required String id,
    @Default('') String imagePath,
    @Default([]) List<MapPin> pins,
    @Default([]) List<TimelinePin> timelinePins,
  }) = _MapEpoch;

  factory MapEpoch.fromJson(Map<String, dynamic> json) =>
      _$MapEpochFromJson(json);
}

/// A waypoint marker separating two epochs on the epoch scroll bar.
@freezed
abstract class EpochWaypoint with _$EpochWaypoint {
  const factory EpochWaypoint({
    required String id,
    @Default('') String label,
  }) = _EpochWaypoint;

  factory EpochWaypoint.fromJson(Map<String, dynamic> json) =>
      _$EpochWaypointFromJson(json);
}
