import 'package:freezed_annotation/freezed_annotation.dart';

import 'schema/world_schema.dart';

part 'campaign.freezed.dart';
part 'campaign.g.dart';

@freezed
abstract class Campaign with _$Campaign {
  const factory Campaign({
    @Default('') String worldName,
    @Default({}) Map<String, dynamic> entities,
    @Default(MapData()) MapData mapData,
    @Default([]) List<Map<String, dynamic>> sessions,
    String? lastActiveSessionId,
    @Default({}) Map<String, dynamic> mindMaps,
    WorldSchema? worldSchema,
  }) = _Campaign;

  factory Campaign.fromJson(Map<String, dynamic> json) =>
      _$CampaignFromJson(json);
}

@freezed
abstract class MapData with _$MapData {
  const factory MapData({
    @Default('') String imagePath,
    @Default([]) List<Map<String, dynamic>> pins,
    @Default([]) List<Map<String, dynamic>> timeline,
  }) = _MapData;

  factory MapData.fromJson(Map<String, dynamic> json) =>
      _$MapDataFromJson(json);
}
