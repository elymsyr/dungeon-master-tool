import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_listing.freezed.dart';
part 'game_listing.g.dart';

@freezed
abstract class GameListing with _$GameListing {
  const factory GameListing({
    required String id,
    required String ownerId,
    String? ownerUsername,
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    @Default(0) int seatsFilled,
    String? schedule,
    @Default(true) bool isOpen,
    required DateTime createdAt,
  }) = _GameListing;

  factory GameListing.fromJson(Map<String, dynamic> json) =>
      _$GameListingFromJson(json);
}
